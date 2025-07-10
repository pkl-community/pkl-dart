// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'package:pkl_dart/src/message_pack/message_pack.dart';
import 'package:pkl_dart/src/message_pack/message_pack_value.dart';
import 'package:pkl_dart/src/message_pack/msgpack.dart';
import 'package:test/test.dart';

import 'fixtures/msgpack_test_data.dart';

void main() {
  group('MessagePackCodec', () {
    group('MessagePack Test Suite from JSON', () {
      mspTestData.forEach((fileName, tests) {
        group(fileName, () {
          for (final testCase in tests) {
            dynamic value = _getValueFromTestCase(testCase);
            final List<String> msgpackHexes = (testCase['msgpack'] as List)
                .cast<String>();

            // Skip tests for bignums that exceed Dart's int range (64-bit signed)
            if (value == null && testCase.containsKey('bignum')) {
              test(
                'Skipping bignum ${testCase['bignum']} (out of Dart int range)',
                () {},
              );
              continue; // Skip this test case
            }

            // Generate decoding tests for each msgpack representation
            for (int i = 0; i < msgpackHexes.length; i++) {
              final String msgpackHex = msgpackHexes[i];
              final Uint8List expectedBytes = hexToBytes(msgpackHex);

              test(
                'should decode ${value.runtimeType} $value from variant ${i + 1}',
                () {
                  final decoded = msgPack.decode(expectedBytes);
                  _assertDecodedValue(decoded, value);
                },
              );
            }

            // Generate encoding test (only once per value, as our encoder produces one canonical form)
            // We expect our encoder to produce one of the provided msgpack variants.
            test(
              'should encode ${value.runtimeType} $value to a valid variant',
              () {
                if (value is MessagePackBinary) {
                  value = (value as MessagePackBinary).value;
                }
                if (value is MessagePackExt) {
                  value = (value as MessagePackExt).value;
                }
                if (value is MessagePackInt) {
                  value = (value as MessagePackInt).value;
                }
                final encoded = msgPack.encode(value);
                bool encodedMatchesAnyVariant = false;
                for (final variantHex in msgpackHexes) {
                  if (const ListEquality().equals(
                    encoded,
                    hexToBytes(variantHex),
                  )) {
                    encodedMatchesAnyVariant = true;
                    break;
                  }
                }

                expect(
                  encodedMatchesAnyVariant,
                  isTrue,
                  reason:
                      'Encoder output must be one of the valid MessagePack variants',
                );
              },
            );
          }
        });
      });
    });
  });
}

// Helper function to convert a hexadecimal string (e.g., "b2-d0-9a") to a Uint8List.
Uint8List hexToBytes(String hex) {
  if (hex.isEmpty) {
    return Uint8List(0);
  }

  final List<int> bytes = [];
  final hexParts = hex.split('-');
  for (final part in hexParts) {
    bytes.add(int.parse(part, radix: 16));
  }

  return Uint8List.fromList(bytes);
}

// Helper to create MessagePackTimestamp from JSON data
MessagePackTimestamp _createTimestamp(List<dynamic> tsData) {
  return MessagePackTimestamp(tsData[0] as int, tsData[1] as int);
}

// Helper to create MessagePackExt from JSON data
MessagePackExt _createExt(List<dynamic> extData) {
  final type = extData[0] as int;
  final dataHex = extData[1] as String;
  return MessagePackExt(type, hexToBytes(dataHex));
}

// Helper to convert JSON values that might be nested complex types
dynamic _convertJsonValue(dynamic jsonValue, [String? key]) {
  /// Use the following conversion based on key
  /// `binary` -> [MessagePackBinary]
  /// `timestamp` -> [MessagePackTimestamp]
  /// `ext` -> [MessagePackExt]
  /// `bignum` -> [MessagePackInt]
  if (key != null) {
    switch (key) {
      case 'binary':
        return MessagePackBinary(hexToBytes(jsonValue as String));
      case 'timestamp':
        return _createTimestamp(jsonValue as List<dynamic>);
      case 'ext':
        return _createExt(jsonValue as List<dynamic>);
      case 'bignum':
        final value = BigInt.parse(jsonValue);
        if (value.isValidInt) {
          return MessagePackInt(value.toInt());
        } else {
          return null;
        }
    }
  }
  if (jsonValue is Map) {
    if (jsonValue.containsKey('nil')) {
      return null;
    } else if (jsonValue.containsKey('bool')) {
      return jsonValue['bool'];
    } else if (jsonValue.containsKey('number')) {
      return jsonValue['number'];
    } else if (jsonValue.containsKey('string')) {
      return jsonValue['string'];
    } else if (jsonValue.containsKey('binary')) {
      // Use MessagePackBinary directly as the expected value
      return MessagePackBinary(hexToBytes(jsonValue['binary'] as String));
    } else if (jsonValue.containsKey('array')) {
      return (jsonValue['array'] as List)
          .map((e) => _convertJsonValue(e))
          .toList();
    } else if (jsonValue.containsKey('map')) {
      return (jsonValue['map'] as Map).map(
        (k, v) => MapEntry(_convertJsonValue(k), _convertJsonValue(v)),
      );
    } else if (jsonValue.containsKey('timestamp')) {
      // Already returns MessagePackTimestamp
      return _createTimestamp(jsonValue['timestamp'] as List<dynamic>);
    } else if (jsonValue.containsKey('ext')) {
      // Already returns MessagePackExt
      return _createExt(jsonValue['ext'] as List<dynamic>);
    } else if (jsonValue.containsKey('bignum')) {
      final bignumStr = jsonValue['bignum'] as String;
      try {
        // Attempt to parse as int. Dart's int handles 64-bit signed.
        return int.parse(bignumStr);
      } catch (e) {
        // If parsing fails (e.g., too large for 64-bit signed int),
        // return null to indicate this test case should be skipped.
        print(
          'Warning: Bignum $bignumStr is out of Dart\'s 64-bit int range. Skipping test.',
        );
        return null;
      }
    }
    // If it's a generic map, recurse on its contents
    return jsonValue.map(
      (k, v) => MapEntry(_convertJsonValue(k), _convertJsonValue(v)),
    );
  } else if (jsonValue is List) {
    return jsonValue.map((e) => _convertJsonValue(e)).toList();
  }
  return jsonValue;
}

// Helper to extract the actual Dart value from a test case map
dynamic _getValueFromTestCase(
  Map<String, dynamic> testCase, [
  bool toEncode = false,
]) {
  // Find the single key that represents the value (excluding 'msgpack')
  final valueKey = testCase.keys.firstWhere((key) => key != 'msgpack');
  return _convertJsonValue(testCase[valueKey], toEncode ? null : valueKey);
}

// Helper for deep comparison of decoded MessagePackValue against expected raw Dart value
void _assertDecodedValue(MessagePackValue decoded, dynamic expectedValue) {
  if (expectedValue == null) {
    expect(
      decoded,
      isA<MessagePackNil>(),
      reason: 'Decoded value should be MessagePackNil',
    );
  } else if (expectedValue is bool) {
    expect(
      decoded,
      isA<MessagePackBool>(),
      reason: 'Decoded value should be MessagePackBool',
    );
    expect(
      (decoded as MessagePackBool).value,
      equals(expectedValue),
      reason: 'Decoded bool value mismatch',
    );
  } else if (expectedValue is num) {
    if (decoded is MessagePackInt) {
      expect(
        decoded.value,
        equals(expectedValue),
        reason: 'Decoded int value should match',
      );
    } else if (decoded is MessagePackFloat) {
      // Use closeTo for float comparison due to precision
      expect(
        decoded.value,
        closeTo(expectedValue.toDouble(), 1e-9),
        reason: 'Decoded float value should be close',
      );
    } else {
      fail('Decoded number is not MessagePackInt or MessagePackFloat');
    }
  } else if (expectedValue is String) {
    expect(
      decoded,
      isA<MessagePackString>(),
      reason: 'Decoded value should be MessagePackString',
    );
    expect(
      (decoded as MessagePackString).value,
      equals(expectedValue),
      reason: 'Decoded string value mismatch',
    );
  } else if (expectedValue is List) {
    // This is for raw Dart Lists, not MessagePackArray
    expect(
      decoded,
      isA<MessagePackArray>(),
      reason: 'Decoded value should be MessagePackArray',
    );
    final decodedArray = (decoded as MessagePackArray).elements;
    expect(
      decodedArray.length,
      equals(expectedValue.length),
      reason: 'Decoded array length mismatch',
    );
    for (int j = 0; j < expectedValue.length; j++) {
      // Recursive call, expectedValue[j] might be a raw Dart type or a MessagePackValue subclass
      _assertDecodedValue(decodedArray[j], expectedValue[j]);
    }
  } else if (expectedValue is Map) {
    // This is for raw Dart Maps, not MessagePackMap
    expect(
      decoded,
      isA<MessagePackMap>(),
      reason: 'Decoded value should be MessagePackMap',
    );
    final decodedMap = (decoded as MessagePackMap).map;
    expect(
      decodedMap.length,
      equals(expectedValue.length),
      reason: 'Decoded map length mismatch',
    );
    expectedValue.forEach((k, v) {
      // Find the corresponding key in the decoded map using _compareMessagePackValues
      final decodedKey = decodedMap.keys.firstWhere(
        (dk) => _compareMessagePackValues(dk, k),
        orElse: () => throw 'Key $k not found in decoded map',
      );
      _assertDecodedValue(
        decodedMap[decodedKey]!,
        v,
      ); // Recursive call for value
    });
  }
  // If expectedValue is already a MessagePackValue subclass (like MessagePackBinary, MessagePackTimestamp, MessagePackExt)
  else if (expectedValue is MessagePackValue) {
    expect(
      decoded,
      equals(expectedValue),
      reason: 'Decoded MessagePackValue subclass mismatch',
    );
  } else {
    fail(
      'Unhandled expected value type in _assertDecodedValue: ${expectedValue.runtimeType}',
    );
  }
}

// Helper for comparing MessagePackValue instances for map keys
bool _compareMessagePackValues(MessagePackValue mpValue, dynamic rawValue) {
  if (rawValue == null) {
    return mpValue is MessagePackNil;
  } else if (rawValue is bool) {
    return mpValue is MessagePackBool && mpValue.value == rawValue;
  } else if (rawValue is int) {
    return mpValue is MessagePackInt && mpValue.value == rawValue;
  } else if (rawValue is double) {
    return mpValue is MessagePackFloat &&
        (mpValue.value - rawValue).abs() < 1e-9;
  } else if (rawValue is String) {
    return mpValue is MessagePackString && mpValue.value == rawValue;
  } else if (rawValue is List) {
    // For raw Dart Lists (representing MessagePackArray)
    // Compare the underlying Dart values of the MessagePackArray elements
    if (mpValue is! MessagePackArray) return false;
    if (mpValue.elements.length != rawValue.length) return false;
    for (int i = 0; i < rawValue.length; i++) {
      if (!_compareMessagePackValues(mpValue.elements[i], rawValue[i])) {
        return false;
      }
    }
    return true;
  } else if (rawValue is Map) {
    // For raw Dart Maps (representing MessagePackMap)
    // Compare the underlying Dart values of the MessagePackMap entries
    if (mpValue is! MessagePackMap) return false;
    if (mpValue.map.length != rawValue.length) return false;
    for (final entry in rawValue.entries) {
      final rawKey = entry.key;
      final rawVal = entry.value;
      bool found = false;
      for (final mpEntry in mpValue.map.entries) {
        if (_compareMessagePackValues(mpEntry.key, rawKey) &&
            _compareMessagePackValues(mpEntry.value, rawVal)) {
          found = true;
          break;
        }
      }
      if (!found) return false;
    }
    return true;
  }
  // If rawValue is already a MessagePackValue subclass (like MessagePackBinary, MessagePackTimestamp, MessagePackExt)
  else if (rawValue is MessagePackValue) {
    return mpValue == rawValue;
  }
  return false;
}
