import 'dart:convert';
import 'dart:typed_data';

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
/// final int decoded = msgPack.decode(encoded);
/// assert(decoded == 9);
/// ```
final class MessagePackCodec extends Codec<Object?, Uint8List> {
  const MessagePackCodec();

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
  Uint8List convert(Object? input) => _encodeValue(input);
}

class MessagePackDeserializer extends Converter<Uint8List, Object?> {
  final Object? Function(dynamic)? _toEncodable;

  const MessagePackDeserializer([Object? Function(dynamic object)? toEncodable])
      : _toEncodable = toEncodable;

  @override
  Object? convert(Uint8List input) => _deserializeMsgPack(input, _toEncodable);
}


