// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

part of '../pkl_data_model.dart';

/// Duration is the Dart representation of Pkl's `pkl.Duration`.
class PklDuration extends PklValue implements PklDecodable {
  /// The value of this [PklDuration] in the unit set in [unit].
  final double value;

  /// The unit of this [PklDuration], for example, millisecond, second, minute.
  final DurationUnit unit;

  const PklDuration(this.value, {required this.unit});

  /// Creates a Duration with nanoseconds.
  PklDuration.nanoseconds(num value) : this(value.toDouble(), unit: DurationUnit.ns);

  /// Creates a Duration with microseconds.
  PklDuration.microseconds(num value) : this(value.toDouble(), unit: DurationUnit.us);

  /// Creates a Duration with milliseconds.
  PklDuration.milliseconds(num value) : this(value.toDouble(), unit: DurationUnit.ms);

  /// Creates a Duration with seconds.
  PklDuration.seconds(num value) : this(value.toDouble(), unit: DurationUnit.s);

  /// Creates a Duration with minutes.
  PklDuration.minutes(num value) : this(value.toDouble(), unit: DurationUnit.min);

  /// Creates a Duration with hours.
  PklDuration.hours(num value) : this(value.toDouble(), unit: DurationUnit.h);

  /// Creates a Duration with days.
  PklDuration.days(num value) : this(value.toDouble(), unit: DurationUnit.d);

  /// Convert [elements] into a [PklDuration].
  factory PklDuration.fromMsp(List<MessagePackValue> elements) {
    final value = (elements[0] as MessagePackFloat).value;
    final unit = (elements[1] as MessagePackString).value;

    return PklDuration(value, unit: DurationUnit.fromString(unit));
  }

  /// Implement [PklFactory<T>] contract
  factory PklDuration.fromPkl(Map<String, dynamic> map) {
    final decoder = PklObjectDecoder(map);

    return PklDuration(
      decoder.decode('value'),
      unit: DurationUnit.fromString(decoder.decode('unit')),
    );
  }

  /// Converts this [PklDuration] to the specified unit.
  PklDuration toUnit(DurationUnit unit) {
    return PklDuration(value * this.unit.factorForConversion(to: unit), unit: unit);
  }

  /// Converts this duration to a Dart [PklDuration].
  Duration toDartDuration() {
    return Duration(microseconds: (value * unit.factorForConversion(to: DurationUnit.us)).round());
  }

  @override
  List<Object?> get props => [value, unit];

  @override
  String toString() => '${value.toString()}.${unit.name}';
}

/// Extension to convert Dart Duration to Pkl Duration.
extension DartDurationExtension on Duration {
  /// Converts this duration to a Pkl [PklDuration].
  PklDuration toPklDuration() {
    return PklDuration(inMicroseconds.toDouble(), unit: DurationUnit.us);
  }
}

/// A unit (magnitude) of duration.
enum DurationUnit {
  /// Nanosecond
  ns,

  /// Microsecond
  us,

  /// Millisecond
  ms,

  /// Second
  s,

  /// Minute
  min,

  /// Hour
  h,

  /// Day
  d;

  /// More verbose synonym.
  static const DurationUnit nanoseconds = DurationUnit.ns;

  /// More verbose synonym.
  static const DurationUnit microseconds = DurationUnit.us;

  /// More verbose synonym.
  static const DurationUnit milliseconds = DurationUnit.ms;

  /// More verbose synonym.
  static const DurationUnit seconds = DurationUnit.s;

  /// More verbose synonym.
  static const DurationUnit minutes = DurationUnit.min;

  /// More verbose synonym.
  static const DurationUnit hours = DurationUnit.h;

  /// More verbose synonym.
  static const DurationUnit days = DurationUnit.d;

  /// Return [this] from string
  static DurationUnit fromString(String value) {
    for (final unit in values) {
      if (unit.name == value) return unit;
    }

    return ms;
  }

  int get inNanoseconds {
    switch (this) {
      case DurationUnit.ns:
        return 1;
      case DurationUnit.us:
        return 1000;
      case DurationUnit.ms:
        return 1000000;
      case DurationUnit.s:
        return 1000000000;
      case DurationUnit.min:
        return 60000000000;
      case DurationUnit.h:
        return 3600000000000;
      case DurationUnit.d:
        return 86400000000000;
    }
  }

  double factorForConversion({required DurationUnit to}) {
    return inNanoseconds.toDouble() / to.inNanoseconds.toDouble();
  }
}
