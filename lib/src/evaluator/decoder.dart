import 'dart:typed_data';

/// A utility class for decoding a given type from
class PklDecoder {

}

abstract interface class PklDecodable<T> {
  T decodeBytes(Uint8List bytes);
}