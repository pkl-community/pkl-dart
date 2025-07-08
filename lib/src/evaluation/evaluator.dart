// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../message.dart';
import '../serializer/pkl_decodable.dart';
import '../serializer/pkl_decoder.dart';
import 'evaluator_manager.dart';
import 'module_source.dart';
import 'pkl_error.dart';
import 'evaluator_options.dart';

import 'manager_messages.dart';

typedef EvaluationAction<T> = Future<T> Function(Evaluator);

/// A convenience method for running an action given an evaluator with the supplied evaluator options.
/// After [action] completes, the evaluator is closed.
///
///   - [options]: The options used to configure the evaluator.
///   - [action]: The action to perform.
Future<T> withEvaluator<T>(EvaluatorOptions options, EvaluationAction action) async {
  return await withEvaluatorManager((manager) async {
    final evaluator = await manager.newEvaluator(options: options);
    return await action(evaluator);
  });
}

/// Like [withEvaluator] with options, but with preconfigured evaluator options.
///
/// - [action]: The action to perform
Future<T> withEvaluatorPreconfigured<T>(EvaluationAction action) async {
  return await withEvaluator(await EvaluatorOptions.preconfigured, action);
}

/// Like [withProjectEvaluator] with options, but configured with preconfigured options.
///
///   - [projectBaseUri]: The base path containing the PklProject file.
///   - [action]: The action to perform.
/// - Returns: The result of the action.
Future<T> withProjectEvaluatorPreconfigured<T>(Uri projectBaseUri, EvaluationAction action) async {
  return await withProjectEvaluator(projectBaseUri, await EvaluatorOptions.preconfigured, action);
}

/// Convenience method for initializing an evaluator from the project.
///
/// [options] is the base set of evaluator options.
/// Any `evaluatorSettings` set within the PklProject file overwrites any fields set on [options].
///
/// After [action] completes, the evaluator is closed.
/// - Parameters:
///   - [projectBaseUri]: The base path containing the PklProject file.
///   - [options]: The base options used to configure the evaluator.
///   - [action]: The action to perform.
/// - Returns: The result of the action.
Future<dynamic> withProjectEvaluator<T>(
  Uri projectBaseUri,
  EvaluatorOptions options,
  EvaluationAction action,
) async {
  return await withEvaluatorManager((manager) async {
    final evaluator = await manager.newProjectEvaluator(
      projectBaseUri: projectBaseUri,
      options: options,
    );
    final result = await action(evaluator);
    await evaluator.close();
    return result;
  });
}

/// The core API for evaluating Pkl modules.
class Evaluator {
  final int _evaluatorId;
  final SendPort _managerSendPort; // To send commands to the background Isolate
  final Map<int, Completer<dynamic>> _commandCompleters; // To await responses from manager

  // Constructor only to be called by EvaluatorManager
  Evaluator.create({
    required int evaluatorId,
    required SendPort managerSendPort,
    required Map<int, Completer<dynamic>> commandCompleters,
  }) : _evaluatorId = evaluatorId,
       _managerSendPort = managerSendPort,
       _commandCompleters = commandCompleters;

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

  // Get the next Id to use
  int _nextId() {
    return _commandCompleters.length;
  }

  /// Evaluates the provided module, and decodes the result.
  ///
  ///   - [source]: The module to be evaluated.
  /// - Returns: The evaluated expression value.
  /// - Throws: [PklError] if an error occurs during evaluation, or if the result could not be decoded.
  Future<dynamic> evaluateModule(ModuleSource source) async {
    return await evaluateExpression(source: source, expression: null);
  }

  /// Evaluates the provided module and decodes the result into a strongly-typed Dart object of type [T].
  ///
  /// - Parameters:
  ///   - [source]: The module to be evaluated.
  ///   - [fromPkl]: A factory function that can create an instance of [T] from a `Map<String, dynamic>`.
  ///   - [expression]: The expression to be evaluated. If `null`, the entire module is evaluated.
  /// - Returns: An instance of type [T].
  /// - Throws: [PklError] if evaluation fails, or if the result cannot be converted to type [T].
  Future<T> evaluateModuleAs<T extends PklDecodable>({
    required ModuleSource source,
    required PklFactory<T> fromPkl,
    String? expression,
  }) async {
    return evaluateExpressionAs<T>(source: source, fromPkl: fromPkl, expression: expression);
  }

  /// Evaluates the provided [expression] within [source] and decodes the result into a strongly-typed Dart object of type [T].
  ///
  /// - Parameters:
  ///   - [source]: The module to be evaluated.
  ///   - [fromPkl]: A factory function that can create an instance of [T] from a `Map<String, dynamic>`.
  ///   - [expression]: The expression to be evaluated. If `null`, the entire module is evaluated.
  /// - Returns: An instance of type [T].
  /// - Throws: [PklError] if evaluation fails, or if the result cannot be converted to type [T].
  Future<T> evaluateExpressionAs<T extends PklDecodable>({
    required ModuleSource source,
    required PklFactory<T> fromPkl,
    String? expression,
  }) async {
    final dynamic result = await evaluateExpression(source: source, expression: expression);

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

  /// Evaluates the provided module's `output.text` property, and returns the result as a string.
  ///
  ///   - [source]: The module source to be evaluated.
  /// - Returns: A string representing the rendered contents of the module.
  /// - Throws: [PklError] if an error occurs during evaluation.
  Future<String> evaluateOutputText(ModuleSource source) async {
    return await evaluateExpression(source: source, expression: 'output.text');
  }

  /// Evaluates the provided module's `output.value` property, and decodes the result.
  ///
  /// - Parameters:
  ///   - source: The module to be evaluated.
  /// - Returns: The evaluated result.
  /// - Throws: [PklError] if an error occurs during evaluation, or if the result could not be decoded into [T].
  Future<dynamic> evaluateOutputValue(ModuleSource source) async {
    return await evaluateExpression(source: source, expression: 'output.value');
  }

  /// Evaluates the `output.files` property of the given module.
  ///
  /// - Parameter source: The module to be evaluated.
  /// - Returns: A map whose keys are the filenames, and values are the file contents.
  /// - Throws: [PklError] if an error occurs during evaluation.
  Future<Map<String, String>> evaluateOutputFiles(ModuleSource source) async {
    final result =
        await evaluateExpression(
              source: source,
              expression: 'output.files.toMap().mapValues((_, it) -> it.text)',
            )
            as Map<dynamic, dynamic>;

    return result.cast();
  }

  /// Evaluates the provided [expression] within [source], and decodes the result as type [T].
  ///
  /// - Parameters:
  ///   - [source]: The module to be evaluated.
  ///   - [expression]: The expression to be evaluated within the module. If `null`, evaluates the whole module.
  /// - Returns: A value of type.
  /// - Throws: [PklError] if an error occurs during evaluation, or if the result could not be decoded into [T].
  Future<dynamic> evaluateExpression({required ModuleSource source, String? expression}) async {
    final bytes = await evaluateExpressionRaw(source: source, expression: expression);
    return PklDecoder().decode(bytes);
  }

  /// Evaluates the provided [expression] within the [source], and returns the underlying response in binary form.
  ///
  /// - Parameters:
  ///   - source: The module to be evaluated
  ///   - expression: The expression to be evaluated within the module. If `null`, evaluates the whole module.
  /// - Returns: The evaluated result, in binary form.
  /// - Throws: [PklError], if an error occurred during evaluation
  Future<Uint8List> evaluateExpressionRaw({
    required ModuleSource source,
    String? expression,
  }) async {
    final request = EvaluateRequest(
      requestId: 0,
      // filled in by EvaluatorManager later
      evaluatorId: _evaluatorId,
      moduleUri: source.uri,
      moduleText: source.text,
      expr: expression,
    );

    final response = await _sendCommand(AskCommand(_nextId(), request));

    if (response is! EvaluateResponse) {
      throw PklBugError.invalidMessageCode(
        'Expected EvaluateResponse, but got ${response.runtimeType}',
      );
    }

    if (response.error != null) {
      throw PklError(response.error!);
    }

    // we can be sure that if error is null, result is set.
    return response.result!;
  }

  /// Closes this evaluator, cleaning up any resources held by the evaluator.
  Future<void> close() async {
    await _sendCommand(CloseEvaluatorCommand(_nextId(), _evaluatorId));
  }
}
