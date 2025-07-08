// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'message.dart';

/// Base interface for all readers in Pkl.
sealed class BaseReader {
  /// The scheme part of the URL that this reader can read.
  String get scheme;

  /// Tells if this reader supports Pkl's `import*` and `glob*` keywords.
  bool get isGlobbable;

  /// Tells if the URIs handled by this reader are hierarchical.
  /// Hierarchical URIs are URIs that have hierarchy elements like host, origin, query, and
  /// fragment.
  ///
  /// A hierarchical URI must start with a "/" in its scheme specific part. For example, consider
  /// the following two URIS:
  ///
  /// ```
  /// birds:/catalog/swallow.pkl
  /// birds:catalog/swallow.pkl
  /// ```
  ///
  /// The first URI conveys name "swallow.pkl" within parent "/catalog/". The second URI
  /// conveys the name "catalog/swallow.pkl" with no hierarchical meaning.
  bool get hasHierarchicalUris;

  /// Returns elements at a specified path.
  /// If [BaseReader.hasHierarchicalUris] is `false`, the uri parameter will be a dummy value,
  /// and this method should return all possible values.
  Future<List<PathElement>> listElements({required Uri uri});
}

/// A custom module reader for Pkl.
///
/// A [ModuleReader] registers the scheme that it is responsible for reading via the `scheme` property.
/// For example, a module reader can declare that it reads a resource at `myscheme:/myFile.pkl` by setting its `scheme`
/// to `"myscheme"`.
///
/// Modules are cached by Pkl for the lifetime of an [Evaluator]. Therefore, caching is not needed
/// on the Pkl side as long as the same Evaluator is used.
///
/// Modules are read in Pkl via the import declaration:
///
/// ```
///	import "myscheme:/myFile.pkl"
///	import* "myscheme:/*.pkl" // only when the reader is globbable
/// ```
///
/// Or via the import expression:
///
/// ```
///	import("myscheme:/myFile.pkl")
///	import*("myscheme:/myFile.pkl") // only when the reader is globbable
/// ```
///
/// To provide a custom reader, register it with [EvaluatorOptions.withModuleReader]
abstract class ModuleReader extends BaseReader {
  /// Tells if the resources handled by this reader are local to the file system.
  ///
  /// A local resource means that triple-dot import syntax will be resolved.
  /// It is expected that I/O operations for this resource to be fast.
  bool get isLocal;

  /// Read the module at the provided URL, and return its contents as a string.
  Future<String> read({required Uri url});

  /// Converts this module reader to a message format for communication.
  ModuleReaderMessage toMessage([int id = 0]) {
    return ModuleReaderMessage(
      id: id,
      scheme: scheme,
      hasHierarchicalUris: hasHierarchicalUris,
      isLocal: isLocal,
      isGlobbable: isGlobbable,
    );
  }
}

/// A custom resource reader for Pkl.
abstract class ResourceReader extends BaseReader {
  /// Reads resources from the provided URL into a byte array.
  Future<Uint8List> read({required Uri url});

  /// Converts this resource reader to a message format for communication.
  ResourceReaderMessage toMessage([int id = 0]) {
    return ResourceReaderMessage(
      id: id,
      scheme: scheme,
      hasHierarchicalUris: hasHierarchicalUris,
      isGlobbable: isGlobbable,
    );
  }
}

/// An element within a base URI.
///
/// For example, a [PathElement] with name `bar.txt` and is not a directory at base URI `file:////foo/`
/// implies URI resource `file:///foo/bar.txt`.
class PathElement extends Equatable {
  /// The name of the path element
  final String name;

  /// Whether the element is a directory or not.
  final bool isDirectory;

  const PathElement({required this.name, required this.isDirectory});

  /// Converts this path element to a message format for communication.
  PathElementMessage toMessage() {
    return PathElementMessage(name: name, isDirectory: isDirectory);
  }

  @override
  List<Object?> get props => [name, isDirectory];
}
