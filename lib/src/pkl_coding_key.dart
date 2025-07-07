/// Copyright (c) 2025 Kirk Agbenyegah
///
/// This source code is licensed under the MIT license found in the
/// LICENSE file in the root directory of this source tree.
/// A coding key implementation for Pkl serialization/deserialization.
class PklCodingKey {
  final String stringValue;
  final int? intValue;

  const PklCodingKey({required this.stringValue, this.intValue});

  /// Creates a [PklCodingKey] from an integer value.
  PklCodingKey.fromIntValue(int this.intValue) : stringValue = intValue.toString();

  /// Creates a [PklCodingKey] from another coding key.
  factory PklCodingKey.fromKey(PklCodingKey base) {
    if (base.intValue != null) {
      return PklCodingKey.fromIntValue(base.intValue!);
    } else {
      return PklCodingKey(stringValue: base.stringValue);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PklCodingKey &&
          runtimeType == other.runtimeType &&
          stringValue == other.stringValue &&
          intValue == other.intValue;

  @override
  int get hashCode => intValue?.hashCode ?? stringValue.hashCode;

  @override
  String toString() => 'PklCodingKey(stringValue: $stringValue, intValue: $intValue)';
}
