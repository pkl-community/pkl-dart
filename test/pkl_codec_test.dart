import 'dart:typed_data';
import 'package:pkl_dart/src/serializer/pkl_decoder.dart';
import 'package:test/test.dart';
import 'package:pkl_dart/src/message_pack/message_pack.dart';
import 'package:pkl_dart/src/serializer/pkl_encoder.dart';
import 'package:pkl_dart/src/serializer/pkl_data_model.dart';
import 'package:pkl_dart/src/pkl_type_codes.dart';

/// Copyright (c) 2025 Kirk Agbenyegah
///
/// This source code is licensed under the MIT license found in the
/// LICENSE file in the root directory of this source tree.

void main() {
  group('PklCodec (Encoder & Decoder)', () {
    final encoder = PklEncoder();
    final decoder = PklDecoder();

    // Helper to create expected raw MessagePack arrays for Pkl types
    // This is used to define the *expected* byte output from the PklEncoder,
    // which should conform to the Pkl MessagePack structure.
    Uint8List expectedPklArray(int typeCode, List<dynamic> values) {
      final mpCodec = MessagePackCodec(); // Use the underlying MessagePackCodec
      return mpCodec.encode([typeCode, ...values]);
    }

    // Helper to create expected raw MessagePack arrays for Pkl members
    Uint8List expectedPklMemberArray(int typeCode, List<dynamic> values) {
      final mpCodec = MessagePackCodec();
      return mpCodec.encode([typeCode, ...values]);
    }

    group('PklEncoder', () {
      // Test encoding of primitive types (should pass through to MessagePackCodec)
      test('should encode primitive types directly', () {
        expect(encoder.encode(null), equals(MessagePackCodec().encode(null)));
        expect(encoder.encode(true), equals(MessagePackCodec().encode(true)));
        expect(encoder.encode(123), equals(MessagePackCodec().encode(123)));
        expect(encoder.encode(3.14), equals(MessagePackCodec().encode(3.14)));
        expect(encoder.encode('hello'), equals(MessagePackCodec().encode('hello')));
        final bytes = Uint8List.fromList([1, 2, 3]);
        expect(encoder.encode(bytes), equals(MessagePackCodec().encode(bytes)));
      });

      test('should encode PklTyped', () {
        final typed = PklObject(
          fqcn: 'org.pkl.example.MyClass',
          moduleUri: 'file:///path/to/module.pkl',
          members: [
            PklProperty(key: 'prop1', value: 123),
            PklEntry(key: 'key', value: 'value'),
          ],
        );
        final expectedRawMp = expectedPklArray(PklTypeCodes.object, [
          'org.pkl.example.MyClass',
          'file:///path/to/module.pkl',
          [
            [PklTypeCodes.property, 'prop1', 123],
            [PklTypeCodes.entry, 'key', 'value'],
          ],
        ]);
        final encoded = encoder.encode(typed);
        expect(encoded, expectedRawMp);
      });

      test('should encode PklMap', () {
        final pklMap = PklMap({'a': 1, 'b': 'two'});
        final expectedRawMp = expectedPklArray(PklTypeCodes.map, [
          {'a': 1, 'b': 'two'},
        ]);
        expect(encoder.encode(pklMap), equals(expectedRawMp));
      });

      test('should encode PklMapping', () {
        final pklMapping = PklMapping({'x': 10, 'y': 20});
        final expectedRawMp = expectedPklArray(PklTypeCodes.mapping, [
          {'x': 10, 'y': 20},
        ]);
        expect(encoder.encode(pklMapping), equals(expectedRawMp));
      });

      test('should encode PklList', () {
        final pklList = PklList([1, 'two', true]);
        final expectedRawMp = expectedPklArray(PklTypeCodes.list, [
          [1, 'two', true],
        ]);
        expect(encoder.encode(pklList), equals(expectedRawMp));
      });

      test('should encode PklListing', () {
        final pklListing = PklListing([false, 3.14]);
        final expectedRawMp = expectedPklArray(PklTypeCodes.listing, [
          [false, 3.14],
        ]);
        expect(encoder.encode(pklListing), equals(expectedRawMp));
      });

      test('should encode PklSet', () {
        final pklSet = PklSet({1, 2, 3});
        final expectedRawMp = expectedPklArray(PklTypeCodes.set, [
          [1, 2, 3],
        ]);
        expect(encoder.encode(pklSet), equals(expectedRawMp));
      });

      test('should encode PklDuration', () {
        final duration = PklDuration.seconds(1.5);
        final expectedRawMp = expectedPklArray(PklTypeCodes.duration, [1.5, 's']);
        expect(encoder.encode(duration), equals(expectedRawMp));
      });

      test('should encode PklDataSize', () {
        final dataSize = DataSize.kilobytes(1024.0);
        final expectedRawMp = expectedPklArray(PklTypeCodes.dataSize, [1024.0, 'kb']);
        expect(encoder.encode(dataSize), equals(expectedRawMp));
      });

      test('should encode PklPair', () {
        final pair = PklPair(first: 'first', second: 123);
        final expectedRawMp = expectedPklArray(PklTypeCodes.pair, ['first', 123]);
        expect(encoder.encode(pair), equals(expectedRawMp));
      });

      test('should encode PklIntSeq', () {
        final intSeq = PklIntSeq(start: 1, end: 5, step: 1);
        final expectedRawMp = expectedPklArray(PklTypeCodes.intSeq, [1, 5, 1]);
        expect(encoder.encode(intSeq), equals(expectedRawMp));
      });

      test('should encode PklRegex', () {
        final regex = PklRegex(value: r'^[a-z]+$');
        final expectedRawMp = expectedPklArray(PklTypeCodes.regex, [r'^[a-z]+$']);
        expect(encoder.encode(regex), equals(expectedRawMp));
      });

      test('should encode PklClass', () {
        final pklClass = PklClass();
        final expectedRawMp = expectedPklArray(PklTypeCodes.classType, []);
        expect(encoder.encode(pklClass), equals(expectedRawMp));
      });

      test('should encode PklTypeAlias', () {
        final typeAlias = PklTypeAlias();
        final expectedRawMp = expectedPklArray(PklTypeCodes.typeAlias, []);
        expect(encoder.encode(typeAlias), equals(expectedRawMp));
      });

      test('should encode PklProperty', () {
        final property = PklProperty(key: 'myProp', value: 'someValue');
        final expectedRawMp = expectedPklMemberArray(PklTypeCodes.property, [
          'myProp',
          'someValue',
        ]);
        expect(encoder.encode(property), equals(expectedRawMp));
      });

      test('should encode PklEntry', () {
        final entry = PklEntry(key: 1, value: 'one');
        final expectedRawMp = expectedPklMemberArray(PklTypeCodes.entry, [1, 'one']);
        expect(encoder.encode(entry), equals(expectedRawMp));
      });

      test('should encode PklElement', () {
        final element = PklElement(index: 0, value: 'firstElement');
        final expectedRawMp = expectedPklMemberArray(PklTypeCodes.element, [0, 'firstElement']);
        expect(encoder.encode(element), equals(expectedRawMp));
      });

      test('should throw ArgumentError for unsupported types', () {
        expect(() => encoder.encode(DateTime.now()), throwsA(isA<ArgumentError>()));
        // Raw Map/List are not PklValue types and should throw
        expect(() => encoder.encode({'a': 1}), throwsA(isA<ArgumentError>()));
        expect(() => encoder.encode([1, 2]), throwsA(isA<ArgumentError>()));
      });
    });

    group('PklDecoder', () {
      // Test decoding of primitive types (should pass through from MessagePackCodec)
      test('should decode primitive types directly', () {
        expect(decoder.decodePkl(MessagePackCodec().encode(null)), isNull);
        expect(decoder.decodePkl(MessagePackCodec().encode(true)), isTrue);
        expect(decoder.decodePkl(MessagePackCodec().encode(123)), equals(123));
        expect(decoder.decodePkl(MessagePackCodec().encode(3.14)), equals(3.14));
        expect(decoder.decodePkl(MessagePackCodec().encode('hello')), equals('hello'));
        final bytes = Uint8List.fromList([1, 2, 3]);
        expect(decoder.decodePkl(MessagePackCodec().encode(bytes)), equals(bytes));
      });

      // Test decoding of PklValue types
      test('should decode PklTyped', () {
        final rawMp = expectedPklArray(PklTypeCodes.object, [
          'org.pkl.example.MyClass',
          'file:///path/to/module.pkl',
          [
            [PklTypeCodes.property, 'prop1', 123],
            [PklTypeCodes.entry, 'key', 'value'],
          ],
        ]);
        final decoded = decoder.decodePkl(rawMp);
        expect(decoded, isA<PklObject>());
        final typed = decoded as PklObject;
        expect(typed.fqcn, 'org.pkl.example.MyClass');
        expect(typed.moduleUri, 'file:///path/to/module.pkl');
        expect(typed.members, hasLength(2));
        expect(typed.members[0], equals(PklProperty(key: 'prop1', value: 123)));
        expect(typed.members[1], equals(PklEntry(key: 'key', value: 'value')));
      });

      test('should decode PklMap', () {
        final expectedMap = {'a': 1, 'b': 'two'};
        final rawMp = expectedPklArray(PklTypeCodes.map, [expectedMap]);
        final decoded = decoder.decode(rawMp);
        expect(decoded, isA<Map>());
        expect(decoded, equals(expectedMap));
        final pklDecoded = decoder.decodePkl(rawMp);
        expect(pklDecoded, PklMap(expectedMap));
      });

      test('should decode PklMapping', () {
        final expectedMap = {'x': 10, 'y': 20};
        final rawMp = expectedPklArray(PklTypeCodes.mapping, [expectedMap]);
        final decoded = decoder.decode(rawMp);
        expect(decoded, isA<Map>());
        expect(decoded, equals(expectedMap));
        final pklDecoded = decoder.decodePkl(rawMp);
        expect(pklDecoded, PklMapping(expectedMap));
      });

      test('should decode PklList', () {
        final expectedList = [1, 'two', true];
        final rawMp = expectedPklArray(PklTypeCodes.list, [expectedList]);
        final decoded = decoder.decode(rawMp);
        expect(decoded, isA<List>());
        expect(decoded, equals(expectedList));
        final pklDecoded = decoder.decodePkl(rawMp);
        expect(pklDecoded, PklList(expectedList));
      });

      test('should decode PklListing', () {
        const expectedList = [false, 3.14];
        final rawMp = expectedPklArray(PklTypeCodes.listing, [expectedList]);
        final decoded = decoder.decode(rawMp);
        expect(decoded, isA<List>());
        expect(decoded, equals(expectedList));
        final pklDecoded = decoder.decodePkl(rawMp);
        expect(pklDecoded, PklListing(expectedList));
      });

      test('should decode PklSet', () {
        const expectedSet = {1, 2, 3};
        final rawMp = expectedPklArray(PklTypeCodes.set, [List.from(expectedSet)]);
        final decoded = decoder.decode(rawMp);
        expect(decoded, isA<Set>());
        expect(decoded, equals(expectedSet));
      });

      test('should decode PklDuration', () {
        final rawMp = expectedPklArray(PklTypeCodes.duration, [1.5, 's']);
        final decoded = decoder.decodePkl(rawMp);
        expect(decoded, equals(PklDuration.seconds(1.5)));
      });

      test('should decode PklDataSize', () {
        final rawMp = expectedPklArray(PklTypeCodes.dataSize, [1024.0, 'kb']);
        final decoded = decoder.decodePkl(rawMp);
        expect(decoded, equals(DataSize.kilobytes(1024.0)));
      });

      test('should decode PklPair', () {
        final rawMp = expectedPklArray(PklTypeCodes.pair, ['first', 123]);
        final decoded = decoder.decodePkl(rawMp);
        expect(decoded, equals(PklPair(first: 'first', second: 123)));
      });

      test('should decode PklIntSeq', () {
        final rawMp = expectedPklArray(PklTypeCodes.intSeq, [1, 5, 1]);
        final decoded = decoder.decodePkl(rawMp);
        expect(decoded, equals(PklIntSeq(start: 1, end: 5, step: 1)));
      });

      test('should decode PklRegex', () {
        final rawMp = expectedPklArray(PklTypeCodes.regex, [r'^[a-z]+$']);
        final decoded = decoder.decodePkl(rawMp);
        expect(decoded, equals(PklRegex(value: r'^[a-z]+$')));
      });

      test('should decode PklClass', () {
        final rawMp = expectedPklArray(PklTypeCodes.classType, []);
        final decoded = decoder.decodePkl(rawMp);
        expect(decoded, equals(PklClass()));
      });

      test('should decode PklTypeAlias', () {
        final rawMp = expectedPklArray(PklTypeCodes.typeAlias, []);
        final decoded = decoder.decodePkl(rawMp);
        expect(decoded, equals(PklTypeAlias()));
      });

      // Test decoding of PklMember types (when they are top-level, though usually nested)
      test('should decode PklProperty (top-level)', () {
        final rawMp = expectedPklMemberArray(PklTypeCodes.property, ['myProp', 'someValue']);
        final decoded = decoder.decodePkl(rawMp);
        expect(decoded, equals(PklProperty(key: 'myProp', value: 'someValue')));
      });

      test('should decode PklEntry (top-level)', () {
        final rawMp = expectedPklMemberArray(PklTypeCodes.entry, [1, 'one']);
        final decoded = decoder.decodePkl(rawMp);
        expect(decoded, equals(PklEntry(key: 1, value: 'one')));
      });

      test('should decode PklElement (top-level)', () {
        final rawMp = expectedPklMemberArray(PklTypeCodes.element, [0, 'firstElement']);
        final decoded = decoder.decodePkl(rawMp);
        expect(decoded, equals(PklElement(index: 0, value: 'firstElement')));
      });

      test('should throw FormatException for empty Pkl array', () {
        final emptyArrayMp = MessagePackCodec().encode([]);
        expect(() => decoder.decodePkl(emptyArrayMp), throwsA(isA<FormatException>()));
      });

      test('should throw FormatException for unknown Pkl type code', () {
        final unknownCodeMp = MessagePackCodec().encode([999, 'data']); // 999 is an unknown code
        expect(() => decoder.decodePkl(unknownCodeMp), throwsA(isA<FormatException>()));
      });

      test('should throw FormatException for invalid Pkl array structure', () {
        final badTypedMp = expectedPklArray(PklTypeCodes.object, ['fqcn_only']);
        expect(() => decoder.decodePkl(badTypedMp), throwsA(isA<FormatException>()));
      });
    });

    group('Round-trip (Encode then Decode)', () {
      test('PklTyped round-trip', () {
        final original = PklObject(
          fqcn: 'org.pkl.example.MyClass',
          moduleUri: 'file:///path/to/module.pkl',
          members: [
            PklProperty(key: 'prop1', value: 123),
            PklEntry(key: 'key', value: 'value'),
            PklElement(index: 0, value: PklDuration.minutes(5.0)),
          ],
        );
        final encoded = encoder.encode(original);
        final decoded = decoder.decodePkl(encoded);
        expect(decoded, equals(original));
      });

      test('PklMap round-trip', () {
        final original = PklMap({
          'key1': 1,
          'key2': 'value',
          'key3': PklPair(first: true, second: false),
        });
        final encoded = encoder.encode(original);
        final decoded = decoder.decode(encoded);
        expect(decoded, isA<Map>());
        expect(
          decoded,
          equals({
            'key1': 1,
            'key2': 'value',
            'key3': [true, false],
          }),
        );
        expect(decoder.decodePkl(encoded), original);
      });

      test('PklList round-trip', () {
        final original = PklList([1, 'two', true, DataSize.megabytes(100)]);
        final encoded = encoder.encode(original);
        final decoded = decoder.decode(encoded);
        expect(decoded, isA<List>());
        expect(
          decoded,
          equals([
            1,
            'two',
            true,
            {"value": 100, "unit": 'mb'},
          ]),
        );
        expect(decoder.decodePkl(encoded), original);
      });

      test('PklSet round-trip', () {
        final original = PklSet({1, 2, 'three', PklRegex(value: r'.*')});
        final encoded = encoder.encode(original);
        final decoded = decoder.decode(encoded);
        expect(decoded, isA<Set>());
        expect(decoded, equals({1, 2, 'three', RegExp(r'.*')}));
        expect(decoder.decodePkl(encoded), original);
      });

      test('Nested Pkl values round-trip', () {
        final original = PklPair(
          first: PklDuration.seconds(10.0),
          second: PklObject(
            fqcn: 'NestedType',
            moduleUri: 'nested.pkl',
            members: [PklProperty(key: 'nestedProp', value: PklIntSeq(start: 1, end: 3, step: 1))],
          ),
        );
        final encoded = encoder.encode(original);
        final decoded = decoder.decode(encoded);
        final dartPair = [
          {"value": 10.0, "unit": "s"},
          {
            'nestedProp': [1, 2, 3],
          },
        ];
        expect(decoded, equals(dartPair));
        expect(decoder.decodePkl(encoded), equals(original));
      });
    });
  });
}
