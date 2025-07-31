import 'dart:convert';
import 'dart:typed_data';

import 'message_pack_format.dart';
import 'message_pack_value.dart';

/// Encodes any Dart value into the writer.
Uint8List encodeMsgPackValue(dynamic value, [BytesBuilder? byteBuilder]) {
  byteBuilder ??= BytesBuilder();

  switch (value) {
    case null:
      byteBuilder.addByte(MessagePackFormat.nil);
    case bool():
      byteBuilder.addByte(
        value ? MessagePackFormat.booleanTrue : MessagePackFormat.booleanFalse,
      );
    case int():
      _encodeInt(value, byteBuilder);
    case double():
      _encodeDouble(value, byteBuilder);
    case String():
      _encodeString(value, byteBuilder);
    case Uint8List():
      _encodeBinary(value, byteBuilder);
    case List():
      _encodeList(value, byteBuilder);
    case Map():
      _encodeMap(value, byteBuilder);
    case MessagePackExt():
      _encodeExtension(value, byteBuilder);
    default:
      throw ArgumentError(
        'Unsupported type for MessagePack encoding: ${value.runtimeType}',
      );
  }

  return byteBuilder.toBytes();
}

/// Encodes an integer, selecting the most compact format.
void _encodeInt(int value, BytesBuilder builder) {
  if (value >= 0) {
    switch (value) {
      case <= 127:
        builder.addByte(value);
        return;
      case <= 255:
        builder.addByte(MessagePackFormat.uint8);
        builder.addByte(value);
        return;
      case <= 65535:
        builder.addByte(MessagePackFormat.uint16);
        builder.add(_uint16ToBytes(value));
        return;
      case <= 4294967295:
        builder.addByte(MessagePackFormat.uint32);
        builder.add(_uint32ToBytes(value));
      default:
        builder.addByte(MessagePackFormat.uint64);
        builder.add(_uint64ToBytes(value));
        break;
    }
  } else {
    switch (value) {
      case >= -32 && <= -1:
        builder.addByte(value);
        return;
      case >= -128 && <= 127:
        builder.addByte(MessagePackFormat.int8);
        builder.addByte(value);
        return;
      case >= -32768 && <= 32767:
        builder.addByte(MessagePackFormat.int16);
        builder.add(_int16ToBytes(value));
        return;
      case >= -2147483648 && <= 2147483647:
        builder.addByte(MessagePackFormat.int32);
        builder.add(_int32ToBytes(value));
        return;
      default:
        builder.addByte(MessagePackFormat.int64);
        builder.add(_int64ToBytes(value));
        return;
    }
  }
}

/// Encodes a [double] as float64 for maximum precision.
void _encodeDouble(double value, BytesBuilder builder) {
  builder.addByte(MessagePackFormat.float64);
  builder.add(_double64ToBytes(value));
}

/// Encodes a [String], selecting the most compact format.
void _encodeString(String value, BytesBuilder builder) {
  final bytes = utf8.encode(value);
  final length = bytes.length;

  switch (length) {
    case <= 31:
      builder.addByte(MessagePackFormat.fixStrMin | length);
      break;
    case <= 0xff:
      builder.addByte(MessagePackFormat.str8);
      builder.addByte(length);
      break;
    case <= 0xffff:
      builder.addByte(MessagePackFormat.str16);
      builder.add(_uint16ToBytes(length));
      break;
    case <= 0xffffffff:
      builder.addByte(MessagePackFormat.str32);
      builder.add(_uint32ToBytes(length));
      break;
    default:
      throw ArgumentError(
        'String length exceeds MessagePack limit (2^32-1 bytes): $length',
      );
  }
  builder.add(bytes);
}

/// Encodes a [Uint8List] (Binary), selecting the most compact format.
void _encodeBinary(Uint8List value, BytesBuilder builder) {
  final length = value.length;

  if (length <= 0xFF) {
    builder.addByte(MessagePackFormat.bin8);
    builder.addByte(length);
  } else if (length <= 0xFFFF) {
    builder.addByte(MessagePackFormat.bin16);
    builder.add(_uint16ToBytes(length));
  } else if (length <= 0xFFFFFFFF) {
    builder.addByte(MessagePackFormat.bin32);
    builder.add(_uint32ToBytes(length));
  } else {
    throw ArgumentError(
      'Binary length exceeds MessagePack limit (2^32-1 bytes): $length',
    );
  }
  builder.add(value);
}

/// Encodes a [List] (Array), selecting the most compact format.
void _encodeList(List value, BytesBuilder builder) {
  final length = value.length;

  if (length <= 15) {
    builder.addByte(MessagePackFormat.fixArrayMin | length);
  } else if (length <= 0xFFFF) {
    builder.addByte(MessagePackFormat.array16);
    builder.add(_uint16ToBytes(length));
  } else if (length <= 0xFFFFFFFF) {
    builder.addByte(MessagePackFormat.array32);
    builder.add(_uint32ToBytes(length));
  } else {
    throw ArgumentError(
      'Array length exceeds MessagePack limit (2^32-1 elements): $length',
    );
  }
  for (final item in value) {
    encodeMsgPackValue(item, builder);
  }
}

/// Encode array header
void encodeArrayHeader(int length, BytesBuilder builder) {
  if (length <= 15) {
    builder.add(Uint8List.fromList([MessagePackFormat.fixArrayMin | length]));
  } else if (length <= 0xFFFF) {
    final lengthBytes = _uint16ToBytes(length);
    builder.add(
      Uint8List.fromList([MessagePackFormat.array16, ...lengthBytes]),
    );
  } else {
    final lengthBytes = _uint32ToBytes(length);
    builder.add(
      Uint8List.fromList([MessagePackFormat.array32, ...lengthBytes]),
    );
  }
}

/// Encode map header
void encodeMapHeader(int length, BytesBuilder builder) {
  if (length <= 15) {
    builder.add(Uint8List.fromList([MessagePackFormat.fixMapMin | length]));
  } else if (length <= 0xFFFF) {
    final lengthBytes = _uint16ToBytes(length);
    builder.add(Uint8List.fromList([MessagePackFormat.map16, ...lengthBytes]));
  } else {
    final lengthBytes = _uint32ToBytes(length);
    builder.add(Uint8List.fromList([MessagePackFormat.map32, ...lengthBytes]));
  }
}

/// Encodes a Map, selecting the most compact format.
void _encodeMap(Map value, BytesBuilder builder) {
  final length = value.length;

  if (length <= 15) {
    builder.addByte(MessagePackFormat.fixMapMin | length);
  } else if (length <= 0xFFFF) {
    builder.addByte(MessagePackFormat.map16);
    builder.add(_uint16ToBytes(length));
  } else if (length <= 0xFFFFFFFF) {
    builder.addByte(MessagePackFormat.map32);
    builder.add(_uint32ToBytes(length));
  } else {
    throw ArgumentError(
      'Map length exceeds MessagePack limit (2^32-1 elements): $length',
    );
  }
  value.forEach((key, val) {
    encodeMsgPackValue(key, builder);
    encodeMsgPackValue(val, builder);
  });
}

/// Encodes an Extension type, selecting the most compact format.
void _encodeExtension(MessagePackExt ext, BytesBuilder builder) {
  final length = ext.data.length;

  builder.addByte(switch (length) {
    1 => MessagePackFormat.fixext1,
    2 => MessagePackFormat.fixext2,
    4 => MessagePackFormat.fixext4,
    8 => MessagePackFormat.fixext8,
    16 => MessagePackFormat.fixext16,
    <= 0xFF => MessagePackFormat.ext8,
    <= 0xFFFF => MessagePackFormat.ext16,
    <= 0xFFFFFFFF => MessagePackFormat.ext32,
    _ => throw ArgumentError(
      'Extension data length exceeds MessagePack limit (2^32-1 bytes): $length',
    ),
  });

  if (![1, 2, 4, 8, 16].contains(length)) {
    if (length <= 0xFF) {
      builder.addByte(length);
    } else if (length <= 0xFFFF) {
      builder.add(_uint16ToBytes(length));
    } else if (length <= 0xFFFFFFFF) {
      builder.add(_uint32ToBytes(length));
    }
  }

  builder.addByte(ext.type);
  builder.add(ext.data);
}

// --- Helper methods for byte conversion ---

Uint8List _uint16ToBytes(int value) {
  final buffer = ByteData(2);
  buffer.setUint16(0, value, Endian.big);
  return buffer.buffer.asUint8List();
}

Uint8List _uint32ToBytes(int value) {
  final buffer = ByteData(4);
  buffer.setUint32(0, value, Endian.big);
  return buffer.buffer.asUint8List();
}

Uint8List _uint64ToBytes(int value) {
  final buffer = ByteData(8);
  buffer.setUint64(0, value, Endian.big);
  return buffer.buffer.asUint8List();
}

Uint8List _int16ToBytes(int value) {
  final buffer = ByteData(2);
  buffer.setInt16(0, value, Endian.big);
  return buffer.buffer.asUint8List();
}

Uint8List _int32ToBytes(int value) {
  final buffer = ByteData(4);
  buffer.setInt32(0, value, Endian.big);
  return buffer.buffer.asUint8List();
}

Uint8List _int64ToBytes(int value) {
  final buffer = ByteData(8);
  buffer.setInt64(0, value, Endian.big);
  return buffer.buffer.asUint8List();
}

Uint8List _double64ToBytes(double value) {
  final buffer = ByteData(8);
  buffer.setFloat64(0, value, Endian.big);
  return buffer.buffer.asUint8List();
}
