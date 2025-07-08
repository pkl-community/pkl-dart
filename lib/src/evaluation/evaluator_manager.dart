// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:async';
import 'dart:core';
import 'dart:isolate';

import '../message.dart';
import '../project.dart';
import '../reader.dart';
import 'evaluator.dart';
import 'evaluator_options.dart';
import 'logger.dart';
import 'manager_isolate_logic.dart';
import 'manager_messages.dart';
import 'manager_utils.dart';
import 'module_source.dart';
import 'pkl_error.dart';

/// Performs [action], returns its result and then closes the manager.
///
/// -  [action]: The action to perform
/// - Returns: The result of `action`
Future<dynamic> withEvaluatorManager(Future<dynamic> Function(EvaluatorManager) action) async {
  final manager = await EvaluatorManager.spawn();
  var closed = false;
  try {
    final result = await action(manager);
    await manager.close();
    closed = true;
    return result;
  } catch (e) {
    if (!closed) {
      await manager.close();
    }
    rethrow;
  }
}

/// Provides handlers for managing the lifecycles of Pkl evaluators.
///
/// If binding to Pkl as a child process, an evaluator manager represents a single child process.
/// If spawning multiple evaluators, it is much better to spawn them through the evaluator manager,
/// rather than through `withEvaluator`. This lessens the overhead of each new evaluator,
/// and allows Pkl to cache and optimize evaluation.
class EvaluatorManager {
  late final SendPort _sendPortToIsolate;
  late final ReceivePort _receivePortFromIsolate;
  final Map<int, Completer<dynamic>> _commandCompleters = {};
  int _nextCommandId = 0;

  final Map<int, Evaluator> _evaluatorProxies = {};

  bool _isClosed = false;

  // Maps for storing actual reader/logger objects and their IDs
  final Map<int, ResourceReader> _resourceReaders = {};
  final Map<int, ModuleReader> _moduleReaders = {};
  final Map<int, Logger> _loggers = {};
  int _nextReaderId = 0;

  /// Spawns a background Isolate for the manager logic.
  static Future<EvaluatorManager> spawn() async {
    // Create a receive port and add its initial message handler
    final initPort = RawReceivePort();
    final connection = Completer<(ReceivePort, SendPort)>.sync();
    initPort.handler = (initialMessage) {
      final commandPort = initialMessage as SendPort;
      connection.complete((ReceivePort.fromRawReceivePort(initPort), commandPort));
    };

    // Spawn the isolate.
    try {
      await Isolate.spawn(evaluatorManagerIsolateEntrypoint, (initPort.sendPort));
    } on Object {
      initPort.close();
      rethrow;
    }

    final (ReceivePort receivePort, SendPort sendPort) = await connection.future;

    return EvaluatorManager._(receivePort, sendPort);
  }

  EvaluatorManager._(this._receivePortFromIsolate, this._sendPortToIsolate) {
    _receivePortFromIsolate.listen(_handleIsolateMessage);
  }

  /// Constructs an evaluator with the provided options, and calls the action.
  ///
  /// After the action completes or throws, the evaluator is closed.
  /// If [options] is not provided use preconfigured option
  ///
  ///   - [options]: The options used to configure the evaluator.
  ///   - [action]: The action to run with the evaluator.
  static Future<T> withEvaluator<T>({
    required EvaluationAction action,
    EvaluatorOptions? options,
  }) async {
    final configuredOption = options ?? await EvaluatorOptions.preconfigured;
    return await _withEvaluator(options: configuredOption, action: action);
  }

  static Future<T> _withEvaluator<T>({
    required EvaluationAction action,
    required EvaluatorOptions options,
  }) async {
    final manager = await spawn();
    final evaluator = await manager.newEvaluator(options: options);
    try {
      final result = await action(evaluator);
      return result;
    } catch (e) {
      rethrow;
    } finally {
      manager.close();
    }
  }

  /// Constructs an evaluator that is configured by the project within the project dir.
  ///
  /// `options` is the base set of evaluator options.
  /// Any `evaluatorSettings` set within the PklProject file overwrites any fields set on `options`.
  ///
  /// After the action completes or throws, the evaluator is closed.
  /// If [options] is not provided, preconfigured version is used.
  ///
  ///   - [projectBaseUri]: The project base path that contains the PklProject file.
  ///   - [options]: The options used to configure the evaluator.
  ///   - [action]: The action to run with the evaluator.
  static Future<T> withProjectEvaluator<T>({
    required Uri projectBaseUri,
    required EvaluationAction action,
    EvaluatorOptions? options,
  }) async {
    final configuredOption = options ?? await EvaluatorOptions.preconfigured;
    return await _withProjectEvaluator(
      projectBaseUri: projectBaseUri,
      options: configuredOption,
      action: action,
    );
  }

  static Future<T> _withProjectEvaluator<T>({
    required Uri projectBaseUri,
    required EvaluatorOptions options,
    required EvaluationAction action,
  }) async {
    final manager = await spawn();
    final evaluator = await manager.newProjectEvaluator(
      projectBaseUri: projectBaseUri,
      options: options,
    );
    try {
      final result = await action(evaluator);
      return result;
    } catch (e) {
      rethrow;
    } finally {
      manager.close();
    }
  }

  /// Creates a new evaluator with the provided options.
  ///
  /// To create an evaluator that understands project dependencies, use
  /// `newProjectEvaluator(projectBaseURI:options:)`.
  ///
  /// - [options]: The options used to configure the evaluator.
  Future<Evaluator> newEvaluator({EvaluatorOptions? options}) async {
    options = options ?? await EvaluatorOptions.preconfigured;
    if (_isClosed) {
      throw PklError(
        'The evaluator manager is closed. Create new manager by calling EvaluatorManager.spawn() or EvaluatorManager.withEvaluator()',
      );
    }

    // Register readers and logger, get their IDs
    final List<ResourceReaderMessage> clientResourceReaders = [];
    for (final reader in options.resourceReaders ?? <ResourceReader>[]) {
      final id = _nextReaderId++;
      _resourceReaders[id] = reader;
      clientResourceReaders.add(reader.toMessage(id));
    }

    final List<ModuleReaderMessage> clientModuleReaders = [];
    for (final reader in options.moduleReaders ?? <ModuleReader>[]) {
      final id = _nextReaderId++;
      _moduleReaders[id] = reader;
      clientModuleReaders.add(reader.toMessage(id));
    }

    int? loggerId;
    if (options.logger != null) {
      loggerId = _nextReaderId++;
      _loggers[loggerId] = options.logger!;
    }

    // Send command to background isolate
    final evaluatorId = await _sendCommand(
      NewEvaluatorCommand(
        _nextCommandId++,
        moduleReaders: options.allowedModules,
        resourceReaders: options.allowedResources,
        clientModuleReaders: clientModuleReaders,
        clientResourceReaders: clientResourceReaders,
        modulePaths: options.modulePaths,
        env: options.env,
        properties: options.properties,
        timeout: options.timeout,
        rootDir: options.rootDir,
        cacheDir: options.cacheDir,
        outputFormat: options.outputFormat,
        project: options.toProjectOrDependency(),
        http: options.http,
        externalModuleReaders: options.externalModuleReaders,
        externalResourceReaders: options.externalResourceReaders,
        loggerId: loggerId,
      ),
    );

    final evaluator = Evaluator.create(
      evaluatorId: evaluatorId as int,
      managerSendPort: _sendPortToIsolate,
      commandCompleters: _commandCompleters,
    );
    _evaluatorProxies[evaluatorId] = evaluator;

    return evaluator;
  }

  /// Creates a new evaluator that is configured from the provided project.
  ///
  /// `options` is the base set of evaluator options.
  /// Any `evaluatorSettings` set within the PklProject file overwrites any fields set on `options`.
  ///
  ///   - [projectBaseUri]: The project base path containing the `PklProject` file.
  ///   - [options]: The base options used to configure the evaluator.
  Future<Evaluator> newProjectEvaluator({
    required Uri projectBaseUri,
    EvaluatorOptions? options,
  }) async {
    /// Loads a project by creating a temporary evaluator
    final preconfigured = await EvaluatorOptions.preconfigured;
    options = options ?? preconfigured;
    return await withEvaluator(
      options: preconfigured,
      action: (ev) async {
        final result =
            await ev.evaluateModule(ModuleSource.uri(projectBaseUri)) as Map<String, dynamic>;

        // Deserialize the result into our Dart Project model
        final project = Project.fromJson(result);

        return await newEvaluator(options: options!.withProject(project));
      },
    );
  }

  /// Closes the evaluator manager, and closes any evaluators that have spawned.
  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;

    // Send close command to background isolate
    await _sendCommand(CloseManagerCommand(_nextCommandId++));

    // Close the receive port, which will cause the background isolate to exit
    _receivePortFromIsolate.close();
  }

  // Internal method to send commands to the background Isolate
  Future<dynamic> _sendCommand(IsolateCommand command) async {
    final completer = Completer<dynamic>();
    _commandCompleters[command.commandId] = completer;
    _sendPortToIsolate.send(command);
    final result = await completer.future;
    if (result is String && result.startsWith('Error:')) {
      throw PklError(result.substring(6).trim());
    }
    return result;
  }

  // Internal method to handle messages from the background Isolate
  void _handleIsolateMessage(dynamic message) {
    if (message is IsolateResponse) {
      final completer = _commandCompleters.remove(message.commandId);
      if (completer != null) {
        if (message is SuccessResponse) {
          completer.complete(message.result);
        } else if (message is ErrorResponse) {
          completer.completeError(PklError(message.errorMessage));
        }
      } else {
        log('Received response for unknown command ID: ${message.commandId}');
      }
    } else if (message is IsolateCallback) {
      _handleIsolateCallback(message);
    } else {
      log('Received unknown message from Isolate: $message');
    }
  }

  // Internal method to handle callbacks from the background Isolate
  void _handleIsolateCallback(IsolateCallback callback) async {
    try {
      dynamic result;
      switch (callback) {
        case ReadModuleCallback cb:
          final reader = _moduleReaders[cb.readerId];
          if (reader == null) {
            throw PklError('ModuleReader with ID ${cb.readerId} not found.');
          }
          result = await reader.read(url: cb.uri);
          break;
        case ReadResourceCallback cb:
          final reader = _resourceReaders[cb.readerId];
          if (reader == null) {
            throw PklError('ResourceReader with ID ${cb.readerId} not found.');
          }
          result = await reader.read(url: cb.uri);
          break;
        case ListModulesCallback cb:
          final reader = _moduleReaders[cb.readerId];
          if (reader == null) {
            throw PklError('ModuleReader with ID ${cb.readerId} not found.');
          }
          result = await reader.listElements(uri: cb.uri);
          // Convert PathElement to PathElementMessage if necessary
          result = (result as List<PathElement>).map((e) => e.toMessage()).toList();
          break;
        case ListResourcesCallback cb:
          final reader = _resourceReaders[cb.readerId];
          if (reader == null) {
            throw PklError('ResourceReader with ID ${cb.readerId} not found.');
          }
          result = await reader.listElements(uri: cb.uri);
          // Convert PathElement to PathElementMessage if necessary
          result = (result as List<PathElement>).map((e) => e.toMessage()).toList();
          break;
        case LogCallback cb:
          final logger = _loggers[cb.loggerId];
          if (logger == null) {
            log('Logger with ID ${cb.loggerId} not found for log message.');
            return; // No response needed for log
          }
          switch (cb.level) {
            case LogLevel.trace:
              logger.trace(message: cb.message, frameUri: cb.frameUri ?? '');
              break;
            case LogLevel.warn:
              logger.warn(message: cb.message, frameUri: cb.frameUri ?? '');
              break;
          }
          return; // No response needed for log
      }
      _sendPortToIsolate.send(CallbackSuccessResponse(callback.callbackId, result));
    } catch (e) {
      log('Error handling callback ${callback.runtimeType}: $e');
      _sendPortToIsolate.send(CallbackErrorResponse(callback.callbackId, e.toString()));
    }
  }
}
