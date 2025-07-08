// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'package:equatable/equatable.dart';
import 'package:pkl_dart/src/serializer/pkl_decodable.dart';
import 'package:pkl_dart/src/serializer/pkl_value/pkl_object_decoder.dart';

class Animal extends Equatable implements PklDecodable {
  final String name;

  const Animal({required this.name});

  factory Animal.fromPkl(Map<String, dynamic> map) {
    final decoder = PklObjectDecoder(map);
    return Animal(name: decoder.decode('name'));
  }

  @override
  List<Object?> get props => [name];
}
