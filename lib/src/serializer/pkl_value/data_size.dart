part of '../pkl_data_model.dart';

/// Copyright (c) 2025 Kirk Agbenyegah
///
/// This source code is licensed under the MIT license found in the
/// LICENSE file in the root directory of this source tree.
/// DataSize is the Dart representation of Pkl's `pkl.DataSize`.
class DataSize extends PklValue implements PklDecodable {
  /// The value of this [DataSize] in the unit set in [unit].
  final double value;

  /// The unit of this [DataSize], for example, byte, kilobyte, megabyte.
  final DataSizeUnit unit;

  const DataSize(this.value, {required this.unit});

  /// Creates a DataSize with bytes.
  DataSize.bytes(num value) : this(value.toDouble(), unit: DataSizeUnit.b);

  /// Creates a DataSize with kilobytes.
  DataSize.kilobytes(num value) : this(value.toDouble(), unit: DataSizeUnit.kb);

  /// Creates a DataSize with kibibytes.
  DataSize.kibibytes(num value) : this(value.toDouble(), unit: DataSizeUnit.kib);

  /// Creates a DataSize with megabytes.
  DataSize.megabytes(num value) : this(value.toDouble(), unit: DataSizeUnit.mb);

  /// Creates a DataSize with mebibytes.
  DataSize.mebibytes(num value) : this(value.toDouble(), unit: DataSizeUnit.mib);

  /// Creates a DataSize with gigabytes.
  DataSize.gigabytes(num value) : this(value.toDouble(), unit: DataSizeUnit.gb);

  /// Creates a DataSize with gibibytes.
  DataSize.gibibytes(num value) : this(value.toDouble(), unit: DataSizeUnit.gib);

  /// Creates a DataSize with terabytes.
  DataSize.terabytes(num value) : this(value.toDouble(), unit: DataSizeUnit.tb);

  /// Creates a DataSize with tebibytes.
  DataSize.tebibytes(num value) : this(value.toDouble(), unit: DataSizeUnit.tib);

  /// Creates a DataSize with petabytes.
  DataSize.petabytes(num value) : this(value.toDouble(), unit: DataSizeUnit.pb);

  /// Creates a DataSize with pebibytes.
  DataSize.pebibytes(num value) : this(value.toDouble(), unit: DataSizeUnit.pib);

  /// Convert [elements] to a [DataSize].
  factory DataSize.fromMsp(List<MessagePackValue> elements) {
    final value = (elements[0] as MessagePackFloat).value;
    final unit = (elements[1] as MessagePackString).value;

    return DataSize(value, unit: DataSizeUnit.fromString(unit));
  }

  /// Implement [PklFactory<T>] contract
  factory DataSize.fromPkl(Map<String, dynamic> map) {
    final decoder = PklObjectDecoder(map);

    return DataSize(decoder.decode('value'), unit: DataSizeUnit.fromString(decoder.decode('unit')));
  }

  /// Converts this [DataSize] to the specified unit.
  DataSize toUnit(DataSizeUnit unit) {
    return DataSize(value * this.unit.factorForConversion(to: unit), unit: unit);
  }

  @override
  List<Object?> get props => [value, unit];

  @override
  String toString() => '${value.toString()}.${unit.name}';
}

/// A unit (magnitude) of data size.
enum DataSizeUnit {
  /// byte
  b,

  /// kilobyte
  kb,

  /// kibibyte
  kib,

  /// megabyte
  mb,

  /// mebibyte
  mib,

  /// gigabyte
  gb,

  /// gibibyte
  gib,

  /// terabyte
  tb,

  /// tebibyte
  tib,

  /// petabyte
  pb,

  /// pebibyte
  pib;

  /// More verbose synonym.
  static const DataSizeUnit bytes = DataSizeUnit.b;

  /// More verbose synonym.
  static const DataSizeUnit kilobytes = DataSizeUnit.kb;

  /// More verbose synonym.
  static const DataSizeUnit kibibytes = DataSizeUnit.kib;

  /// More verbose synonym.
  static const DataSizeUnit megabytes = DataSizeUnit.mb;

  /// More verbose synonym.
  static const DataSizeUnit mebibytes = DataSizeUnit.mib;

  /// More verbose synonym.
  static const DataSizeUnit gigabytes = DataSizeUnit.gb;

  /// More verbose synonym.
  static const DataSizeUnit gibibytes = DataSizeUnit.gib;

  /// More verbose synonym.
  static const DataSizeUnit terabytes = DataSizeUnit.tb;

  /// More verbose synonym.
  static const DataSizeUnit tebibytes = DataSizeUnit.tib;

  /// More verbose synonym.
  static const DataSizeUnit petabytes = DataSizeUnit.pb;

  /// More verbose synonym.
  static const DataSizeUnit pebibytes = DataSizeUnit.pib;

  /// Return [this] from string value.
  static DataSizeUnit fromString(String value) {
    for (final unit in values) {
      if (unit.name == value) return unit;
    }

    return b;
  }

  int get inBytes {
    switch (this) {
      case DataSizeUnit.b:
        return 1;
      case DataSizeUnit.kb:
        return 1000;
      case DataSizeUnit.kib:
        return 1024;
      case DataSizeUnit.mb:
        return 1000000;
      case DataSizeUnit.mib:
        return 1048576;
      case DataSizeUnit.gb:
        return 1000000000;
      case DataSizeUnit.gib:
        return 1073741824;
      case DataSizeUnit.tb:
        return 1000000000000;
      case DataSizeUnit.tib:
        return 1099511627776;
      case DataSizeUnit.pb:
        return 1000000000000000;
      case DataSizeUnit.pib:
        return 1125899906842624;
    }
  }

  double factorForConversion({required DataSizeUnit to}) {
    return inBytes.toDouble() / to.inBytes.toDouble();
  }
}
