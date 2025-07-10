// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../message.dart';
import '../serializer/pkl_decodable.dart';
import '../serializer/pkl_decoder.dart';
import 'evaluator_manager.dart';
import 'evaluator_options.dart';
import 'manager_messages.dart';
import 'module_source.dart';
import 'pkl_error.dart';

/// A type alias for an action to be performed with a temporary evaluator.
typedef EvaluationAction<T> = Future<T> Function(Evaluator);

/// Helper that performs an [action] with a manager and ensures
/// the manager is closed afterward.
Future<T> _withEvaluatorManager<T>(
  Future<T> Function(EvaluatorManager) action,
) async {
  final manager = await EvaluatorManager.spawn();
  try {
    return await action(manager);
  } finally {
    await manager.close();
  }
}

/// The core API for evaluating Pkl modules.
///
/// Use the static `run` methods for one-off evaluations with automatic resource
/// management. For managing multiple, long-lived evaluators, use an
/// [EvaluatorManager] instance directly.
class Evaluator {
  final int _evaluatorId;
  final SendPort _managerSendPort;
  final Map<int, Completer<dynamic>> _commandCompleters;

  // A closure provided by the manager to generate unique command IDs safely.
  final int Function() _generateCommandId;

  /// Internal constructor. Use `Evaluator.run` or `EvaluatorManager.newEvaluator`.
  @internal
  Evaluator({
    required int evaluatorId,
    required SendPort managerSendPort,
    required Map<int, Completer<dynamic>> commandCompleters,
    required int Function() generateCommandId,
  }) : _evaluatorId = evaluatorId,
       _managerSendPort = managerSendPort,
       _commandCompleters = commandCompleters,
       _generateCommandId = generateCommandId;

  /// Runs an action with a new evaluator.
  ///
  /// If [options] is not provided, preconfigured default options are used.
  /// The evaluator and its underlying process are automatically closed after
  /// the [action] completes.
  ///
  /// ## Example
  /// ```dart
  ///   await Evaluator.run((evaluator) async {
  ///     final module = ModuleSource.text('''
  ///       name = "Pkl-Dart"
  ///       version = 1
  ///       features = List("Evaluation", "Deserialization")
  ///     ''');
  ///
  ///     // Evaluate the entire module into a Map
  ///     final config = await evaluator.evaluateModule(module) as Map<String, dynamic>;
  ///     print(config['name']); // Pkl-Dart
  ///
  ///     // Evaluate a single expression
  ///     final features = await evaluator.evaluateExpression(
  ///       source: module,
  ///       expression: 'features',
  ///     ) as List;
  ///     print(features.first); // Evaluation
  ///   });
  /// ```
  ///
  static Future<T> run<T>(
    EvaluationAction<T> action, {
    EvaluatorOptions? options,
  }) async {
    final resolvedOptions = options ?? await EvaluatorOptions.preconfigured;
    return await _withEvaluatorManager((manager) async {
      final evaluator = await manager.newEvaluator(options: resolvedOptions);
      return await action(evaluator);
    });
  }

  /// Runs an action with a new evaluator configured from a Pkl project.
  ///
  /// If [options] is not provided, preconfigured default options are used.
  /// The evaluator and its underlying process are automatically closed after
  /// the [action] completes.
  ///
  /// The provided [uri] should be the base uri of the project.
  static Future<T> runWithProject<T>(
    EvaluationAction<T> action, {
    required Uri uri,
    EvaluatorOptions? options,
  }) async {
    final resolvedOptions = options ?? await EvaluatorOptions.preconfigured;
    return await _withEvaluatorManager((manager) async {
      final evaluator = await manager.newProjectEvaluator(
        uri: uri,
        options: resolvedOptions,
      );
      return await action(evaluator);
    });
  }

  // Helper to send commands to the manager's isolate and await response
  Future<dynamic> _sendCommand(IsolateCommand command) async {
    final completer = Completer<dynamic>();
    _commandCompleters[command.commandId] = completer;
    _managerSendPort.send(command);
    final result = await completer.future;
    if (result is String && result.startsWith('Error:')) {
      throw PklError(result.substring(6).trim());
    }
    return result;
  }

  /// Evaluates the provided module, and decodes the result.
  Future<dynamic> evaluateModule(ModuleSource source) async {
    return await evaluateExpression(source: source, expression: null);
  }

  /// Evaluates the provided module and decodes the result into a strongly-typed
  /// Dart object of type [T].
  Future<T> evaluateModuleAs<T extends PklDecodable>({
    required ModuleSource source,
    required PklFactory<T> fromPkl,
    String? expression,
  }) async {
    return evaluateExpressionAs<T>(
      source: source,
      fromPkl: fromPkl,
      expression: expression,
    );
  }

  /// Evaluates the provided [expression] within [source] and decodes the result
  /// into a strongly-typed Dart object of type [T].
  Future<T> evaluateExpressionAs<T extends PklDecodable>({
    required ModuleSource source,
    required PklFactory<T> fromPkl,
    String? expression,
  }) async {
    final dynamic result = await evaluateExpression(
      source: source,
      expression: expression,
    );

    if (result is! Map<String, dynamic>) {
      throw PklError(
        'The evaluated expression did not result in a Pkl object (Map). '
        'Instead, got type: ${result.runtimeType}.',
      );
    }

    try {
      return fromPkl(result);
    } catch (e, s) {
      throw PklError(
        'Failed to convert Pkl object to type $T. Error during factory execution: $e\n$s',
      );
    }
  }

  /// Evaluates the provided module's `output.text` property.
  Future<String> evaluateOutputText(ModuleSource source) async {
    final result = await evaluateExpression(
      source: source,
      expression: 'output.text',
    );
    return result as String;
  }

  /// Evaluates the provided module's `output.value` property.
  Future<dynamic> evaluateOutputValue(ModuleSource source) async {
    return await evaluateExpression(source: source, expression: 'output.value');
  }

  /// Evaluates the `output.files` property of the given module.
  Future<Map<String, String>> evaluateOutputFiles(ModuleSource source) async {
    final result =
        await evaluateExpression(
              source: source,
              expression: 'output.files.toMap().mapValues((_, it) -> it.text)',
            )
            as Map;
    return result.cast<String, String>();
  }

  /// Evaluates the provided [expression] within [source].
  Future<dynamic> evaluateExpression({
    required ModuleSource source,
    String? expression,
  }) async {
    final bytes = await evaluateExpressionRaw(
      source: source,
      expression: expression,
    );
    return PklDecoder().decode(bytes);
  }

  /// Evaluates the provided [expression] within the [source], and returns the
  /// underlying response in binary form.
  Future<Uint8List> evaluateExpressionRaw({
    required ModuleSource source,
    String? expression,
  }) async {
    final request = EvaluateRequest(
      requestId: 0,
      evaluatorId: _evaluatorId,
      moduleUri: source.uri,
      moduleText: source.text,
      expr: expression,
    );

    final response = await _sendCommand(
      AskCommand(_generateCommandId(), request),
    );

    if (response is! EvaluateResponse) {
      throw PklBugError.invalidMessageCode(
        'Expected EvaluateResponse, but got ${response.runtimeType}',
      );
    }

    if (response.error != null) {
      throw PklError(response.error!);
    }

    // We can be sure that if error is null, result is set.
    return response.result!;
  }

  /// Closes this evaluator, cleaning up any resources held by the evaluator.
  Future<void> close() async {
    await _sendCommand(
      CloseEvaluatorCommand(_generateCommandId(), _evaluatorId),
    );
  }
}
