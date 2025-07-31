import 'dart:convert';
import 'dart:typed_data';

import 'message_pack.dart';
import 'message_pack_format.dart';
import 'message_pack_value.dart';

/// Interface for reading MessagePack data with buffering support
abstract class MessagePackReader {
  Uint8List get raw;

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

/// Helper class for efficient sequential reading from a Uint8List.
class _ByteReader {
  final Uint8List _bytes;
  int offset = 0;

  _ByteReader(this._bytes);

  Uint8List get raw => _bytes;

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

/// Default reader implementation
///
// TODO(nikeokoronkwo): Implement this using [ByteData] rather than reimplementing
//  already existing functionality
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

MessagePackValue decodeMsgPackValue(
  Uint8List input, [
  MessagePackReader? reader,
]) {
  reader ??= _DefaultMessagePackReader(input);
  final formatByte = MessagePackFormat(reader.readByte());

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

    case MessagePackFormat.nil:
      return const MessagePackNil();
    case MessagePackFormat.booleanFalse:
      return const MessagePackBool(false);
    case MessagePackFormat.booleanTrue:
      return const MessagePackBool(true);
    case MessagePackFormat.bin8:
      final length = reader.readByte();
      return _decodeBinary(reader, length);
    case MessagePackFormat.bin16:
      final length = reader.readUint16();
      return _decodeBinary(reader, length);
    case MessagePackFormat.bin32:
      final length = reader.readUint32();
      return _decodeBinary(reader, length);
    case MessagePackFormat.ext8:
      final length = reader.readByte();
      final type = reader.readInt8();
      return _decodeExtension(reader, length, type);
    case MessagePackFormat.ext16:
      final length = reader.readUint16();
      final type = reader.readInt8();
      return _decodeExtension(reader, length, type);
    case MessagePackFormat.ext32:
      final length = reader.readUint32();
      final type = reader.readInt8();
      return _decodeExtension(reader, length, type);
    case MessagePackFormat.float32:
      return _decodeFloat32(reader);
    case MessagePackFormat.float64:
      return _decodeFloat64(reader);
    case MessagePackFormat.uint8:
      return MessagePackInt(reader.readByte());
    case MessagePackFormat.uint16:
      return MessagePackInt(reader.readUint16());
    case MessagePackFormat.uint32:
      return MessagePackInt(reader.readUint32());
    case MessagePackFormat.uint64:
      return MessagePackInt(reader.readUint64());
    case MessagePackFormat.int8:
      return MessagePackInt(reader.readInt8());
    case MessagePackFormat.int16:
      return MessagePackInt(reader.readInt16());
    case MessagePackFormat.int32:
      return MessagePackInt(reader.readInt32());
    case MessagePackFormat.int64:
      return MessagePackInt(reader.readInt64());
    case MessagePackFormat.fixext1:
      final type = reader.readInt8();
      return _decodeExtension(reader, 1, type);
    case MessagePackFormat.fixext2:
      final type = reader.readInt8();
      return _decodeExtension(reader, 2, type);
    case MessagePackFormat.fixext4:
      final type = reader.readInt8();
      return _decodeExtension(reader, 4, type);
    case MessagePackFormat.fixext8:
      final type = reader.readInt8();
      return _decodeExtension(reader, 8, type);
    case MessagePackFormat.fixext16:
      final type = reader.readInt8();
      return _decodeExtension(reader, 16, type);
    case MessagePackFormat.str8:
      final length = reader.readByte();
      return _decodeString(reader, length);
    case MessagePackFormat.str16:
      final length = reader.readUint16();
      return _decodeString(reader, length);
    case MessagePackFormat.str32:
      final length = reader.readUint32();
      return _decodeString(reader, length);
    case MessagePackFormat.array16:
      final length = reader.readUint16();
      return _decodeList(reader, length);
    case MessagePackFormat.array32:
      final length = reader.readUint32();
      return _decodeList(reader, length);
    case MessagePackFormat.map16:
      final length = reader.readUint16();
      return _decodeMap(reader, length);
    case MessagePackFormat.map32:
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
    list.add(decodeMsgPackValue(reader.raw, reader));
  }
  return MessagePackArray(list);
}

/// Decodes a Map from the reader.
MessagePackMap _decodeMap(MessagePackReader reader, int length) {
  final map = <MessagePackValue, MessagePackValue>{};
  for (int i = 0; i < length; i++) {
    final key = decodeMsgPackValue(reader.raw, reader);
    final value = decodeMsgPackValue(reader.raw, reader);
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
