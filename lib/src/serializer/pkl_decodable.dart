// ignore_for_file: dangling_library_doc_comments
/// Copyright (c) 2025 Kirk Agbenyegah
///
/// This source code is licensed under the MIT license found in the
/// LICENSE file in the root directory of this source tree.

/// A type definition for a factory function that creates an object of type [T]
/// from a decoded Pkl object map.
///
/// Any class that you wish to decode a Pkl object into should have a
/// factory constructor or static method that matches this signature.
typedef PklFactory<T> = T Function(Map<String, dynamic> map);

/// A contract for classes that can be decoded from a Pkl object.
///
/// This serves as a marker and a central point for documentation on how to make your Dart classes
/// compatible with Pkl's decoding mechanism.
///
/// To make a class decodable, you must provide a factory that matches the
/// [PklFactory] signature. It is highly recommended to use the [PklObjectDecoder]
/// helper class within your factory to safely access and cast properties.
///
/// ### Example
/// ```dart
/// class MyObject implements PklDecodable {
///   final String name;
///   final int age;
///
///   MyObject({required this.name, required this.age});
///
///   factory MyObject.fromPkl(Map<String, dynamic> map) {
///     return MyObject(
///       name: map['name'] as String,
///       age: map['age'] as int,
///     );
///   }
/// }
///
///
///
abstract class PklDecodable {}
