/// An extension type based on [int] 
/// to provide MessagePack format codes and checks.
extension type MessagePackFormat(int _) implements int {
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
