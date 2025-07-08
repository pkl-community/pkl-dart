// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as path;

/// A representation of a source for a Pkl module to be evaluated.
class ModuleSource extends Equatable {
  /// The URI of the module.
  final Uri uri;

  /// The text contents of the module, if available.
  ///
  /// If `null`, gets resolved by Pkl during evaluation time.
  /// If the scheme of the uri matches a [ModuleReader], it will be used to resolve the module.
  final String? text;

  const ModuleSource._({required this.uri, this.text});

  /// Creates a [ModuleSource] from the given file path component.
  ///
  /// Relative paths are resolved against the current working directory.
  factory ModuleSource.path(String filePath) {
    final resolvedPath = path.isAbsolute(filePath)
        ? filePath
        : path.join(Directory.current.path, filePath);
    return ModuleSource._(uri: Uri.file(resolvedPath));
  }

  /// Creates a synthetic [ModuleSource] with the given text.
  /// The module is assigned `"repl:text"` as its URI.
  factory ModuleSource.text(String text) {
    return ModuleSource._(uri: Uri.parse('repl:text'), text: text);
  }

  /// Creates a [ModuleSource] with the given URL.
  factory ModuleSource.uri(Uri url) {
    return ModuleSource._(uri: url);
  }

  /// Creates a [ModuleSource] with the given URI string.
  ///
  /// Throws [FormatException] if the URI string is malformed.
  factory ModuleSource.uriString(String uriString) {
    return ModuleSource._(uri: Uri.parse(uriString));
  }

  /// Creates a [ModuleSource] with the given URI string, or returns `null` if malformed.
  static ModuleSource? tryUri(String uriString) {
    try {
      return ModuleSource.uriString(uriString);
    } on FormatException {
      return null;
    }
  }

  @override
  List<Object?> get props => [uri, text];

  @override
  bool get stringify => true;
}
