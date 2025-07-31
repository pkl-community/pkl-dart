import 'dart:convert';
import 'dart:typed_data';

import 'decoder.dart';
import 'encoder.dart';
import 'message_pack_value.dart';

const MessagePackCodec msgPack = MessagePackCodec();

/// A [MessagePackCodec] to convert to/from the [MessagePack Format](https://msgpack.org/index.html) to Dart
///
/// MessagePack is a binary format for JSON Data
///
/// Example:
/// ```dart
/// import 'dart:typed_data';
///
/// final int i = 9;
/// final Uint8List encoded = msgPack.encode(i);
/// assert(encoded.toList() == [0x09]);
///
/// final decoded = msgPack.decode(encoded);
/// assert(decoded.value == 9);
/// ```
final class MessagePackCodec extends Codec<Object?, Uint8List> {
  const MessagePackCodec();

  @override
  MessagePackValue decode(Uint8List encoded) {
    return super.decode(encoded) as MessagePackValue;
  }

  /// A deserializer that converts binary data conforming to the MessagePack format to a Dart object
  ///
  /// This follows the spec as defined in https://github.com/msgpack/msgpack/blob/master/spec.md
  @override
  Converter<Uint8List, Object?> get decoder => const MessagePackDeserializer();

  @override
  Converter<Object?, Uint8List> get encoder => const MessagePackSerializer();
}

class MessagePackSerializer extends Converter<Object?, Uint8List> {
  const MessagePackSerializer();

  @override
  Uint8List convert(Object? input) => encodeMsgPackValue(input);
}

class MessagePackDeserializer extends Converter<Uint8List, Object?> {
  const MessagePackDeserializer();

  @override
  MessagePackValue convert(Uint8List input) => decodeMsgPackValue(input);
}
