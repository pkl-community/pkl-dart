import 'dart:convert';
import 'dart:math';
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
/// 
/// NOTE: This Codec does not support extensions yet.
final class MessagePackCodec extends Codec<Object?, Uint8List> {
  final Object? Function(Object? value)? _reviver;
  final Object? Function(dynamic)? _toEncodable;

  const MessagePackCodec({
    Object? Function(Object? value)? reviver,
    Object? Function(dynamic object)? toEncodable,
  })  : _reviver = reviver,
        _toEncodable = toEncodable;

  /// A deserializer that converts binary data conforming to the MessagePack format to a Dart object
  ///
  /// This follows the spec as defined in https://github.com/msgpack/msgpack/blob/master/spec.md
  @override
  Converter<Uint8List, Object?> get decoder {
    if (_toEncodable case final toEncodable?)
      return MessagePackDeserializer(toEncodable);
    return const MessagePackDeserializer();
  }

  @override
  Converter<Object?, Uint8List> get encoder {
    if (_reviver case final reviver?) return MessagePackSerializer(reviver);
    return const MessagePackSerializer();
  }
}

class MessagePackSerializer extends Converter<Object?, Uint8List> {
  final Object? Function(Object? value)? _reviver;

  const MessagePackSerializer([Object? Function(Object? value)? reviver])
      : _reviver = reviver;

  @override
  Uint8List convert(Object? input) => _serializeMsgPack(input, _reviver);
}

class MessagePackDeserializer extends Converter<Uint8List, Object?> {
  final Object? Function(dynamic)? _toEncodable;

  const MessagePackDeserializer([Object? Function(dynamic object)? toEncodable])
      : _toEncodable = toEncodable;

  @override
  Object? convert(Uint8List input) => _deserializeMsgPack(input, _toEncodable);
}

Uint8List _serializeMsgPack(dynamic input,
    [Object? Function(Object)? reviver]) {
  BytesBuilder byteBuilder = BytesBuilder();

  switch (input) {
    case final int i when i < 0x80:
      byteBuilder.addByte(i);
      break;
    case null:
      byteBuilder.addByte(0xc0);
      break;
    case true:
      byteBuilder.addByte(0xc3);
      break;
    case false:
      byteBuilder.addByte(0xc2);
      break;
    case final int i when i < 0 && -i > 256:
      byteBuilder.addByte(0x100 - i);
      break;
    case final int i when i > 0:
      switch (BigInt.from(i).bitLength) {
        case <= 8:
          byteBuilder.add([0xcc, i]);
          break;
        case <= 16:
          byteBuilder.addByte(0xcd);
          final ByteData data = ByteData(2)..setUint16(0, i);
          byteBuilder.add(data.buffer.asUint8List());
          break;
        case <= 32:
          byteBuilder.addByte(0xce);
          final ByteData data = ByteData(4)..setUint32(0, i);
          byteBuilder.add(data.buffer.asUint8List());
          break;
        case <= 64:
          byteBuilder.addByte(0xcf);
          final ByteData data = ByteData(8)..setUint64(0, i);
          byteBuilder.add(data.buffer.asUint8List());
          break;
      }
    case final int i:
      final signedInt = BigInt.from(i);
      switch (BigInt.from(i).bitLength) {
        case <= 8:
          byteBuilder.add([0xd0, signedInt.toSigned(8).toInt()]);
          break;
        case <= 16:
          byteBuilder.addByte(0xd1);
          final ByteData data = ByteData(2)..setInt16(0, i);
          byteBuilder.add(data.buffer.asUint8List());
          break;
        case <= 32:
          byteBuilder.addByte(0xd2);
          final ByteData data = ByteData(4)..setInt32(0, i);
          byteBuilder.add(data.buffer.asUint8List());
          break;
        case <= 64:
          byteBuilder.addByte(0xd3);
          final ByteData data = ByteData(8)..setInt64(0, i);
          byteBuilder.add(data.buffer.asUint8List());
          break;
      }
    case final double f:
      final byteData = ByteData(8);
      byteData.setFloat64(0, f);
      byteBuilder.addByte(0xcb);
      byteBuilder.add(byteData.buffer.asUint8List());
      break;
    case final String s when s.length < 0x1f:
      byteBuilder.addByte(0xa0 | s.length);
      byteBuilder.add(s.codeUnits);
      break;
    case final String s when s.length <= 0xff:
      byteBuilder.addByte(0xd9);
      byteBuilder.add([s.length]);
      byteBuilder.add(s.codeUnits);
      break;
    case final String s when s.length <= 0xffff:
      byteBuilder.addByte(0xda);
      final ByteData data = ByteData(2)..setUint16(0, s.length);
      byteBuilder.add(data.buffer.asUint8List());
      byteBuilder.add(s.codeUnits);
      break;
    case final String s when s.length <= 0xffffffff:
      byteBuilder.addByte(0xdb);
      final ByteData data = ByteData(4)..setUint32(0, s.length);
      byteBuilder.add(data.buffer.asUint8List());
      byteBuilder.add(s.codeUnits);
      break;
    case Iterable l when l.length <= 15:
      byteBuilder.addByte(0x90 | l.length);
      for (final msg in l.map((item) => _serializeMsgPack(item, reviver))) {
        byteBuilder.add(msg);
      }
      break;
    case Iterable l when l.length <= 0xffff:
      byteBuilder.addByte(0xdc);
      final ByteData data = ByteData(2)..setUint16(0, l.length);
      byteBuilder.add(data.buffer.asUint8List());
      for (final msg in l.map((item) => _serializeMsgPack(item, reviver))) {
        byteBuilder.add(msg);
      }
      break;
    case Iterable l when l.length <= 0xffffffff:
      byteBuilder.addByte(0xdd);
      final ByteData data = ByteData(4)..setUint32(0, l.length);
      byteBuilder.add(data.buffer.asUint8List());
      for (final msg in l.map((item) => _serializeMsgPack(item, reviver))) {
        byteBuilder.add(msg);
      }
      break;
    case Map m when m.length <= 15:
      byteBuilder.addByte(0x80 | m.length);
      for (final entry in m.entries.map((e) => (
            _serializeMsgPack(e.key, reviver),
            _serializeMsgPack(e.value, reviver)
          ))) {
        byteBuilder.add(entry.$1);
        byteBuilder.add(entry.$2);
      }
      break;
    case Map m when m.length <= 0xffff:
      byteBuilder.addByte(0xdc);
      final ByteData data = ByteData(2)..setUint16(0, m.length);
      byteBuilder.add(data.buffer.asUint8List());
      for (final entry in m.entries.map((e) => (
            _serializeMsgPack(e.key, reviver),
            _serializeMsgPack(e.value, reviver)
          ))) {
        byteBuilder.add(entry.$1);
        byteBuilder.add(entry.$2);
      }
      break;
    case Map m when m.length <= 0xffffffff:
      byteBuilder.addByte(0xdd);
      final ByteData data = ByteData(4)..setUint32(0, m.length);
      byteBuilder.add(data.buffer.asUint8List());
      for (final entry in m.entries.map((e) => (
            _serializeMsgPack(e.key, reviver),
            _serializeMsgPack(e.value, reviver)
          ))) {
        byteBuilder.add(entry.$1);
        byteBuilder.add(entry.$2);
      }
      break;
  }

  return byteBuilder.toBytes();
}

Object? _deserializeMsgPack(Uint8List input,
    [Object? Function(dynamic)? toEncodable]) {
  final byteData = ByteData.view(input.buffer, input.offsetInBytes);
  var atIndex = 0;

  Object? _deserialize(Uint8List input) {
    final firstByte = input[atIndex++];

    switch (firstByte) {
      case 0xc0:
        return null;
      case 0xc2:
        return false;
      case 0xc3:
        return true;
      case < 0x80:
        // fixed integer
        return firstByte;
      case final int i when (i & 0xe0) == 0xe0:
        // negative integer
        return firstByte - 0x100;
      case >= 0xcc && <= 0xcf:
        // unsigned int 8, 16, etc
        final diff = firstByte - 0xcc;
        var value = switch (firstByte - 0xcc) {
          0 => byteData.getUint8(atIndex),
          1 => byteData.getUint16(atIndex),
          2 => byteData.getUint32(atIndex),
          3 => byteData.getUint64(atIndex),
          _ => throw Exception()
        };
        atIndex += pow(2, diff) as int;
        return value;
      case >= 0xd0 && <= 0xd3:
        // int 8, 16, etc
        var diff = firstByte - 0xd0;
        var value = switch (diff) {
          0 => byteData.getInt8(atIndex),
          1 => byteData.getInt16(atIndex),
          2 => byteData.getInt32(atIndex),
          3 => byteData.getInt64(atIndex),
          _ => throw Exception()
        };
        atIndex += pow(2, diff) as int;
        return value;
      case 0xca:
        // float32

        var float32 = byteData.getFloat32(atIndex);
        atIndex += 4;
        return float32;
      case 0xcb:
        // float64
        var float64 = byteData.getFloat64(atIndex);
        atIndex += 8;
        return float64;
      case final int i when (i & 0xe0) == 0xa0:
        // fixed string
        final len = i & 0x1f;
        final data =
            Uint8List.view(input.buffer, input.offsetInBytes + atIndex, len);
        atIndex += len;
        return String.fromCharCodes(data);
      case >= 0xd9 && <= 0xdb:
        // string with var lengths
        final diff = firstByte - 0xd9;
        final len = switch (firstByte) {
          0xd9 => byteData.getUint8(atIndex),
          0xda => byteData.getUint16(atIndex),
          0xdb => byteData.getUint32(atIndex),
          _ => throw Exception()
        };
        atIndex += pow(2, diff) as int;
        final data =
            Uint8List.view(input.buffer, input.offsetInBytes + atIndex, len);
        atIndex += len;
        return String.fromCharCodes(data);
      case >= 0xc4 && <= 0xc6:
        // binary format (byte array)
        final diff = firstByte - 0xc4;
        final len = switch (firstByte) {
          0xc4 => byteData.getUint8(atIndex),
          0xc5 => byteData.getUint16(atIndex),
          0xc6 => byteData.getUint32(atIndex),
          _ => throw Exception()
        };
        atIndex += pow(2, diff) as int;
        atIndex += len;
        return Uint8List.view(input.buffer, input.offsetInBytes + atIndex, len);
      case final int i when (i & 0xf0) == 0x90:
        // array
        final length = i & 0x0f;
        final value = [];
        for (int j = 0; j < length; j++) {
          value.add(_deserialize(input));
        }
        return value;
      case 0xdc:
        // longer array
        final len = byteData.getUint16(atIndex);
        atIndex += 2;
        final value = [];
        for (int j = 0; j < len; j++) {
          value.add(_deserialize(input));
        }
        return value;
      case 0xdd:
        // even longer array
        final len = byteData.getUint32(atIndex);
        atIndex += 4;
        final value = [];
        for (int j = 0; j < len; j++) {
          value.add(_deserialize(input));
        }
        return value;
      case final int i when (i & 0xf0) == 0x80:
        // map
        final len = i & 0x0f;
        final map = {};
        for (int j = 0; j < len; j++) {
          final key = _deserialize(input);
          final value = _deserialize(input);
          map[key] = value;
        }
        return map;
      case 0xde:
        // larger map
        final len = byteData.getUint16(atIndex);
        atIndex += 2;
        final map = {};
        for (int j = 0; j < len; j++) {
          final key = _deserialize(input);
          final value = _deserialize(input);
          map[key] = value;
        }
        return map;
      case 0xdf:
        // even larger map
        final len = byteData.getUint32(atIndex);
        atIndex += 4;
        final map = {};
        for (int j = 0; j < len; j++) {
          final key = _deserialize(input);
          final value = _deserialize(input);
          map[key] = value;
        }
        return map;
      
    }
    // TODO: implement convert
    throw UnimplementedError();
  }

  return _deserialize(input);
}
