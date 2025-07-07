import 'dart:typed_data';


abstract interface class PklDecodable<T> {
  T decodeBytes(Uint8List bytes);
}

