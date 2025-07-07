import 'package:equatable/equatable.dart';
import 'package:pkl_dart/src/serializer/pkl_decodable.dart';
import 'package:pkl_dart/src/serializer/pkl_value/pkl_object_decoder.dart';

/// Copyright (c) 2025 Kirk Agbenyegah
///
/// This source code is licensed under the MIT license found in the
/// LICENSE file in the root directory of this source tree.

abstract class Being extends Equatable implements PklDecodable {
  const Being();

  // This smart factory inspects the map to decide which concrete class to build.
  factory Being.fromPkl(Map<String, dynamic> map) {
    if (map.containsKey('barks')) return Dog.fromPkl(map);
    if (map.containsKey('flies')) return Bird.fromPkl(map);
    if (map.containsKey('name')) return Animal.fromPkl(map);
    throw Exception('Unknown Being type: $map');
  }
}

class Animal extends Being {
  final String name;

  const Animal({required this.name});

  factory Animal.fromPkl(Map<String, dynamic> map) {
    final decoder = PklObjectDecoder(map);
    return Animal(name: decoder.decode('name'));
  }

  @override
  List<Object?> get props => [name];
}

class Bird extends Being {
  final String name;
  final bool flies;

  const Bird({required this.name, required this.flies});

  factory Bird.fromPkl(Map<String, dynamic> map) {
    final decoder = PklObjectDecoder(map);
    return Bird(name: decoder.decode('name'), flies: decoder.decode('flies'));
  }

  @override
  List<Object?> get props => [name, flies];
}

class Dog extends Animal {
  final bool barks;
  final Animal? hates;

  const Dog({required super.name, required this.barks, this.hates});

  factory Dog.fromPkl(Map<String, dynamic> map) {
    final decoder = PklObjectDecoder(map);
    return Dog(
      name: decoder.decode('name'),
      barks: decoder.decode('barks'),
      hates: map.containsKey('hates') && map['hates'] != null
          ? decoder.decodeObject('hates', Animal.fromPkl)
          : null,
    );
  }

  @override
  List<Object?> get props => [name, barks, hates];
}
