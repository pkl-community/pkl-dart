import 'dart:typed_data';

import 'evaluator/reader.dart';
import 'utils/logger.dart';

class EvaluatorManager {}

/// The core API for evaluating Pkl modules
class Evaluator {
  final EvaluatorManager manager;
  final Iterable<ResourceReader> resourceReaders;
  final Iterable<ModuleReader> moduleReaders;
  final Map pendingRequests = {};
  final int evaluatorId;
  final Logger logger;

  bool _closed = false;

  Evaluator({
    required this.manager,
    required this.evaluatorId,
    this.resourceReaders = const [],
    this.moduleReaders = const [],
    required this.logger
  });

  /// Evaluates the provided module, and decodes the result as a Dart type
  Future<dynamic> evaluateModule(ModuleSource source) async {
    return await evaluateExpression(source, null);
  }

  /// Evaluates the `output.text` property of the given module
  Future<String> evaluateOutputText(ModuleSource source) async {
    return await evaluateExpression(source, 'output.text');
  }

  /// Evaluates the `output.value` property of the given module and decodes the result as a Dart type
  Future<dynamic> evaluateOutputValue(ModuleSource source) async {
    return await evaluateExpression(source, 'output.value');
  }

  /// Evaluates the `output.files` property of the given module.
  Future<Map<String, String>> evaluateOutputFiles(ModuleSource source) async {
    return await evaluateExpression(source, "output.files.toMap().mapValues((_, it) -> it.text)");
  }

  /// Evaluates the provided [expression] within the given module [source] and decodes the result as a Dart type
  Future<dynamic> evaluateExpression(ModuleSource source, String? expression) async {
    final bytes = await evaluateExpressionRaw(source, expression);

  }

  /// Evaluates the provided [expression] within the given module [source] and returns the underlying response in binary form
  Future<Uint8List> evaluateExpressionRaw(ModuleSource source, String? expression) async {
    throw UnimplementedError("TODO: Implement evaluateExpressionRaw");
  }

  /// Closes this evaluator, cleaning up any resources
  Future<void> close() async {
    _closed = true;
  }
}

class ModuleSource {
  final Uri uri;

  final String? text;

  const ModuleSource({
    required this.uri,
    this.text
  });
}