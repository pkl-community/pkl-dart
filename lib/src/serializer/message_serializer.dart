// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:typed_data';

import '../evaluation/pkl_error.dart';
import '../message.dart';
import '../message_pack/message_pack.dart';
import '../message_pack/message_pack_value.dart';

/// A codec to serialize and deserialize messages between the client and server.
class MessageSerializer {
  final MessagePackEncoder encoder;
  final MessagePackDecoder decoder;

  const MessageSerializer({required this.encoder, required this.decoder});

  /// Serializes a [ClientMessage] into the provided [encoder].
  /// The first element of the array is a code that designates the message’s type, encoded as an int.
  /// The second element of the array is the message body, encoded as a map.
  void serialize(ClientMessage message) {
    final messageType = MessageType.getMessageType(message);
    encoder.encodeArrayHeader(2);
    encoder.encode(messageType.value);
    final body = message.propertyMap();
    encoder.encode(body);
  }

  /// Deserializes a [ServerMessage] using the message code and the [decoder].
  ServerMessage deserialize() {
    final message = decoder.decode<MessagePackArray>();
    if (message.elements.length < 2) {
      throw PklBugError.invalidMessageCode(
        'Expected MessagePack array of length 2, but got ${message.elements.length}',
      );
    }
    final code = (message.elements[0] as MessagePackInt);
    final type = MessageType.fromValue(code.value);
    if (type == null) {
      throw ArgumentError('Unknown server message code: $code');
    }

    final body = (message.elements[1] as MessagePackMap).value;
    final requestId = body['requestId'] as int?;

    switch (type) {
      case MessageType.createEvaluatorResponse:
        return CreateEvaluatorResponse(
          requestId: requestId!,
          evaluatorId: body['evaluatorId'] as int?,
          error: body['error'] as String?,
        );
      case MessageType.evaluateResponse:
        return EvaluateResponse(
          requestId: requestId!,
          evaluatorId: body['evaluatorId'] as int,
          result: body['result'] as Uint8List?,
          error: body['error'] as String?,
        );
      case MessageType.logMessage:
        return LogMessage(
          evaluatorId: body['evaluatorId'] as int,
          level: (body['level'] as int) == 0 ? LogLevel.trace : LogLevel.warn,
          message: body['message'] as String,
          frameUri: body['frameUri'] as String,
        );
      case MessageType.readResourceRequest:
        return ReadResourceRequest(
          requestId: requestId!,
          evaluatorId: body['evaluatorId'] as int,
          uri: Uri.parse(body['uri'] as String),
        );
      case MessageType.readModuleRequest:
        return ReadModuleRequest(
          requestId: requestId!,
          evaluatorId: body['evaluatorId'] as int,
          uri: Uri.parse(body['uri'] as String),
        );
      case MessageType.listResourcesRequest:
        return ListResourcesRequest(
          requestId: requestId!,
          evaluatorId: body['evaluatorId'] as int,
          uri: Uri.parse(body['uri'] as String),
        );
      case MessageType.listModulesRequest:
        return ListModulesRequest(
          requestId: requestId!,
          evaluatorId: body['evaluatorId'] as int,
          uri: Uri.parse(body['uri'] as String),
        );
      case MessageType.initializeModuleReaderRequest:
        return InitializeModuleReaderRequest(
          requestId: requestId!,
          scheme: body['scheme'] as String,
        );
      case MessageType.initializeResourceReaderRequest:
        return InitializeResourceReaderRequest(
          requestId: requestId!,
          scheme: body['scheme'] as String,
        );
      case MessageType.closeExternalProcess:
        return CloseExternalProcess();
      default:
        // We only care about messages coming from the server.
        throw ArgumentError('Invalid server message type: $type');
    }
  }
}
