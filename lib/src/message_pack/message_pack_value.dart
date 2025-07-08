// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:pkl_dart/src/message_pack/message_pack.dart'
    show MessagePackDeserializationException;

/// A sealed class representing any value that can be decoded from MessagePack.
///
/// This provides a type-safe way to handle decoded data, allowing for
/// exhaustive pattern matching.
sealed class MessagePackValue extends Equatable {
  const MessagePackValue();

  /// The underlying Dart value.
  ///
  /// This is a convenience accessor. Using pattern matching on `MessagePackValue`
  /// is the recommended way to handle different types.
  dynamic get value;
}

/// Represents the MessagePack `nil` value.
class MessagePackNil extends MessagePackValue {
  const MessagePackNil();

  @override
  dynamic get value => null;

  @override
  List<Object?> get props => [];

  @override
  String toString() => 'MessagePackNil()';
}

/// Represents a MessagePack `boolean` value.
class MessagePackBool extends MessagePackValue {
  @override
  final bool value;

  const MessagePackBool(this.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'MessagePackBool($value)';
}

/// Represents a MessagePack `integer` value.
class MessagePackInt extends MessagePackValue {
  @override
  final int value;

  const MessagePackInt(this.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'MessagePackInt($value)';
}

/// Represents a MessagePack `float` value.
class MessagePackFloat extends MessagePackValue {
  @override
  final double value;

  const MessagePackFloat(this.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'MessagePackFloat($value)';
}

/// Represents a MessagePack `string` value.
class MessagePackString extends MessagePackValue {
  @override
  final String value;

  const MessagePackString(this.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'MessagePackString("$value")';
}

/// Represents a MessagePack `binary` value.
class MessagePackBinary extends MessagePackValue {
  @override
  final Uint8List value;

  const MessagePackBinary(this.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'MessagePackBinary(length: ${value.length})';
}

/// Represents a MessagePack `array` value.
class MessagePackArray extends MessagePackValue {
  final List<MessagePackValue> elements;

  const MessagePackArray(this.elements);

  @override
  List<dynamic> get value => elements.map((e) => e.value).toList();

  @override
  List<Object?> get props => [elements];

  @override
  String toString() => 'MessagePackArray($elements)';
}

/// Represents a MessagePack `map` value.
class MessagePackMap extends MessagePackValue {
  final Map<MessagePackValue, MessagePackValue> map;

  const MessagePackMap(this.map);

  @override
  Map<dynamic, dynamic> get value => map.map((k, v) => MapEntry(k.value, v.value));

  @override
  List<Object?> get props => [map];

  @override
  String toString() => 'MessagePackMap($map)';
}

/// Represents a MessagePack Extension type.
/// Applications can define custom types using positive type codes.
/// Negative type codes are reserved for MessagePack predefined types (like Timestamp).
class MessagePackExt extends MessagePackValue {
  final int type;
  final Uint8List data;

  MessagePackExt(this.type, this.data) {
    if (type < -128 || type > 127) {
      throw ArgumentError('Extension type must be between -128 and 127.');
    }
  }

  @override
  MessagePackExt get value => this;

  @override
  List<Object?> get props => [type, data];
}

/// Represents a MessagePack Timestamp extension type.
/// Type code for Timestamp is -1.
class MessagePackTimestamp extends MessagePackExt {
  /// Seconds since Unix epoch. Can be negative for dates before 1970.
  final int seconds;

  /// Nanoseconds part of the timestamp (0-999,999,999).
  final int nanoseconds;

  MessagePackTimestamp(this.seconds, this.nanoseconds)
    : assert(
        nanoseconds >= 0 && nanoseconds <= 999999999,
        'Nanoseconds must be between 0 and 999,999,999',
      ),
      super(-1, _encodeTimestampData(seconds, nanoseconds));

  /// Internal constructor for creating from raw bytes during decoding.
  MessagePackTimestamp.fromRawData(Uint8List data, int offset)
    : seconds = _decodeSeconds(data, offset),
      nanoseconds = _decodeNanoseconds(data, offset),
      super(-1, data);

  /// Converts to DateTime in UTC.
  DateTime toDateTimeUtc() {
    return DateTime.fromMicrosecondsSinceEpoch(
      seconds * 1000000 + nanoseconds ~/ 1000,
      isUtc: true,
    );
  }

  // --- Encoding Timestamp Data ---
  static Uint8List _encodeTimestampData(int seconds, int nanoseconds) {
    // Timestamp 32: seconds <= 0xFFFFFFFF and nanoseconds == 0
    if (nanoseconds == 0 && seconds >= 0 && seconds <= 0xFFFFFFFF) {
      final buffer = ByteData(4);
      buffer.setUint32(0, seconds, Endian.big);
      return buffer.buffer.asUint8List();
    }

    // Timestamp 64: (nanoseconds << 34 | seconds)
    // This covers a wider range than timestamp 32, up to 2514-05-30 UTC
    if (seconds >= 0 && seconds < (1 << 34) && nanoseconds < (1 << 30)) {
      final buffer = ByteData(8);
      final int data64 = (nanoseconds << 34) | (seconds & 0x00000003FFFFFFFF);
      buffer.setUint64(0, data64, Endian.big);
      return buffer.buffer.asUint8List();
    }

    // Timestamp 96: other cases (32-bit nanoseconds, 64-bit seconds)
    final buffer = ByteData(12);
    buffer.setUint32(0, nanoseconds, Endian.big);
    buffer.setInt64(4, seconds, Endian.big); // seconds can be signed
    return buffer.buffer.asUint8List();
  }

  // --- Decoding Timestamp Data ---
  static int _decodeSeconds(Uint8List data, int offset) {
    final buffer = data.buffer.asByteData(data.offsetInBytes, data.length);
    switch (data.length) {
      case 4:
        return buffer.getUint32(0, Endian.big);
      case 8:
        return (buffer.getUint64(0, Endian.big) & 0x00000003FFFFFFFF)
            .toInt(); // Extract lower 34 bits
      case 12:
        return buffer.getInt64(4, Endian.big);
      default:
        throw MessagePackDeserializationException(
          'Invalid timestamp data length: ${data.length}',
          offset,
        );
    }
  }

  static int _decodeNanoseconds(Uint8List data, int offset) {
    final buffer = data.buffer.asByteData(data.offsetInBytes, data.length);
    switch (data.length) {
      case 4:
        return 0; // Timestamp 32 has 0 nanoseconds
      case 8:
        return (buffer.getUint64(0, Endian.big) >> 34).toInt(); // Extract upper 30 bits
      case 12:
        return buffer.getUint32(0, Endian.big);
      default:
        throw MessagePackDeserializationException(
          'Invalid timestamp data length: ${data.length}',
          offset,
        );
    }
  }
}
