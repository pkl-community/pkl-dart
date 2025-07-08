// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:typed_data';

import '../message_pack/message_pack.dart';
import '../pkl_type_codes.dart';
import 'pkl_data_model.dart';

/// Encodes Dart objects into Pkl binary format (MessagePack).
class PklEncoder {
  final MessagePackCodec _messagePackCodec = MessagePackCodec();

  /// Encodes a Dart object into Pkl binary format.
  ///
  /// [value] can be a primitive Dart type (null, bool, int, double, String, Uint8List)
  /// or an instance of a [PklValue] or [PklMember] class.
  ///
  /// Throws [ArgumentError] if an unsupported type is provided.
  Uint8List encode(dynamic value) {
    // Primitives are encoded directly by MessagePackCodec
    if (value == null ||
        value is bool ||
        value is int ||
        value is double ||
        value is String ||
        value is Uint8List) {
      return _messagePackCodec.encode(value);
    }

    // Pkl-specific types are converted to their MessagePack-encodable List/Map form
    if (value is PklValue || value is PklMember) {
      final dynamic pklEncodedValue = _convertPklToMessagePackEncodable(value);
      return _messagePackCodec.encode(pklEncodedValue);
    }

    throw ArgumentError(
      'Unsupported Pkl value type for encoding: ${value.runtimeType}. '
      'Pkl non-primitive types must be wrapped in PklValue or PklMember classes.',
    );
  }

  /// Converts a Pkl-specific Dart object into a MessagePack-encodable Dart object (List or Map).
  dynamic _convertPklToMessagePackEncodable(dynamic value) {
    if (value is PklValue) {
      switch (value) {
        case PklObject():
          return [
            PklTypeCodes.object,
            value.fqcn,
            value.moduleUri,
            value.members.map((m) => _convertPklToMessagePackEncodable(m)).toList(),
          ];
        case PklMap():
          final normalizedMap = value.data.entries.fold({}, (pm, e) {
            pm.putIfAbsent(
              _convertPklToMessagePackEncodable(e.key),
              () => _convertPklToMessagePackEncodable(e.value),
            );
            return pm;
          });

          return [PklTypeCodes.map, normalizedMap];
        case PklMapping():
          final normalizedMap = value.data.entries.fold({}, (pm, e) {
            pm.putIfAbsent(
              _convertPklToMessagePackEncodable(e.key),
              () => _convertPklToMessagePackEncodable(e.value),
            );
            return pm;
          });
          return [PklTypeCodes.mapping, normalizedMap];
        case PklList():
          final normalizedList = value.elements
              .map((e) => _convertPklToMessagePackEncodable(e))
              .toList();
          return [PklTypeCodes.list, normalizedList];
        case PklListing():
          final normalizedList = value.elements
              .map((e) => _convertPklToMessagePackEncodable(e))
              .toList();
          return [PklTypeCodes.listing, normalizedList];
        case PklSet():
          final normalizedSet = value.elements
              .map((e) => _convertPklToMessagePackEncodable(e))
              .toList();
          return [PklTypeCodes.set, normalizedSet];
        case PklPair():
          return [
            PklTypeCodes.pair,
            _convertPklToMessagePackEncodable(value.first),
            _convertPklToMessagePackEncodable(value.second),
          ];
        case PklIntSeq():
          return [PklTypeCodes.intSeq, value.start, value.end, value.step];
        case PklRegex():
          return [PklTypeCodes.regex, value.value];
        case PklClass():
          return [PklTypeCodes.classType];
        case PklTypeAlias():
          return [PklTypeCodes.typeAlias];
        case PklDuration():
          return [PklTypeCodes.duration, value.value, value.unit.name];
        case DataSize():
          return [PklTypeCodes.dataSize, value.value, value.unit.name];
      }
    } else if (value is PklMember) {
      switch (value) {
        case PklProperty():
          final key = (value).key;
          final pValue = _convertPklToMessagePackEncodable(value.value);
          return [PklTypeCodes.property, key, pValue];
        case PklEntry():
          final key = (value).key;
          final eValue = _convertPklToMessagePackEncodable(value.value);
          return [PklTypeCodes.entry, key, eValue];
        case PklElement():
          final index = (value).index;
          final eValue = _convertPklToMessagePackEncodable(value.value);
          return [PklTypeCodes.element, index, eValue];
      }
    } else {
      return value;
    }
  }
}
