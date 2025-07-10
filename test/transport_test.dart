// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pkl_dart/src/evaluation/pkl_error.dart';
import 'package:pkl_dart/src/evaluation/transport.dart';
import 'package:pkl_dart/src/message.dart';
import 'package:pkl_dart/src/message_pack/message_pack.dart';
import 'package:pkl_dart/src/serializer/message_serializer.dart';
import 'package:test/test.dart';

/// A mock IOSink that captures all written bytes into a buffer for inspection.
class _MockSink implements IOSink {
  final BytesBuilder _buffer = BytesBuilder();
  final Completer<void> _doneCompleter = Completer();

  /// The bytes that have been written to this sink.
  Uint8List get bytes => _buffer.toBytes();

  @override
  void add(List<int> data) {
    _buffer.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    // Not needed for these tests
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<void> close() async {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  Encoding encoding = utf8;

  @override
  Future<void> flush() async {}

  @override
  void write(Object? obj) {
    add(encoding.encode(obj.toString()));
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    write(String.fromCharCode(charCode));
  }

  @override
  void writeln([Object? obj = ""]) {
    write(obj);
    write('\n');
  }
}

void main() {
  group('BaseMessageTransport', () {
    late BaseMessageTransport transport;
    late StreamController<List<int>> readerController;
    late _MockSink writerSink;

    // Helper to create a serialized message for testing deserialization
    Uint8List createSerializedMessage(Message message) {
      final writer = DefaultMessagePackWriter();
      final encoder = MessagePackEncoder(writer);
      final serializer = MessageSerializer(
        encoder: encoder,
        decoder: MessagePackDecoder(),
      );
      serializer.serialize(
        message as ClientMessage,
      ); // Cast for helper simplicity
      return writer.takeBytes();
    }

    setUp(() {
      readerController = StreamController<List<int>>.broadcast();
      writerSink = _MockSink();
      // Use the ServerMessageTransport implementation of BaseMessageTransport
      // but with our mock streams. The `_process` will be null.
      transport = ServerMessageTransport.withoutProcess(
        readerController.stream,
        writerSink,
      );
    });

    tearDown(() async {
      await transport.close();
      if (!readerController.isClosed) {
        await readerController.close();
      }
    });

    test('send() serializes and writes a message to the sink', () async {
      // Arrange
      final request = EvaluateRequest(
        requestId: 123,
        evaluatorId: 1,
        moduleUri: Uri.parse('pigeon:/test'),
      );

      // Act
      await transport.send(request);

      // Assert
      // Manually serialize the same message to get the expected byte sequence.
      final expectedBytes = createSerializedMessage(request);
      expect(writerSink.bytes, equals(expectedBytes));
    });

    test('should receive and decode a single complete message', () async {
      // Arrange
      final response = CreateEvaluatorResponse(requestId: 1, evaluatorId: 10);
      final bytes = MessagePackCodec().encode([
        MessageType.createEvaluatorResponse.value,
        response.propertyMap(),
      ]);

      // Assert
      expect(transport.messages, emits(isA<CreateEvaluatorResponse>()));

      // Act
      readerController.add(bytes);
    });

    test(
      'should receive and decode multiple messages from a single chunk',
      () async {
        // Arrange
        final response1 = CreateEvaluatorResponse(
          requestId: 1,
          evaluatorId: 10,
        );
        final response2 = LogMessage(
          evaluatorId: 10,
          level: LogLevel.warn,
          message: 'Warning!',
          frameUri: 'file:///test.pkl',
        );

        final bytes1 = MessagePackCodec().encode([
          MessageType.createEvaluatorResponse.value,
          response1.propertyMap(),
        ]);
        final bytes2 = MessagePackCodec().encode([
          MessageType.logMessage.value,
          response2.propertyMap(),
        ]);

        final combinedBytes = Uint8List.fromList([...bytes1, ...bytes2]);

        // Assert
        expect(
          transport.messages,
          emitsInOrder([isA<CreateEvaluatorResponse>(), isA<LogMessage>()]),
        );

        // Act
        readerController.add(combinedBytes);
      },
    );

    test('should buffer and decode a fragmented message', () async {
      // Arrange
      final response = CreateEvaluatorResponse(requestId: 1, evaluatorId: 10);
      final bytes = MessagePackCodec().encode([
        MessageType.createEvaluatorResponse.value,
        response.propertyMap(),
      ]);

      // Split the message into two parts
      final part1 = bytes.sublist(0, bytes.length ~/ 2);
      final part2 = bytes.sublist(bytes.length ~/ 2);

      // Assert
      expect(transport.messages, emits(isA<CreateEvaluatorResponse>()));

      // Act
      readerController.add(part1);
      // Give a moment to ensure the message is not emitted prematurely
      await Future.delayed(const Duration(milliseconds: 10));

      readerController.add(part2);
    });

    test(
      'should emit an error for a malformed message (not a 2-element array)',
      () async {
        // Arrange
        // Encodes `[0x21]`, which is an array of 1, not 2.
        final malformedBytes = MessagePackCodec().encode([
          MessageType.createEvaluatorResponse.value,
        ]);

        // Assert
        expect(transport.messages, emitsError(isA<PklBugError>()));

        // Act
        readerController.add(malformedBytes);
      },
    );

    test('should propagate an error from the reader stream', () async {
      // Arrange
      final error = Exception('Underlying stream failed');

      // Assert
      expect(transport.messages, emitsError(equals(error)));

      // Act
      readerController.addError(error);
    });

    test('close() should stop listening to the stream', () async {
      // Arrange
      final response = CreateEvaluatorResponse(requestId: 1, evaluatorId: 10);
      final bytes = MessagePackCodec().encode([
        MessageType.createEvaluatorResponse.value,
        response.propertyMap(),
      ]);

      // Act
      await transport.close();

      // Assert
      // The stream should be closed, so it should not emit anything.
      expect(transport.messages, neverEmits(anything));

      // This should now be a no-op as the listener is cancelled.
      readerController.add(bytes);
      await Future.delayed(const Duration(milliseconds: 10));
    });
  });
}
