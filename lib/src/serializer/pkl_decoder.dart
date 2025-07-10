// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:typed_data';

import '../message_pack/message_pack.dart';
import '../message_pack/message_pack_value.dart';
import '../pkl_type_codes.dart';
import 'pkl_data_model.dart';

/// Decodes Pkl binary format (MessagePack) into Dart objects.
class PklDecoder {
  final MessagePackCodec _messagePackCodec = MessagePackCodec();

  /// Decodes Pkl binary format bytes into a Dart object.
  ///
  /// The returned object can be a primitive Dart type (null, bool, int, double, String, Uint8List),
  /// or a standard Dart [List] or [Map]
  /// for Pkl collections.
  ///
  /// Throws [MessagePackDeserializationException] or [FormatException] if the data is invalid.
  dynamic decode(Uint8List bytes) {
    final MessagePackValue mpValue = _messagePackCodec.decode(bytes);

    return _convert(mpValue);
  }

  /// Decodes Pkl binary format bytes to dart defined pkl representations.
  ///
  /// Throws [MessagePackDeserializationException] or [FormatException] if the data is invalid.
  dynamic decodePkl(Uint8List bytes) {
    final MessagePackValue mpValue = _messagePackCodec.decode(bytes);

    return _convertMessagePackValueToPkl(mpValue);
  }

  /// Recursively converts a [MessagePackValue] into its corresponding Pkl Dart object.
  dynamic _convertMessagePackValueToPkl(MessagePackValue mpValue) {
    if (mpValue is MessagePackArray) {
      if (mpValue.elements.isEmpty) {
        throw FormatException('Pkl array cannot be empty (missing type code).');
      }
      final typeCode = (mpValue.elements[0] as MessagePackInt).value;

      /// Check for [PlkClass] and [TypeAlias]
      if (typeCode == PklTypeCodes.classType) {
        return PklClass();
      }
      if (typeCode == PklTypeCodes.typeAlias) {
        return PklTypeAlias();
      }
      if (mpValue.elements.length < 2) {
        throw FormatException(
          "Expected array of at least 2 elements, but got ${mpValue.elements.length} elements.",
        );
      }

      final elements = mpValue.elements.sublist(1);

      switch (typeCode) {
        case PklTypeCodes.object:
          _checkElementLength(elements, 3);
          final fqcn = (elements[0] as MessagePackString).value;
          final moduleUri = (elements[1] as MessagePackString).value;
          final membersMp = elements[2] as MessagePackArray;
          final members = membersMp.elements
              .map(
                (m) => _convertMessagePackValueToPklMember(
                  (m as MessagePackArray).elements,
                ),
              )
              .toList();
          return PklObject(fqcn: fqcn, moduleUri: moduleUri, members: members);
        case PklTypeCodes.map:
        case PklTypeCodes.mapping:
          final mpMap = elements[0] as MessagePackMap;
          final decodedMap = mpMap.map.map(
            (k, v) => MapEntry(
              _convertMessagePackValueToPkl(k),
              _convertMessagePackValueToPkl(v),
            ),
          );
          return typeCode == PklTypeCodes.map
              ? PklMap.fromMap(decodedMap)
              : PklMapping.fromMap(decodedMap);
        case PklTypeCodes.list:
          return PklList.fromList(_mspArrayToList(elements));
        case PklTypeCodes.listing:
          return PklListing.fromList(_mspArrayToList(elements));
        case PklTypeCodes.set:
          return PklSet.fromList(_mspArrayToList(elements));
        case PklTypeCodes.duration:
          return PklDuration.fromMsp(elements);
        case PklTypeCodes.dataSize:
          return DataSize.fromMsp(elements);
        case PklTypeCodes.pair:
          final first = _convertMessagePackValueToPkl(elements[0]);
          final second = _convertMessagePackValueToPkl(elements[1]);
          return PklPair(first: first, second: second);
        case PklTypeCodes.intSeq:
          _checkElementLength(elements, 3);
          final start = (elements[0] as MessagePackInt).value;
          final end = (elements[1] as MessagePackInt).value;
          final step = (elements[2] as MessagePackInt).value;
          return PklIntSeq(start: start, end: end, step: step);
        case PklTypeCodes.regex:
          final regexString = (elements[0] as MessagePackString).value;
          return PklRegex(value: regexString);
        case PklTypeCodes.classType:
          return const PklClass();
        case PklTypeCodes.typeAlias:
          return const PklTypeAlias();
        case PklTypeCodes.property:
        case PklTypeCodes.entry:
        case PklTypeCodes.element:
          _checkElementLength(elements, 2);
          return _convertMessagePackValueToPklMember(mpValue.elements);
        default:
          throw FormatException('Unknown Pkl type code: $typeCode');
      }
    } else {
      // Primitive MessagePack value, return its raw Dart value
      return mpValue.value;
    }
  }

  List<dynamic> _mspArrayToList(List<MessagePackValue> elements) {
    final mpList = elements[0] as MessagePackArray;

    return mpList.elements
        .map((e) => _convertMessagePackValueToPkl(e))
        .toList();
  }

  /// Recursively converts a [MessagePackArray] representing a Pkl member into its corresponding Dart object.
  PklMember _convertMessagePackValueToPklMember(
    List<MessagePackValue> elements,
  ) {
    _checkElementLength(elements, 2);
    final memberTypeCode = (elements[0] as MessagePackInt).value;
    final memberElements = elements.sublist(1);

    switch (memberTypeCode) {
      case PklTypeCodes.property:
        final key = (memberElements[0] as MessagePackString).value;
        final value = _convertMessagePackValueToPkl(memberElements[1]);
        return PklProperty(key: key, value: value);
      case PklTypeCodes.entry:
        final key = _convertMessagePackValueToPkl(memberElements[0]);
        final value = _convertMessagePackValueToPkl(memberElements[1]);
        return PklEntry(key: key, value: value);
      case PklTypeCodes.element:
        final index = (memberElements[0] as MessagePackInt).value;
        final value = _convertMessagePackValueToPkl(memberElements[1]);
        return PklElement(index: index, value: value);
      default:
        throw FormatException('Unknown Pkl member type code: $memberTypeCode');
    }
  }

  /// Recursively converts a [MessagePackValue] into a standard Dart object.
  dynamic _convert(MessagePackValue mpValue) {
    if (mpValue is MessagePackArray) {
      if (mpValue.elements.isEmpty) {
        throw FormatException('Pkl array cannot be empty (missing type code).');
      }
      final typeCode = (mpValue.elements[0] as MessagePackInt).value;
      final elements = mpValue.elements.sublist(1);

      switch (typeCode) {
        case PklTypeCodes.object:
          _checkElementLength(elements, 3, 'PklObject');
          // We discard fqcn (elements[0]) and moduleUri (elements[1]) to
          // produce a clean Dart map.
          final membersMp = elements[2] as MessagePackArray;
          return _convertMembersToMap(membersMp.elements);

        case PklTypeCodes.map:
        case PklTypeCodes.mapping:
          _checkElementLength(elements, 1, 'PklMap/Mapping');
          final mpMap = elements[0] as MessagePackMap;
          return mpMap.map.map((k, v) => MapEntry(_convert(k), _convert(v)));

        case PklTypeCodes.list:
        case PklTypeCodes.listing:
          _checkElementLength(elements, 1, 'PklList/Listing');
          final mpList = elements[0] as MessagePackArray;
          return mpList.elements.map(_convert).toList();

        case PklTypeCodes.set:
          _checkElementLength(elements, 1, 'PklSet');
          final mpList = elements[0] as MessagePackArray;
          return mpList.elements.map(_convert).toSet();

        case PklTypeCodes.duration:
          _checkElementLength(elements, 2, 'PklDuration');
          final value = (elements[0] as MessagePackFloat).value;
          final unitName = (elements[1] as MessagePackString).value;
          return {'value': value, 'unit': unitName};

        case PklTypeCodes.dataSize:
          _checkElementLength(elements, 2, 'PklDataSize');
          final value = (elements[0] as MessagePackFloat).value;
          final unitName = (elements[1] as MessagePackString).value;
          return {'value': value, 'unit': unitName};

        case PklTypeCodes.pair:
          _checkElementLength(elements, 2, 'PklPair');
          return [_convert(elements[0]), _convert(elements[1])];

        case PklTypeCodes.intSeq:
          _checkElementLength(elements, 3, 'PklIntSeq');
          final start = (elements[0] as MessagePackInt).value;
          final end = (elements[1] as MessagePackInt).value;
          final step = (elements[2] as MessagePackInt).value;
          final List<int> seq = [];
          for (var i = start; i <= end; i += step) {
            seq.add(i);
          }
          return seq;

        case PklTypeCodes.regex:
          _checkElementLength(elements, 1, 'PklRegex');
          return RegExp((elements[0] as MessagePackString).value);

        case PklTypeCodes.classType:
          return {'pklType': 'pkl.Class'};

        case PklTypeCodes.typeAlias:
          return {'pklType': 'pkl.TypeAlias'};

        default:
          throw FormatException('Unknown Pkl type code: $typeCode');
      }
    } else {
      // It's a primitive MessagePack value, return its raw Dart value.
      return mpValue.value;
    }
  }

  /// Converts a list of Pkl members into a single Dart Map.
  Map<String, dynamic> _convertMembersToMap(List<MessagePackValue> members) {
    final Map<String, dynamic> result = {};
    for (final member in members) {
      if (member is! MessagePackArray || member.elements.length < 3) continue;

      final memberTypeCode = (member.elements[0] as MessagePackInt).value;
      final key = member.elements[1];
      final value = member.elements[2];

      switch (memberTypeCode) {
        case PklTypeCodes.property:
          // Key is always a string for properties.
          result[(key as MessagePackString).value] = _convert(value);
          break;
        case PklTypeCodes.entry:
          // For entries, the key can be complex. We convert it to a string
          // to fit into a standard Dart map.
          result[_convert(key).toString()] = _convert(value);
          break;
        case PklTypeCodes.element:
        // Indexed elements within a Pkl object don't map cleanly to a
        // standard Dart Map, so they are ignored in this conversion.
        // This matches the behavior of the previous PklConverter.
      }
    }
    return result;
  }

  /// Helper function to throw an exception when element length is less than [boundary]
  void _checkElementLength(
    List<MessagePackValue> elements,
    int boundary, [
    String? typeName,
  ]) {
    if (elements.length < boundary) {
      throw FormatException(
        '${typeName != null ? 'Invalid structure for $typeName. ' : ''}Expected at least $boundary elements, but got ${elements.length} elements.',
      );
    }
  }
}
