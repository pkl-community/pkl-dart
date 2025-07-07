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
  /// If [hasHierarchicalUris] is `false`
  List<PathElement> listElements(Uri url);
}

abstract class ModuleReader extends Reader {

}

abstract class ResourceReader extends Reader {

}

typedef PathElement = ({String name, bool isDirectory});