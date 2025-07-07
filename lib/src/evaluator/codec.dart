

import 'dart:convert';
import 'dart:typed_data';

import '../msgpack/msgpack.dart';

class PklCodec extends Codec<Object?, Uint8List> {
  final Object? Function(Object?)? _toDecoded; 
  final Object? Function(Object?)? _toEncoded; 

  const PklCodec({
    Object? Function(Object?)? toDecoded,
    Object? Function(Object?)? toEncoded
  }) : _toDecoded = toDecoded, _toEncoded = toEncoded;

  @override
  Object? decode(Uint8List encoded, {
    Object? Function(Object?)? toDecoded
  }) {
    // TODO: implement decode
    return super.decode(encoded);
  }

  @override
  Uint8List encode(Object? input, {
    Object? Function(Object?)? toEncoded
  }) {
    // TODO: implement encode
    return super.encode(input);
  }
  
  @override
  Converter<Object?, Uint8List> get encoder {
    if (_toDecoded == null) return const PklEncoder();
    return PklEncoder(_toEncoded);
  }
  
  @override
  Converter<Uint8List, Object?> get decoder {
    if (_toEncoded == null) return const PklDecoder();
    return PklDecoder(_toDecoded);
  }
}

class PklEncoder extends Converter<Object?, Uint8List> {
  final Object? Function(Object?)? _toEncoded; 
  final MessagePackSerializer deserializer = const MessagePackSerializer();

  const PklEncoder([Object? Function(Object?)? toEncoded]) : _toEncoded = toEncoded;

  @override
  Uint8List convert(dynamic input) {
    
  }
}

class PklDecoder extends Converter<Uint8List, Object?> {
  final Object? Function(Object?)? _toDecoded; 
  final MessagePackDeserializer deserializer = const MessagePackDeserializer();

  const PklDecoder([Object? Function(Object?)? toDecoded]) : _toDecoded = toDecoded;

  @override
  Object? convert(Uint8List input) {

  }
}