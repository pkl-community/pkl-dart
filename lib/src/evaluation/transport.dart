import 'dart:async';
import 'dart:io';

import 'package:pkl_dart/src/message_pack/message_pack.dart';
import 'package:pkl_dart/src/serializer/message_serializer.dart';

import '../message.dart';
import 'manager_utils.dart';
import 'pkl_error.dart';

/// Copyright (c) 2025 Kirk Agbenyegah
///
/// This source code is licensed under the MIT license found in the
/// LICENSE file in the root directory of this source tree.

/// Defines the contract for a transport layer that sends and receives
/// messages to and from a Pkl server process.
abstract class MessageTransport {
  /// Sends a single message to the Pkl server.
  Future<void> send(ClientMessage message);

  /// A stream of all messages received from the Pkl server.
  Stream<ServerMessage> get messages;

  /// Closes the transport and any underlying resources (e.g., the child process).
  Future<void> close();
}

/// A base implementation of [MessageTransport] that handles the core
/// logic of encoding and decoding messages over streams.
abstract class BaseMessageTransport implements MessageTransport {
  late final MessagePackEncoder _encoder;
  late final MessagePackDecoder _decoder;
  late final Stream<ServerMessage> _messageStream;
  late final StreamSubscription<List<int>> _stdoutSubscription;
  late final StreamController<ServerMessage> _messageController;
  late final MessageSerializer _messageSerializer;

  bool _isClosed = false;

  BaseMessageTransport(Stream<List<int>> reader, IOSink writer) {
    _encoder = MessagePackEncoder.fromSink(writer);
    _decoder = MessagePackDecoder();
    _messageSerializer = MessageSerializer(encoder: _encoder, decoder: _decoder);
    _messageController = StreamController<ServerMessage>.broadcast();
    _messageStream = _messageController.stream;

    // Listen to the raw byte stream from the process's stdout.
    _stdoutSubscription = reader.listen(
      (data) {
        // Add incoming data to the decoder's internal buffer.
        _decoder.add(data);
        // Continuously attempt to decode messages from the buffer.
        // This handles cases where multiple messages arrive in one data chunk.
        while (true) {
          try {
            final decodedMessage = _decodeNextMessageFromBuffer();
            if (decodedMessage == null) {
              // Not enough data to decode a full message yet.
              // Wait for the next chunk of data.
              break;
            }
            _messageController.add(decodedMessage);
            // A message was successfully read. Compact the buffer to discard
            // the bytes for the message we just processed, saving memory.
            _decoder.compact();
          } on PklBugError catch (e, s) {
            // A decoding error is a bug in the protocol or implementation.
            if (!_isClosed) _messageController.addError(e, s);
            break;
          } catch (e, s) {
            // Catch other potential errors during decoding.
            if (!_isClosed) _messageController.addError(e, s);
            break;
          }
        }
      },
      onError: (error, stackTrace) {
        if (!_isClosed) {
          _messageController.addError(error, stackTrace);
        }
      },
      onDone: () {
        if (!_isClosed) {
          _messageController.close();
        }
      },
    );
  }

  /// Attempts to decode a single, complete message from the decoder's buffer.
  /// Returns `null` if the buffer doesn't contain a full message yet.
  ServerMessage? _decodeNextMessageFromBuffer() {
    try {
      return _messageSerializer.deserialize();
    } on IncompleteReadException {
      // This is the expected case when a message is only partially received.
      // The decoder should throw this to signal that it needs more data.
      // This ensures the partial data is kept for the next attempt.
      _decoder.reset();
      return null;
    } on TypeError {
      _decoder.reset();
      return null;
    }
  }

  @override
  Future<void> send(ClientMessage message) async {
    if (_isClosed) {
      throw PklError('Attempted to send a message on a closed transport.');
    }
    _messageSerializer.serialize(message);
  }

  @override
  Stream<ServerMessage> get messages => _messageStream;

  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    await _stdoutSubscription.cancel();
    await _messageController.close();
  }
}

/// A [MessageTransport] that communicates with Pkl by spawning it as a child process.
class ServerMessageTransport extends BaseMessageTransport {
  Process? _process;

  // Private constructor used by the factory.
  ServerMessageTransport._(this._process, Stream<List<int>> reader, IOSink writer)
    : super(reader, writer);

  /// Creates and starts a new [ServerMessageTransport].
  ///
  /// This is an async factory because it needs to start the Pkl child process.
  static Future<ServerMessageTransport> create({List<String>? pklCommand}) async {
    final command = pklCommand ?? await getPklCommand();
    final process = await Process.start(
      command[0],
      [...command.skip(1), 'server'],
      // Using runInShell on Windows can help with PATH resolution.
      runInShell: Platform.isWindows,
    );
    return ServerMessageTransport._(process, process.stdout, process.stdin);
  }

  /// For testing purposes
  /// Creates an instance without a process
  ServerMessageTransport.withoutProcess(super.reader, super.writer);

  @override
  Future<void> close() async {
    if (_process != null) {
      // Use SIGKILL for a more forceful shutdown, matching the Swift implementation's
      // intent to ensure the process is terminated.
      _process!.kill(ProcessSignal.sigkill);
      await _process!.exitCode;
      _process = null;
    }
    await super.close();
  }
}
