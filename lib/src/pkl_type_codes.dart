// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

abstract class PklTypeCodes {
  static const int object = 0x1;
  static const int map = 0x2;
  static const int mapping = 0x3;
  static const int list = 0x4;
  static const int listing = 0x5;
  static const int set = 0x6;
  static const int duration = 0x7;
  static const int dataSize = 0x8;
  static const int pair = 0x9;
  static const int intSeq = 0xA;
  static const int regex = 0xB;
  static const int classType = 0xC; // Renamed from 'class' to avoid keyword conflict
  static const int typeAlias = 0xD;

  // Object Member Codes
  static const int property = 0x10;
  static const int entry = 0x11;
  static const int element = 0x12;

  // For internal validation in decoder
  static const Set<int> allCodes = {
    object,
    map,
    mapping,
    list,
    listing,
    set,
    duration,
    dataSize,
    pair,
    intSeq,
    regex,
    classType,
    typeAlias,
  };

  static const Set<int> allMemberCodes = {property, entry, element};
}
