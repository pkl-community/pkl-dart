import '../pkl_data_model.dart';
import '../pkl_decodable.dart';

/// Copyright (c) 2025 Kirk Agbenyegah
///
/// This source code is licensed under the MIT license found in the
/// LICENSE file in the root directory of this source tree.

/// A helper class to safely decode a Pkl object (represented as a Map)
/// into a strongly-typed Dart class.
///
/// This class provides methods to access and cast properties from the map,
/// throwing helpful, context-aware errors if a key is missing or a type
/// cast fails. It automatically converts Pkl-specific types (like `PklDuration`)
/// into their standard Dart equivalents (`Duration`).
class PklObjectDecoder {
  final Map<String, dynamic> _map;
  final List<String> _codingPath;

  /// Creates a decoder for the given [map].
  ///
  /// The optional [codingPath] is used internally for tracking the location
  /// of nested decoding errors.
  PklObjectDecoder(this._map, {List<String> codingPath = const []}) : _codingPath = codingPath;

  /// Decodes a value for the given [key] and casts it to type [T].
  ///
  /// If the raw value is a Pkl-specific type (like `PklDuration`), it will be
  /// converted to its standard Dart equivalent (`Duration`) before being cast.
  ///
  /// Throws [PklDecodingException] if the key is not found or if the value
  /// cannot be cast to [T].
  T decode<T>(String key) {
    final rawValue = _getValue(key);
    final value = _convert(rawValue);
    if (value is T) {
      return value;
    }
    throw PklDecodingException(
      'Expected value of type "$T" for key "$key", but got type "${value.runtimeType}".',
      path: _pathWith(key),
    );
  }

  /// Decodes a list of values for the given [key].
  ///
  /// Each element in the list is cast to type [T]. Pkl-specific types within
  /// the list are converted to their Dart equivalents.
  ///
  /// Throws [PklDecodingException] if the key is not found, the value is not a
  /// list, or if any element cannot be cast to [T].
  List<T> decodeList<T>(String key) {
    final rawValue = _getValue(key);
    final value = _convert(rawValue);
    if (value is List) {
      try {
        // The items inside are already converted by the recursive _convert call.
        // We just need to cast the list itself.
        return value.cast<T>();
      } catch (e) {
        throw PklDecodingException(
          'Failed to cast elements of list for key "$key" to type "$T".',
          path: _pathWith(key),
        );
      }
    }
    throw PklDecodingException(
      'Expected a List for key "$key", but got type "${value.runtimeType}".',
      path: _pathWith(key),
    );
  }

  /// Decodes a nested object for the given [key] using the provided [factory].
  ///
  /// Throws [PklDecodingException] if the key is not found, the value is not
  /// a map, or if the factory fails during decoding.
  T decodeObject<T>(String key, PklFactory<T> factory) {
    final rawValue = _getValue(key);
    final value = _convert(rawValue);
    if (value is Map) {
      // Check if it's a Map of any kind first.
      try {
        // Attempt to cast to the specific map type required by the factory.
        final mapForFactory = value.cast<String, dynamic>();
        return factory(mapForFactory);
      } on PklDecodingException {
        // If the factory itself throws a PklDecodingException, rethrow it
        // to preserve its more specific context.
        rethrow;
      } on TypeError {
        throw PklDecodingException(
          'Failed to decode nested object for key "$key". The object\'s keys were not all Strings.',
          path: _pathWith(key),
        );
      } catch (e, s) {
        throw PklDecodingException(
          'Failed to decode nested object for key "$key". Error in factory: $e\n$s',
          path: _pathWith(key),
        );
      }
    }
    throw PklDecodingException(
      'Expected a Map for key "$key" to decode a nested object, but got type "${value.runtimeType}".',
      path: _pathWith(key),
    );
  }

  dynamic _getValue(String key) {
    if (_map.containsKey(key)) {
      return _map[key];
    }
    throw PklDecodingException('Key "$key" not found.', path: _pathWith(key));
  }

  List<String> _pathWith(String key) => [..._codingPath, key];

  /// Recursively converts a value, transforming any Pkl-specific types into
  /// standard Dart types.
  dynamic _convert(dynamic value) {
    if (value is PklValue) {
      return _convertPklValue(value);
    }

    if (value is List) {
      return value.map(_convert).toList();
    }

    if (value is Map) {
      return value.map((k, v) => MapEntry(_convert(k), _convert(v)));
    }

    // It's already a primitive or standard Dart type.
    return value;
  }

  dynamic _convertPklValue(PklValue pklValue) {
    switch (pklValue) {
      case PklObject():
        final Map<String, dynamic> result = {};
        for (final member in pklValue.members) {
          if (member is PklProperty) {
            result[member.key] = _convert(member.value);
          } else if (member is PklEntry) {
            result[_convert(member.key).toString()] = _convert(member.value);
          }
        }
        return result;

      case PklMap() || PklMapping():
        final pklMap = (pklValue as dynamic).data as Map;
        return pklMap.map((k, v) => MapEntry(_convert(k), _convert(v)));

      case PklList() || PklListing():
        final pklList = (pklValue as dynamic).elements as List;
        return pklList.map(_convert).toList();

      case PklSet():
        return pklValue.elements.map(_convert).toSet();

      case PklPair():
        return [_convert(pklValue.first), _convert(pklValue.second)];

      case PklIntSeq():
        final List<int> seq = [];
        for (var i = pklValue.start; i <= pklValue.end; i += pklValue.step) {
          seq.add(i);
        }
        return seq;

      case PklDuration():
        return pklValue.toDartDuration();

      case DataSize():
        return {'value': pklValue.value, 'unit': pklValue.unit.name};

      case PklRegex():
        return RegExp(pklValue.value);

      case PklClass():
        return {'pklType': 'pkl.Class'};

      case PklTypeAlias():
        return {'pklType': 'pkl.TypeAlias'};
    }
  }
}

/// An exception thrown when decoding a Pkl object into a Dart class fails.
class PklDecodingException implements Exception {
  final String message;
  final List<String> path;

  PklDecodingException(this.message, {required this.path});

  @override
  String toString() {
    final pathString = path.join('.');
    return 'PklDecodingException at path "$pathString": $message';
  }
}
