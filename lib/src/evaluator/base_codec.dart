import 'dart:typed_data';


abstract class PklPrimitiveCodec<T> {
  Uint8List encode(T value);
  T decode(Uint8List bytes);
}
