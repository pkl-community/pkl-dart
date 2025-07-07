import 'dart:async';
import 'dart:typed_data';

/// The base implementation of a reader
abstract class Reader {
  /// The scheme part of the URL that this reader can read
  String get scheme;

  /// Whether the reader supports globbing via Pkl's `import*` and `glob*` keywords
  bool get isGlobbable;

  /// Whether the URIs handled by the reader are hierarchial 
  /// A hierarchial URI is a URI that has hierarchy elements like host, origin, query, and fragment
  /// 
  /// A hierarchical URI must start with a "/" in its scheme specific part.
  bool get hasHierarchicalUris;

  /// Returns elements at a specified path
  /// If [hasHierarchicalUris] is `false`, the uri parameter will be a dummy value
  FutureOr<List<PathElement>> listElements(Uri url);
}

/// A custom module reader for Pkl.
///
/// A [ModuleReader] registers the scheme that it is responsible for reading via the `scheme` property.
/// For example, a module reader can declare that it reads a resource at `myscheme:/myFile.pkl` by setting its `scheme`
/// to `"myscheme"`.
///
/// Modules are cached by Pkl for the lifetime of an ``Evaluator``. Therefore, cacheing is not needed
/// on the Pkl side as long as the same Evaluator is used.
///
/// Modules are read in Pkl via the import declaration:
///
/// ```pkl
///	import "myscheme:/myFile.pkl"
///	import* "myscheme:/*.pkl" // only when the reader is globbable
/// ```
///
/// Or via the import expression:
///
/// ```pkl
///	import("myscheme:/myFile.pkl")
///	import*("myscheme:/myFile.pkl") // only when the reader is globbable
/// ```
///
/// To provide a custom reader, register it with [EvaluatorOptions.withModuleReader]
abstract class ModuleReader extends Reader {
  /// Tells if the resources handled by this reader are local to the file system.
  ///
  /// A local resource means that triple-dot import syntax will be resolved.
  /// It is expected that I/O operations for this resource to be fast.
  bool get isLocal;

  /// Read the module at the provided URL, and return its contents as a string.
  FutureOr<String> read(Uri url);
}

/// ResourceReader is a custom resource reader for Pkl.
///
/// A ResourceReader registers the scheme that it is responsible for reading via Reader.Scheme. For
/// example, a resource reader can declare that it reads a resource at secrets:MY_SECRET by returning
/// "secrets" when Reader.Scheme is called.
///
/// Resources are cached by Pkl for the lifetime of an Evaluator.
///
/// Resources are read via the following Pkl expressions:
/// 
/// ```pkl
/// read("myscheme:myresourcee")
///	read?("myscheme:myresource")
///	read*("myscheme:pattern*") // only if the resource is globabble
/// ```
/// 
/// To provide a custom reader, register it on [EvaluatorOptions.ResourceReaders] when building
/// an Evaluator.
abstract class ResourceReader extends Reader {
  FutureOr<Uint8List> read(Uri url);
}

/// An element within a base URI.
///
/// For example, a [PathElement] with name `bar.txt` and is not a directory at base URI `file:////foo/`
/// implies URI resource `file:///foo/bar.txt`.
typedef PathElement = ({String name, bool isDirectory});