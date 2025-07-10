import 'dart:typed_data';

import 'package:pkl_dart/src/message_pack/message_pack_format.dart';

/// Encodes any Dart value into the writer.
  Uint8List _encodeValue(dynamic value) {
    BytesBuilder byteBuilder = BytesBuilder();

    switch (value) {
      case null:
        byteBuilder.addByte(MessagePackFormat.nil);
      case bool():
        byteBuilder.addByte(value ? MessagePackFormat.booleanTrue : MessagePackFormat.booleanFalse);
      case int():
        _encodeInt(value);
      case double():
        _encodeDouble(writer, value);
      case String():
        _encodeString(writer, value);
      case Uint8List():
        _encodeBinary(writer, value);
      case List():
        _encodeList(writer, value);
      case Map():
        _encodeMap(writer, value);
      case MessagePackExt():
        _encodeExtension(writer, value);
      default:
        throw ArgumentError('Unsupported type for MessagePack encoding: ${value.runtimeType}');
    }

    return byteBuilder.toBytes();
  }

/// Encodes an integer, selecting the most compact format.
  void _encodeInt(int value, BytesBuilder builder) {
    switch (value) {
      case < 0x80:
        builder.addByte(value);
        break;
      
    }
    if (value >= 0 && value <= 127) {
      builder.addByte(value);
    } else if (value >= -32 && value <= -1) {
      writer.writeByte(value);
    } else if (value >= 0 && value <= 255) {
      writer.writeByte(MessagePackFormat.uint8);
      writer.writeByte(value);
    } else if (value >= -128 && value <= 127) {
      writer.writeByte(MessagePackFormat.int8);
      writer.writeByte(value);
    } else if (value >= 0 && value <= 65535) {
      writer.writeByte(MessagePackFormat.uint16);
      writer.writeBytes(_uint16ToBytes(value));
    } else if (value >= -32768 && value <= 32767) {
      writer.writeByte(MessagePackFormat.int16);
      writer.writeBytes(_int16ToBytes(value));
    } else if (value >= 0 && value <= 4294967295) {
      writer.writeByte(MessagePackFormat.uint32);
      writer.writeBytes(_uint32ToBytes(value));
    } else if (value >= -2147483648 && value <= 2147483647) {
      writer.writeByte(MessagePackFormat.int32);
      writer.writeBytes(_int32ToBytes(value));
    } else if (value >= 0) {
      writer.writeByte(MessagePackFormat.uint64);
      writer.writeBytes(_uint64ToBytes(value));
    } else {
      writer.writeByte(MessagePackFormat.int64);
      writer.writeBytes(_int64ToBytes(value));
    }
  }

  /// Encodes a double as float64 for maximum precision.
  void _encodeDouble(MessagePackWriter writer, double value) {
    writer.writeByte(MessagePackFormat.float64);
    writer.writeBytes(_double64ToBytes(value));
  }

  /// Encodes a String, selecting the most compact format.
  void _encodeString(MessagePackWriter writer, String value) {
    final bytes = utf8.encode(value);
    final length = bytes.length;

    if (length <= 31) {
      writer.writeByte(MessagePackFormat.fixStrMin | length);
    } else if (length <= 0xFF) {
      writer.writeByte(MessagePackFormat.str8);
      writer.writeByte(length);
    } else if (length <= 0xFFFF) {
      writer.writeByte(MessagePackFormat.str16);
      writer.writeBytes(_uint16ToBytes(length));
    } else if (length <= 0xFFFFFFFF) {
      writer.writeByte(MessagePackFormat.str32);
      writer.writeBytes(_uint32ToBytes(length));
    } else {
      throw ArgumentError('String length exceeds MessagePack limit (2^32-1 bytes): $length');
    }
    writer.writeBytes(bytes);
  }

  /// Encodes a Uint8List (Binary), selecting the most compact format.
  void _encodeBinary(MessagePackWriter writer, Uint8List value) {
    final length = value.length;

    if (length <= 0xFF) {
      writer.writeByte(MessagePackFormat.bin8);
      writer.writeByte(length);
    } else if (length <= 0xFFFF) {
      writer.writeByte(MessagePackFormat.bin16);
      writer.writeBytes(_uint16ToBytes(length));
    } else if (length <= 0xFFFFFFFF) {
      writer.writeByte(MessagePackFormat.bin32);
      writer.writeBytes(_uint32ToBytes(length));
    } else {
      throw ArgumentError('Binary length exceeds MessagePack limit (2^32-1 bytes): $length');
    }
    writer.writeBytes(value);
  }

  /// Encodes a List (Array), selecting the most compact format.
  void _encodeList(MessagePackWriter writer, List value) {
    final length = value.length;

    if (length <= 15) {
      writer.writeByte(MessagePackFormat.fixArrayMin | length);
    } else if (length <= 0xFFFF) {
      writer.writeByte(MessagePackFormat.array16);
      writer.writeBytes(_uint16ToBytes(length));
    } else if (length <= 0xFFFFFFFF) {
      writer.writeByte(MessagePackFormat.array32);
      writer.writeBytes(_uint32ToBytes(length));
    } else {
      throw ArgumentError('Array length exceeds MessagePack limit (2^32-1 elements): $length');
    }
    for (final item in value) {
      _encodeValue(writer, item);
    }
  }

  /// Encode array header
  void encodeArrayHeader(MessagePackWriter writer, int length) {
    if (length <= 15) {
      writer.writeBytes(Uint8List.fromList([MessagePackFormat.fixArrayMin | length]));
    } else if (length <= 0xFFFF) {
      final lengthBytes = _uint16ToBytes(length);
      writer.writeBytes(Uint8List.fromList([MessagePackFormat.array16, ...lengthBytes]));
    } else {
      final lengthBytes = _uint32ToBytes(length);
      writer.writeBytes(Uint8List.fromList([MessagePackFormat.array32, ...lengthBytes]));
    }
  }

  /// Encode map header
  void encodeMapHeader(MessagePackWriter writer, int length) {
    if (length <= 15) {
      writer.writeBytes(Uint8List.fromList([MessagePackFormat.fixMapMin | length]));
    } else if (length <= 0xFFFF) {
      final lengthBytes = _uint16ToBytes(length);
      writer.writeBytes(Uint8List.fromList([MessagePackFormat.map16, ...lengthBytes]));
    } else {
      final lengthBytes = _uint32ToBytes(length);
      writer.writeBytes(Uint8List.fromList([MessagePackFormat.map32, ...lengthBytes]));
    }
  }

  /// Encodes a Map, selecting the most compact format.
  void _encodeMap(MessagePackWriter writer, Map value) {
    final length = value.length;

    if (length <= 15) {
      writer.writeByte(MessagePackFormat.fixMapMin | length);
    } else if (length <= 0xFFFF) {
      writer.writeByte(MessagePackFormat.map16);
      writer.writeBytes(_uint16ToBytes(length));
    } else if (length <= 0xFFFFFFFF) {
      writer.writeByte(MessagePackFormat.map32);
      writer.writeBytes(_uint32ToBytes(length));
    } else {
      throw ArgumentError('Map length exceeds MessagePack limit (2^32-1 elements): $length');
    }
    value.forEach((key, val) {
      _encodeValue(writer, key);
      _encodeValue(writer, val);
    });
  }

  /// Encodes an Extension type, selecting the most compact format.
  void _encodeExtension(MessagePackWriter writer, MessagePackExt ext) {
    final length = ext.data.length;

    if (length == 1) {
      writer.writeByte(MessagePackFormat.fixext1);
    } else if (length == 2) {
      writer.writeByte(MessagePackFormat.fixext2);
    } else if (length == 4) {
      writer.writeByte(MessagePackFormat.fixext4);
    } else if (length == 8) {
      writer.writeByte(MessagePackFormat.fixext8);
    } else if (length == 16) {
      writer.writeByte(MessagePackFormat.fixext16);
    } else if (length <= 0xFF) {
      writer.writeByte(MessagePackFormat.ext8);
      writer.writeByte(length);
    } else if (length <= 0xFFFF) {
      writer.writeByte(MessagePackFormat.ext16);
      writer.writeBytes(_uint16ToBytes(length));
    } else if (length <= 0xFFFFFFFF) {
      writer.writeByte(MessagePackFormat.ext32);
      writer.writeBytes(_uint32ToBytes(length));
    } else {
      throw ArgumentError(
        'Extension data length exceeds MessagePack limit (2^32-1 bytes): $length',
      );
    }
    writer.writeByte(ext.type);
    writer.writeBytes(ext.data);
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