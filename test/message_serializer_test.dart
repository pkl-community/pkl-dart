// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'package:pkl_dart/src/evaluation/pkl_error.dart';
import 'package:pkl_dart/src/message.dart';
import 'package:pkl_dart/src/message_pack/message_pack.dart';
import 'package:pkl_dart/src/message_pack/message_pack_value.dart';
import 'package:pkl_dart/src/serializer/message_serializer.dart';
import 'package:pkl_dart/src/serializer/pkl_data_model.dart';
import 'package:pkl_dart/src/serializer/pkl_encoder.dart';
import 'package:test/test.dart';

void main() {
  group('MessageSerializer', () {
    late MessageSerializer serializer;
    late DefaultMessagePackWriter writer;
    late MessagePackDecoder verificationDecoder;

    setUp(() {
      // For serialization tests, we write to a buffer and then verify its contents.
      writer = DefaultMessagePackWriter();
      final encoder = MessagePackEncoder(writer);

      // For deserialization tests, we'll create a new decoder each time.
      // The serializer under test will also get its own decoder.
      final decoder = MessagePackDecoder();
      serializer = MessageSerializer(encoder: encoder, decoder: decoder);

      // This decoder is used by the test assertions to inspect the serialized output.
      verificationDecoder = MessagePackDecoder();
    });

    group('Serialization (Client Messages)', () {
      test('serializes a full CreateEvaluatorRequest correctly', () {
        final request = CreateEvaluatorRequest(
          requestId: 101,
          allowedModules: ['pkl:', 'file:'],
          allowedResources: ['https:'],
          clientModuleReaders: [
            ModuleReaderMessage(
              scheme: 'custom',
              hasHierarchicalUris: true,
              isLocal: false,
              isGlobbable: true,
            ),
          ],
          properties: {'foo': 'bar'},
          timeoutInSeconds: 30,
          cacheDir: '/tmp/pkl-cache',
        );

        serializer.serialize(request);
        final bytes = writer.takeBytes();
        verificationDecoder.add(bytes);

        final decodedArray = verificationDecoder.decode<MessagePackArray>().value;
        expect(decodedArray.length, 2);
        expect(decodedArray[0], MessageType.createEvaluatorRequest.value);

        final body = decodedArray[1] as Map;
        expect(body['requestId'], 101);
        expect(body['allowedModules'], ['pkl:', 'file:']);
        expect(body['allowedResources'], ['https:'], reason: 'Allowed resources should be present');
        expect(body['clientModuleReaders'], [
          {'scheme': 'custom', 'hasHierarchicalUris': true, 'isLocal': false, 'isGlobbable': true},
        ]);
        expect(body['properties'], {'foo': 'bar'});
        expect(body['timeoutInSeconds'], 30);
        expect(body['cacheDir'], '/tmp/pkl-cache');
      });

      test('omits null fields during serialization', () {
        final request = CreateEvaluatorRequest(requestId: 102);

        serializer.serialize(request);
        final bytes = writer.takeBytes();
        verificationDecoder.add(bytes);

        final decodedArray = verificationDecoder.decode<MessagePackArray>().value;
        final body = decodedArray[1] as Map;

        expect(body.length, 1, reason: 'Only non-null fields should be serialized');
        expect(body['requestId'], 102);
        expect(body.containsKey('allowedModules'), isFalse);
        expect(body.containsKey('properties'), isFalse);
        expect(body.containsKey('timeoutInSeconds'), isFalse);
      });

      test('serializes a one-way CloseEvaluatorRequest without a requestId', () {
        final request = CloseEvaluatorRequest(evaluatorId: 5);

        serializer.serialize(request);
        final bytes = writer.takeBytes();
        verificationDecoder.add(bytes);

        final decodedArray = verificationDecoder.decode<MessagePackArray>().value;
        expect(decodedArray[0], MessageType.closeEvaluator.value);

        final body = decodedArray[1] as Map;
        expect(body['evaluatorId'], 5);
        expect(
          body.containsKey('requestId'),
          isFalse,
          reason: 'One-way messages should not have a requestId',
        );
      });

      test('serializes an EvaluateRequest with module text', () {
        final request = EvaluateRequest(
          requestId: 103,
          evaluatorId: 1,
          moduleUri: Uri.parse('repl:text'),
          moduleText: 'foo = "bar"',
        );

        serializer.serialize(request);
        final bytes = writer.takeBytes();
        verificationDecoder.add(bytes);

        final decodedArray = verificationDecoder.decode<MessagePackArray>().value;
        final body = decodedArray[1] as Map;
        expect(body['requestId'], 103);
        expect(body['evaluatorId'], 1);
        expect(body['moduleUri'], 'repl:text');
        expect(body['moduleText'], 'foo = "bar"');
        expect(body.containsKey('expr'), isFalse);
      });
    });

    group('Deserialization (Server Messages)', () {
      MessagePackValue encodeAndPrepareForDecode(List<dynamic> message) {
        final bytes = MessagePackCodec().encode(message);
        serializer.decoder.add(bytes);
        return MessagePackCodec().decode(bytes);
      }

      test('deserializes a successful CreateEvaluatorResponse', () {
        final message = [
          MessageType.createEvaluatorResponse.value,
          {'requestId': 201, 'evaluatorId': 7},
        ];
        encodeAndPrepareForDecode(message);

        final result = serializer.deserialize();

        expect(result, isA<CreateEvaluatorResponse>());
        final typedResult = result as CreateEvaluatorResponse;
        expect(typedResult.requestId, 201);
        expect(typedResult.evaluatorId, 7);
        expect(typedResult.error, isNull);
      });

      test('deserializes a failed CreateEvaluatorResponse', () {
        final message = [
          MessageType.createEvaluatorResponse.value,
          {'requestId': 202, 'error': 'Invalid cache directory'},
        ];
        encodeAndPrepareForDecode(message);

        final result = serializer.deserialize();

        expect(result, isA<CreateEvaluatorResponse>());
        final typedResult = result as CreateEvaluatorResponse;
        expect(typedResult.requestId, 202);
        expect(typedResult.evaluatorId, isNull);
        expect(typedResult.error, 'Invalid cache directory');
      });

      test('deserializes a successful EvaluateResponse', () {
        final pklResultBytes = PklEncoder().encode(
          PklObject(fqcn: 'foo', moduleUri: 'bar', members: []),
        );
        final message = [
          MessageType.evaluateResponse.value,
          {'requestId': 203, 'evaluatorId': 7, 'result': pklResultBytes},
        ];
        encodeAndPrepareForDecode(message);

        final result = serializer.deserialize();

        expect(result, isA<EvaluateResponse>());
        final typedResult = result as EvaluateResponse;
        expect(typedResult.requestId, 203);
        expect(typedResult.evaluatorId, 7);
        expect(typedResult.result, pklResultBytes);
        expect(typedResult.error, isNull);
      });

      test('deserializes a LogMessage (one-way)', () {
        final message = [
          MessageType.logMessage.value,
          {
            'evaluatorId': 7,
            'level': 1, // warn
            'message': 'Something is deprecated',
            'frameUri': 'file:///app/config.pkl#foo',
          },
        ];
        encodeAndPrepareForDecode(message);

        final result = serializer.deserialize();

        expect(result, isA<LogMessage>());
        final typedResult = result as LogMessage;
        expect(typedResult.evaluatorId, 7);
        expect(typedResult.level, LogLevel.warn);
        expect(typedResult.message, 'Something is deprecated');
        expect(typedResult.frameUri, 'file:///app/config.pkl#foo');
        expect(typedResult.requestId, isNull);
      });

      test('deserializes a ReadModuleRequest', () {
        final message = [
          MessageType.readModuleRequest.value,
          {'requestId': 204, 'evaluatorId': 7, 'uri': 'custom-scheme:/path/to/module'},
        ];
        encodeAndPrepareForDecode(message);

        final result = serializer.deserialize();

        expect(result, isA<ReadModuleRequest>());
        final typedResult = result as ReadModuleRequest;
        expect(typedResult.requestId, 204);
        expect(typedResult.evaluatorId, 7);
        expect(typedResult.uri, Uri.parse('custom-scheme:/path/to/module'));
      });

      test('throws ArgumentError for unknown message code', () {
        final message = [
          0x99, // Unknown code
          {'requestId': 999},
        ];
        encodeAndPrepareForDecode(message);

        expect(
          () => serializer.deserialize(),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Unknown server message code'),
            ),
          ),
        );
      });

      test('throws PklBugError for malformed message (not enough elements)', () {
        final message = [MessageType.createEvaluatorResponse.value];
        encodeAndPrepareForDecode(message);

        expect(() => serializer.deserialize(), throwsA(isA<PklBugError>()));
      });
    });
  });
}
