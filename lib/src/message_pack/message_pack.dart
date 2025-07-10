// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../evaluation/logger.dart';

import 'message_pack_value.dart';

/// A codec for MessagePack serialization and deserialization.
class MessagePackCodec {
  final MessagePackWriter? _writer;
  final MessagePackReader? _reader;

  /// Creates a codec with optional custom writer and reader.
  const MessagePackCodec({MessagePackWriter? writer, MessagePackReader? reader})
    : _writer = writer,
      _reader = reader;

  /// Encodes a Dart object into a MessagePack byte array.
  /// Uses the provided writer or creates a default one.
  Uint8List encode(dynamic value) {
    final writer = _writer ?? DefaultMessagePackWriter();
    _encodeValue(writer, value);
    return writer.takeBytes();
  }

  /// Decodes a MessagePack byte array into a type-safe [MessagePackValue].
  /// Uses the provided reader or creates a default one.
  MessagePackValue decode(Uint8List bytes) {
    final reader = _reader ?? _DefaultMessagePackReader(bytes);
    return _decodeValue(reader);
  }

  /// Allows caller to add data directly to the internal buffer.
  /// Only works if a custom reader is provided.
  void add(List<int> data) {
    if (_reader == null) {
      throw StateError('Cannot add data without a custom reader');
    }
    _reader.add(data);
  }

  /// Decodes an array length from the current reader position.
  /// Used for streaming message protocols where array length indicates message structure.
  int decodeArrayLength() {
    if (_reader == null) {
      throw StateError('Cannot decode array length without a custom reader');
    }
    final formatByte = _reader.readByte();

    if (formatByte.isFixArray) {
      return formatByte & 0x0F;
    } else if (formatByte == _MessagePackFormat.array16) {
      return _reader.readUint16();
    } else if (formatByte == _MessagePackFormat.array32) {
      return _reader.readUint32();
    } else {
      throw MessagePackDeserializationException(
        'Expected array format, got: 0x${formatByte.toRadixString(16)}',
        _reader.offset - 1,
      );
    }
  }

  /// Generic decode method for specific types.
  /// Used in streaming contexts where the type is known.
  T decodeType<T>() {
    if (_reader == null) {
      throw StateError('Cannot decode without a custom reader');
    }
    try {
      return _decodeValue(_reader) as T;
    } on IncompleteReadException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // --- ENCODING ---

  /// Encodes any Dart value into the writer.
  void _encodeValue(MessagePackWriter writer, dynamic value) {
    switch (value) {
      case null:
        writer.writeByte(_MessagePackFormat.nil);
      case bool():
        writer.writeByte(
          value
              ? _MessagePackFormat.booleanTrue
              : _MessagePackFormat.booleanFalse,
        );
      case int():
        _encodeInt(writer, value);
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
        throw ArgumentError(
          'Unsupported type for MessagePack encoding: ${value.runtimeType}',
        );
    }
  }

  /// Encodes an integer, selecting the most compact format.
  void _encodeInt(MessagePackWriter writer, int value) {
    if (value >= 0 && value <= 127) {
      writer.writeByte(value);
    } else if (value >= -32 && value <= -1) {
      writer.writeByte(value);
    } else if (value >= 0 && value <= 255) {
      writer.writeByte(_MessagePackFormat.uint8);
      writer.writeByte(value);
    } else if (value >= -128 && value <= 127) {
      writer.writeByte(_MessagePackFormat.int8);
      writer.writeByte(value);
    } else if (value >= 0 && value <= 65535) {
      writer.writeByte(_MessagePackFormat.uint16);
      writer.writeBytes(_uint16ToBytes(value));
    } else if (value >= -32768 && value <= 32767) {
      writer.writeByte(_MessagePackFormat.int16);
      writer.writeBytes(_int16ToBytes(value));
    } else if (value >= 0 && value <= 4294967295) {
      writer.writeByte(_MessagePackFormat.uint32);
      writer.writeBytes(_uint32ToBytes(value));
    } else if (value >= -2147483648 && value <= 2147483647) {
      writer.writeByte(_MessagePackFormat.int32);
      writer.writeBytes(_int32ToBytes(value));
    } else if (value >= 0) {
      writer.writeByte(_MessagePackFormat.uint64);
      writer.writeBytes(_uint64ToBytes(value));
    } else {
      writer.writeByte(_MessagePackFormat.int64);
      writer.writeBytes(_int64ToBytes(value));
    }
  }

  /// Encodes a double as float64 for maximum precision.
  void _encodeDouble(MessagePackWriter writer, double value) {
    writer.writeByte(_MessagePackFormat.float64);
    writer.writeBytes(_double64ToBytes(value));
  }

  /// Encodes a String, selecting the most compact format.
  void _encodeString(MessagePackWriter writer, String value) {
    final bytes = utf8.encode(value);
    final length = bytes.length;

    if (length <= 31) {
      writer.writeByte(_MessagePackFormat.fixStrMin | length);
    } else if (length <= 0xFF) {
      writer.writeByte(_MessagePackFormat.str8);
      writer.writeByte(length);
    } else if (length <= 0xFFFF) {
      writer.writeByte(_MessagePackFormat.str16);
      writer.writeBytes(_uint16ToBytes(length));
    } else if (length <= 0xFFFFFFFF) {
      writer.writeByte(_MessagePackFormat.str32);
      writer.writeBytes(_uint32ToBytes(length));
    } else {
      throw ArgumentError(
        'String length exceeds MessagePack limit (2^32-1 bytes): $length',
      );
    }
    writer.writeBytes(bytes);
  }

  /// Encodes a Uint8List (Binary), selecting the most compact format.
  void _encodeBinary(MessagePackWriter writer, Uint8List value) {
    final length = value.length;

    if (length <= 0xFF) {
      writer.writeByte(_MessagePackFormat.bin8);
      writer.writeByte(length);
    } else if (length <= 0xFFFF) {
      writer.writeByte(_MessagePackFormat.bin16);
      writer.writeBytes(_uint16ToBytes(length));
    } else if (length <= 0xFFFFFFFF) {
      writer.writeByte(_MessagePackFormat.bin32);
      writer.writeBytes(_uint32ToBytes(length));
    } else {
      throw ArgumentError(
        'Binary length exceeds MessagePack limit (2^32-1 bytes): $length',
      );
    }
    writer.writeBytes(value);
  }

  /// Encodes a List (Array), selecting the most compact format.
  void _encodeList(MessagePackWriter writer, List value) {
    final length = value.length;

    if (length <= 15) {
      writer.writeByte(_MessagePackFormat.fixArrayMin | length);
    } else if (length <= 0xFFFF) {
      writer.writeByte(_MessagePackFormat.array16);
      writer.writeBytes(_uint16ToBytes(length));
    } else if (length <= 0xFFFFFFFF) {
      writer.writeByte(_MessagePackFormat.array32);
      writer.writeBytes(_uint32ToBytes(length));
    } else {
      throw ArgumentError(
        'Array length exceeds MessagePack limit (2^32-1 elements): $length',
      );
    }
    for (final item in value) {
      _encodeValue(writer, item);
    }
  }

  /// Encode array header
  void encodeArrayHeader(MessagePackWriter writer, int length) {
    if (length <= 15) {
      writer.writeBytes(
        Uint8List.fromList([_MessagePackFormat.fixArrayMin | length]),
      );
    } else if (length <= 0xFFFF) {
      final lengthBytes = _uint16ToBytes(length);
      writer.writeBytes(
        Uint8List.fromList([_MessagePackFormat.array16, ...lengthBytes]),
      );
    } else {
      final lengthBytes = _uint32ToBytes(length);
      writer.writeBytes(
        Uint8List.fromList([_MessagePackFormat.array32, ...lengthBytes]),
      );
    }
  }

  /// Encode map header
  void encodeMapHeader(MessagePackWriter writer, int length) {
    if (length <= 15) {
      writer.writeBytes(
        Uint8List.fromList([_MessagePackFormat.fixMapMin | length]),
      );
    } else if (length <= 0xFFFF) {
      final lengthBytes = _uint16ToBytes(length);
      writer.writeBytes(
        Uint8List.fromList([_MessagePackFormat.map16, ...lengthBytes]),
      );
    } else {
      final lengthBytes = _uint32ToBytes(length);
      writer.writeBytes(
        Uint8List.fromList([_MessagePackFormat.map32, ...lengthBytes]),
      );
    }
  }

  /// Encodes a Map, selecting the most compact format.
  void _encodeMap(MessagePackWriter writer, Map value) {
    final length = value.length;

    if (length <= 15) {
      writer.writeByte(_MessagePackFormat.fixMapMin | length);
    } else if (length <= 0xFFFF) {
      writer.writeByte(_MessagePackFormat.map16);
      writer.writeBytes(_uint16ToBytes(length));
    } else if (length <= 0xFFFFFFFF) {
      writer.writeByte(_MessagePackFormat.map32);
      writer.writeBytes(_uint32ToBytes(length));
    } else {
      throw ArgumentError(
        'Map length exceeds MessagePack limit (2^32-1 elements): $length',
      );
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
      writer.writeByte(_MessagePackFormat.fixext1);
    } else if (length == 2) {
      writer.writeByte(_MessagePackFormat.fixext2);
    } else if (length == 4) {
      writer.writeByte(_MessagePackFormat.fixext4);
    } else if (length == 8) {
      writer.writeByte(_MessagePackFormat.fixext8);
    } else if (length == 16) {
      writer.writeByte(_MessagePackFormat.fixext16);
    } else if (length <= 0xFF) {
      writer.writeByte(_MessagePackFormat.ext8);
      writer.writeByte(length);
    } else if (length <= 0xFFFF) {
      writer.writeByte(_MessagePackFormat.ext16);
      writer.writeBytes(_uint16ToBytes(length));
    } else if (length <= 0xFFFFFFFF) {
      writer.writeByte(_MessagePackFormat.ext32);
      writer.writeBytes(_uint32ToBytes(length));
    } else {
      throw ArgumentError(
        'Extension data length exceeds MessagePack limit (2^32-1 bytes): $length',
      );
    }
    writer.writeByte(ext.type);
    writer.writeBytes(ext.data);
  }

  // --- DECODING ---

  /// Decodes a value from the reader based on the current format byte.
  MessagePackValue _decodeValue(MessagePackReader reader) {
    final formatByte = reader.readByte();

    switch (formatByte) {
      case final b when b.isPositiveFixInt:
        return MessagePackInt(b);
      case final b when b.isNegativeFixInt:
        return MessagePackInt(b - 0x100);
      case final b when b.isFixMap:
        final length = b & 0x0F;
        return _decodeMap(reader, length);
      case final b when b.isFixArray:
        final length = b & 0x0F;
        return _decodeList(reader, length);
      case final b when b.isFixStr:
        final length = b & 0x1F;
        return _decodeString(reader, length);

      case _MessagePackFormat.nil:
        return const MessagePackNil();
      case _MessagePackFormat.booleanFalse:
        return const MessagePackBool(false);
      case _MessagePackFormat.booleanTrue:
        return const MessagePackBool(true);
      case _MessagePackFormat.bin8:
        final length = reader.readByte();
        return _decodeBinary(reader, length);
      case _MessagePackFormat.bin16:
        final length = reader.readUint16();
        return _decodeBinary(reader, length);
      case _MessagePackFormat.bin32:
        final length = reader.readUint32();
        return _decodeBinary(reader, length);
      case _MessagePackFormat.ext8:
        final length = reader.readByte();
        final type = reader.readInt8();
        return _decodeExtension(reader, length, type);
      case _MessagePackFormat.ext16:
        final length = reader.readUint16();
        final type = reader.readInt8();
        return _decodeExtension(reader, length, type);
      case _MessagePackFormat.ext32:
        final length = reader.readUint32();
        final type = reader.readInt8();
        return _decodeExtension(reader, length, type);
      case _MessagePackFormat.float32:
        return _decodeFloat32(reader);
      case _MessagePackFormat.float64:
        return _decodeFloat64(reader);
      case _MessagePackFormat.uint8:
        return MessagePackInt(reader.readByte());
      case _MessagePackFormat.uint16:
        return MessagePackInt(reader.readUint16());
      case _MessagePackFormat.uint32:
        return MessagePackInt(reader.readUint32());
      case _MessagePackFormat.uint64:
        return MessagePackInt(reader.readUint64());
      case _MessagePackFormat.int8:
        return MessagePackInt(reader.readInt8());
      case _MessagePackFormat.int16:
        return MessagePackInt(reader.readInt16());
      case _MessagePackFormat.int32:
        return MessagePackInt(reader.readInt32());
      case _MessagePackFormat.int64:
        return MessagePackInt(reader.readInt64());
      case _MessagePackFormat.fixext1:
        final type = reader.readInt8();
        return _decodeExtension(reader, 1, type);
      case _MessagePackFormat.fixext2:
        final type = reader.readInt8();
        return _decodeExtension(reader, 2, type);
      case _MessagePackFormat.fixext4:
        final type = reader.readInt8();
        return _decodeExtension(reader, 4, type);
      case _MessagePackFormat.fixext8:
        final type = reader.readInt8();
        return _decodeExtension(reader, 8, type);
      case _MessagePackFormat.fixext16:
        final type = reader.readInt8();
        return _decodeExtension(reader, 16, type);
      case _MessagePackFormat.str8:
        final length = reader.readByte();
        return _decodeString(reader, length);
      case _MessagePackFormat.str16:
        final length = reader.readUint16();
        return _decodeString(reader, length);
      case _MessagePackFormat.str32:
        final length = reader.readUint32();
        return _decodeString(reader, length);
      case _MessagePackFormat.array16:
        final length = reader.readUint16();
        return _decodeList(reader, length);
      case _MessagePackFormat.array32:
        final length = reader.readUint32();
        return _decodeList(reader, length);
      case _MessagePackFormat.map16:
        final length = reader.readUint16();
        return _decodeMap(reader, length);
      case _MessagePackFormat.map32:
        final length = reader.readUint32();
        return _decodeMap(reader, length);
      default:
        throw MessagePackDeserializationException(
          'Unknown MessagePack format byte: 0x${formatByte.toRadixString(16)}',
          reader.offset - 1,
        );
    }
  }

  /// Decodes a String from the reader.
  MessagePackString _decodeString(MessagePackReader reader, int length) {
    final bytes = reader.readBytes(length);
    return MessagePackString(utf8.decode(bytes));
  }

  /// Decodes a Binary (Uint8List) from the reader.
  MessagePackBinary _decodeBinary(MessagePackReader reader, int length) {
    return MessagePackBinary(reader.readBytes(length));
  }

  /// Decodes a List from the reader.
  MessagePackArray _decodeList(MessagePackReader reader, int length) {
    final list = <MessagePackValue>[];
    for (int i = 0; i < length; i++) {
      list.add(_decodeValue(reader));
    }
    return MessagePackArray(list);
  }

  /// Decodes a Map from the reader.
  MessagePackMap _decodeMap(MessagePackReader reader, int length) {
    final map = <MessagePackValue, MessagePackValue>{};
    for (int i = 0; i < length; i++) {
      final key = _decodeValue(reader);
      final value = _decodeValue(reader);
      map[key] = value;
    }
    return MessagePackMap(map);
  }

  /// Decodes a Float32 from the reader.
  MessagePackFloat _decodeFloat32(MessagePackReader reader) {
    final buffer = reader.readBytesAsByteData(4);
    return MessagePackFloat(buffer.getFloat32(0, Endian.big));
  }

  /// Decodes a Float64 from the reader.
  MessagePackFloat _decodeFloat64(MessagePackReader reader) {
    final buffer = reader.readBytesAsByteData(8);
    return MessagePackFloat(buffer.getFloat64(0, Endian.big));
  }

  /// Decodes an Extension type from the reader.
  MessagePackExt _decodeExtension(
    MessagePackReader reader,
    int length,
    int type,
  ) {
    final offsetBeforeRead = reader.offset;
    final data = reader.readBytes(length);
    if (type == -1) {
      return MessagePackTimestamp.fromRawData(data, offsetBeforeRead);
    }
    return MessagePackExt(type, data);
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
}

/// Helper class for efficient sequential reading from a Uint8List.
class _ByteReader {
  final Uint8List _bytes;
  int offset = 0;

  _ByteReader(this._bytes);

  /// Reads a single byte and advances the offset.
  int readByte() {
    if (offset >= _bytes.length) {
      throw MessagePackDeserializationException(
        'Unexpected end of data while reading byte',
        offset,
      );
    }
    return _bytes[offset++];
  }

  /// Reads [length] bytes and advances the offset.
  Uint8List readBytes(int length) {
    if (offset + length > _bytes.length) {
      throw MessagePackDeserializationException(
        'Unexpected end of data while reading $length bytes',
        offset,
      );
    }
    final result = _bytes.sublist(offset, offset + length);
    offset += length;
    return result;
  }

  /// Internal helper to read a specific number of bytes and
  /// return them as a [ByteData] for numeric conversion.
  ByteData _readBytesAsByteData(int length) {
    return readBytes(length).buffer.asByteData();
  }

  // --- Reading various integer types (big-endian) ---

  int readInt8() => _readBytesAsByteData(1).getInt8(0);

  int readUint16() => _readBytesAsByteData(2).getUint16(0, Endian.big);

  int readInt16() => _readBytesAsByteData(2).getInt16(0, Endian.big);

  int readUint32() => _readBytesAsByteData(4).getUint32(0, Endian.big);

  int readInt32() => _readBytesAsByteData(4).getInt32(0, Endian.big);

  int readUint64() => _readBytesAsByteData(8).getUint64(0, Endian.big);

  int readInt64() => _readBytesAsByteData(8).getInt64(0, Endian.big);
}

/// Exception thrown when MessagePack decoding fails due to invalid data.
class MessagePackDeserializationException implements Exception {
  final String message;
  final int offset;

  MessagePackDeserializationException(this.message, this.offset);

  @override
  String toString() =>
      'MessagePackDeserializationException at offset $offset: $message';
}

/// Extension on `int` to provide MessagePack format codes and checks.
extension _MessagePackFormat on int {
  // --- Ranges ---
  bool get isPositiveFixInt => this >= 0x00 && this <= 0x7f;

  bool get isFixMap => this >= 0x80 && this <= 0x8f;

  bool get isFixArray => this >= 0x90 && this <= 0x9f;

  bool get isFixStr => this >= 0xa0 && this <= 0xbf;

  bool get isNegativeFixInt => this >= 0xe0 && this <= 0xff;

  // --- Single Value Constants ---
  static const int nil = 0xc0;

  // ignore: unused_field
  static const int neverUsed = 0xc1; // Reserved
  static const int booleanFalse = 0xc2;
  static const int booleanTrue = 0xc3;

  static const int bin8 = 0xc4;
  static const int bin16 = 0xc5;
  static const int bin32 = 0xc6;

  static const int ext8 = 0xc7;
  static const int ext16 = 0xc8;
  static const int ext32 = 0xc9;

  static const int float32 = 0xca;
  static const int float64 = 0xcb;

  static const int uint8 = 0xcc;
  static const int uint16 = 0xcd;
  static const int uint32 = 0xce;
  static const int uint64 = 0xcf;

  static const int int8 = 0xd0;
  static const int int16 = 0xd1;
  static const int int32 = 0xd2;
  static const int int64 = 0xd3;

  static const int fixext1 = 0xd4;
  static const int fixext2 = 0xd5;
  static const int fixext4 = 0xd6;
  static const int fixext8 = 0xd7;
  static const int fixext16 = 0xd8;

  static const int str8 = 0xd9;
  static const int str16 = 0xda;
  static const int str32 = 0xdb;

  static const int array16 = 0xdc;
  static const int array32 = 0xdd;

  static const int map16 = 0xde;
  static const int map32 = 0xdf;

  // --- Min values for encoding logic ---
  static const int fixMapMin = 0x80;
  static const int fixArrayMin = 0x90;
  static const int fixStrMin = 0xa0;
}

/// Interface for writing MessagePack data
abstract class MessagePackWriter {
  void writeByte(int byte);

  void writeBytes(Uint8List bytes);

  Uint8List takeBytes();
}

/// Default writer implementation using BytesBuilder
class DefaultMessagePackWriter implements MessagePackWriter {
  final BytesBuilder _buffer = BytesBuilder();

  @override
  void writeByte(int byte) => _buffer.addByte(byte);

  @override
  void writeBytes(Uint8List bytes) => _buffer.add(bytes);

  @override
  Uint8List takeBytes() => _buffer.takeBytes();
}

/// Writer that uses [IOSink] for streaming output
class _IOSinkMessagePackWriter implements MessagePackWriter {
  final IOSink _sink;

  _IOSinkMessagePackWriter(this._sink);

  @override
  void writeByte(int byte) {
    _sink.add([byte]);
  }

  @override
  void writeBytes(Uint8List bytes) {
    _sink.add(bytes);
  }

  @override
  Uint8List takeBytes() {
    // IOSink streams data immediately, so we can't "take" bytes
    // This method doesn't make sense for streaming writers
    Loggers.standardError.warn(
      message: "Can't take bytes from IOSinkMessagePackWriter",
      frameUri: '',
    );
    return Uint8List(0);
  }
}

/// Interface for reading MessagePack data with buffering support
abstract class MessagePackReader {
  int get offset;

  void add(List<int> data);

  bool get hasData;

  int readByte();

  Uint8List readBytes(int length);

  ByteData readBytesAsByteData(int length);

  int readInt8();

  int readUint16();

  int readInt16();

  int readUint32();

  int readInt32();

  int readUint64();

  int readInt64();

  /// Resets the read offset to the beginning of the buffer.
  ///
  /// This allows the buffered data to be read again from the start.
  void reset();

  /// Discards the already-read portion of the buffer and resets the offset.
  ///
  /// This is useful in streaming contexts to prevent the buffer from
  /// growing indefinitely.
  void compact();
}

/// Default reader implementation
class _DefaultMessagePackReader extends _ByteReader
    implements MessagePackReader {
  _DefaultMessagePackReader(super.bytes);

  @override
  ByteData readBytesAsByteData(int length) => _readBytesAsByteData(length);

  @override
  void add(List<int> data) {
    // _ByteReader works with immutable data, so this operation is not supported
    throw UnsupportedError(
      'Cannot add data to _DefaultMessagePackReader. Use _BufferedMessagePackReader instead.',
    );
  }

  @override
  bool get hasData => _bytes.isNotEmpty;

  @override
  void reset() {
    offset = 0;
  }

  @override
  void compact() {
    if (offset > 0 && offset <= _bytes.length) {
      _bytes.removeRange(0, offset);
      offset = 0;
    }
  }
}

/// Exception thrown when trying to read beyond available buffered data
class IncompleteReadException implements Exception {
  const IncompleteReadException();
}

/// Default reader implementation with buffering support
class _BufferedMessagePackReader implements MessagePackReader {
  final List<int> _buffer = <int>[];
  int _offset = 0;

  @override
  int get offset => _offset;

  @override
  bool get hasData => _offset < _buffer.length;

  @override
  void add(List<int> data) {
    _buffer.addAll(data);
  }

  @override
  void reset() {
    _offset = 0;
  }

  @override
  void compact() {
    if (_offset > 0 && _offset <= _buffer.length) {
      _buffer.removeRange(0, _offset);
    }
    _offset = 0;
  }

  int _readByte() {
    if (_offset >= _buffer.length) {
      throw const IncompleteReadException();
    }
    return _buffer[_offset++];
  }

  Uint8List _readBytes(int length) {
    if (_offset + length > _buffer.length) {
      throw const IncompleteReadException();
    }
    final result = Uint8List.fromList(
      _buffer.sublist(_offset, _offset + length),
    );
    _offset += length;
    return result;
  }

  @override
  int readByte() => _readByte();

  @override
  Uint8List readBytes(int length) => _readBytes(length);

  @override
  ByteData readBytesAsByteData(int length) =>
      _readBytes(length).buffer.asByteData();

  @override
  int readInt8() => readBytesAsByteData(1).getInt8(0);

  @override
  int readUint16() => readBytesAsByteData(2).getUint16(0, Endian.big);

  @override
  int readInt16() => readBytesAsByteData(2).getInt16(0, Endian.big);

  @override
  int readUint32() => readBytesAsByteData(4).getUint32(0, Endian.big);

  @override
  int readInt32() => readBytesAsByteData(4).getInt32(0, Endian.big);

  @override
  int readUint64() => readBytesAsByteData(8).getUint64(0, Endian.big);

  @override
  int readInt64() => readBytesAsByteData(8).getInt64(0, Endian.big);
}

/// Convenience classes for the transport usage pattern
class MessagePackEncoder {
  final MessagePackWriter writer;
  final MessagePackCodec _codec;

  MessagePackEncoder(this.writer) : _codec = MessagePackCodec(writer: writer);

  static MessagePackEncoder fromSink(IOSink sink) {
    final writer = _IOSinkMessagePackWriter(sink);
    return MessagePackEncoder(writer);
  }

  void encode(dynamic value) {
    _codec._encodeValue(writer, value);
  }

  void encodeArrayHeader(int length) =>
      _codec.encodeArrayHeader(writer, length);

  void encodeMapHeader(int length) => _codec.encodeMapHeader(writer, length);
}

class MessagePackDecoder {
  final MessagePackCodec _codec;

  MessagePackDecoder()
    : _codec = MessagePackCodec(reader: _BufferedMessagePackReader());

  void add(List<int> data) => _codec.add(data);

  int decodeArrayLength() => _codec.decodeArrayLength();

  T decode<T>() => _codec.decodeType<T>();

  /// Resets the read offset to the beginning of the buffer, allowing a re-read.
  void reset() => _codec._reader?.reset();

  /// Discards the already-read portion of the buffer to save memory.
  void compact() => _codec._reader?.compact();
}
