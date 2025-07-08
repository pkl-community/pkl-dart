// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'package:equatable/equatable.dart';
import 'dart:core';

import '../message_pack/message_pack_value.dart';
import '../serializer/pkl_decodable.dart';
import '../serializer/pkl_value/pkl_object_decoder.dart';

part 'pkl_value/duration.dart';

part 'pkl_value/data_size.dart';

/// Base sealed class for all Pkl non-primitive values.
sealed class PklValue extends Equatable {
  @override
  bool? get stringify => true;

  const PklValue();
}

/// Represents a Pkl `Typed` or `Dynamic` value.
class PklObject extends PklValue {
  /// Fully qualified class name
  final String fqcn;

  /// Enclosing module URI
  final String moduleUri;

  final List<PklMember> members;

  const PklObject({required this.fqcn, required this.moduleUri, this.members = const []});

  @override
  List<Object?> get props => [fqcn, moduleUri, members];
}

/// Represents a Pkl `Map` value.
class PklMap extends PklValue {
  final Map<dynamic, dynamic> data;

  const PklMap(this.data);

  /// Convert from dart map to [this]
  factory PklMap.fromMap(Map<dynamic, dynamic> map) {
    return PklMap(Map.from(map));
  }

  @override
  List<Object?> get props => [data];
}

/// Represents a Pkl `Mapping` value.
class PklMapping extends PklValue {
  final Map<dynamic, dynamic> data;

  const PklMapping(this.data);

  /// Convert from dart map to [this]
  factory PklMapping.fromMap(Map<dynamic, dynamic> map) {
    return PklMapping(Map.from(map));
  }

  @override
  List<Object?> get props => [data];
}

/// Represents a Pkl `List` value.
class PklList extends PklValue {
  final List<dynamic> elements;

  const PklList(this.elements);

  /// Convert from dart list to [this]
  factory PklList.fromList(List<dynamic> list) {
    return PklList(List.from(list));
  }

  @override
  List<Object?> get props => [elements];
}

/// Represents a Pkl `Listing` value.
class PklListing extends PklValue {
  final List<dynamic> elements;

  const PklListing(this.elements);

  /// Convert from dart list to [this]
  factory PklListing.fromList(List<dynamic> list) {
    return PklListing(List.from(list));
  }

  @override
  List<Object?> get props => [elements];
}

/// Represents a Pkl `Set` value.
class PklSet extends PklValue {
  final Set<dynamic> elements;

  const PklSet(this.elements);

  /// Convert from dart list
  factory PklSet.fromList(List<dynamic> list) {
    return PklSet(Set.from(list));
  }

  @override
  List<Object?> get props => [elements];
}

/// Represents a Pkl `Pair` value.
class PklPair extends PklValue {
  final dynamic first;
  final dynamic second;

  const PklPair({required this.first, required this.second});

  @override
  List<Object?> get props => [first, second];
}

/// Represents a Pkl `IntSeq` value.
class PklIntSeq extends PklValue {
  final int start;
  final int end;
  final int step;

  const PklIntSeq({required this.start, required this.end, required this.step});

  @override
  List<Object?> get props => [start, end, step];
}

/// Represents a Pkl `Regex` value.
class PklRegex extends PklValue {
  final String value;

  const PklRegex({required this.value});

  @override
  List<Object?> get props => [value];
}

/// Represents a Pkl `Class` value.
class PklClass extends PklValue {
  const PklClass();

  @override
  List<Object?> get props => [];
}

/// Represents a Pkl `TypeAlias` value.
class PklTypeAlias extends PklValue {
  const PklTypeAlias();

  @override
  List<Object?> get props => [];
}

/// Base sealed class for all Pkl object members.
sealed class PklMember extends Equatable {
  const PklMember();

  @override
  bool? get stringify => true;
}

/// Represents a Pkl `Property` member.
class PklProperty extends PklMember {
  final String key;
  final dynamic value; // Can be a primitive Dart type or another PklValue

  const PklProperty({required this.key, required this.value});

  @override
  List<Object?> get props => [key, value];
}

/// Represents a Pkl `Entry` member.
class PklEntry extends PklMember {
  final dynamic key; // Can be a primitive Dart type or another PklValue
  final dynamic value; // Can be a primitive Dart type or another PklValue

  const PklEntry({required this.key, required this.value});

  @override
  List<Object?> get props => [key, value];
}

/// Represents a Pkl `Element` member.
class PklElement extends PklMember {
  final int index;
  final dynamic value; // Can be a primitive Dart type or another PklValue

  const PklElement({required this.index, required this.value});

  @override
  List<Object?> get props => [index, value];
}
