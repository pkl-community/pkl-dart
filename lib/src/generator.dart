import 'package:path/path.dart' as p;

import 'generator_settings.dart';

/// The generator that generates source code for Dart given Pkl source
class Generator {
  final bool verbose;

  final GeneratorSettings settings;

  final String workingDirectory;

  Generator({
    required this.settings,
    this.verbose = false,
    required this.workingDirectory,
  });

  Future runDry() async {
    //
  }

  /// Generates Dart Code for the given Pkl modules
  Future run() async {
    // get the evaluator manager

    // create an evaluator depending on the context

    // run the evaluator on the files
  }
}
