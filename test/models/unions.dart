// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'package:equatable/equatable.dart';
import 'package:pkl_dart/src/serializer/pkl_decodable.dart';
import 'package:pkl_dart/src/serializer/pkl_value/pkl_object_decoder.dart';

// --- Fruit Classes ---
abstract class Fruit extends Equatable implements PklDecodable {
  const Fruit();

  factory Fruit.fromPkl(Map<String, dynamic> map) {
    if (map.containsKey('isRipe')) return Banana.fromPkl(map);
    if (map.containsKey('isUsedForWine')) return Grape.fromPkl(map);
    if (map.containsKey('isRed')) return Apple.fromPkl(map);
    throw Exception('Unknown Fruit type: $map');
  }
}

class Banana extends Fruit {
  final bool isRipe;

  const Banana({required this.isRipe});

  factory Banana.fromPkl(Map<String, dynamic> map) =>
      Banana(isRipe: PklObjectDecoder(map).decode('isRipe'));

  @override
  List<Object?> get props => [isRipe];
}

class Grape extends Fruit {
  final bool isUsedForWine;

  const Grape({required this.isUsedForWine});

  factory Grape.fromPkl(Map<String, dynamic> map) =>
      Grape(isUsedForWine: PklObjectDecoder(map).decode('isUsedForWine'));

  @override
  List<Object?> get props => [isUsedForWine];
}

class Apple extends Fruit {
  final bool isRed;

  const Apple({required this.isRed});

  factory Apple.fromPkl(Map<String, dynamic> map) =>
      Apple(isRed: PklObjectDecoder(map).decode('isRed'));

  @override
  List<Object?> get props => [isRed];
}

// --- Animal Classes ---
abstract class UnionAnimal extends Equatable implements PklDecodable {
  final String name;

  const UnionAnimal({required this.name});

  factory UnionAnimal.fromPkl(Map<String, dynamic> map) {
    final name = map['name'] as String;
    if (name == 'Zebra') return Zebra.fromPkl(map);
    if (name == 'Donkey') return Donkey.fromPkl(map);
    throw Exception('Unknown Animal type: $map');
  }
}

class Zebra extends UnionAnimal {
  const Zebra() : super(name: 'Zebra');

  factory Zebra.fromPkl(Map<String, dynamic> map) => const Zebra();

  @override
  List<Object?> get props => [name];
}

class Donkey extends UnionAnimal {
  const Donkey() : super(name: 'Donkey');

  factory Donkey.fromPkl(Map<String, dynamic> map) => const Donkey();

  @override
  List<Object?> get props => [name];
}

// --- Shape Classes ---
abstract class Shape extends Equatable implements PklDecodable {
  const Shape();

  factory Shape.fromPkl(Map<String, dynamic> map) {
    if (map.containsKey('corners')) return Square.fromPkl(map);
    throw Exception('Unknown Shape type: $map');
  }
}

class Square extends Shape {
  final int corners;

  const Square({required this.corners});

  factory Square.fromPkl(Map<String, dynamic> map) =>
      Square(corners: PklObjectDecoder(map).decode('corners'));

  @override
  List<Object?> get props => [corners];
}
