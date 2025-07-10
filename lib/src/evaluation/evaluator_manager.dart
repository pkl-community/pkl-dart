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

/// Provides handlers for managing the lifecycles of Pkl evaluators.
///
/// An evaluator manager represents a single Pkl child process. Spawning multiple
/// evaluators through one manager is much more efficient than creating new
/// processes, as it allows Pkl to cache and optimize evaluation.
///
/// For simple, one-off evaluations, prefer using the static methods on the
/// [Evaluator] class, like [Evaluator.run].
class EvaluatorManager {
  late final SendPort _sendPortToIsolate;
  late final ReceivePort _receivePortFromIsolate;
  final Map<int, Completer<dynamic>> _commandCompleters = {};

  // Centralized counter for generating unique command IDs to prevent race conditions.
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
    final initPort = RawReceivePort();
    final connection = Completer<(ReceivePort, SendPort)>.sync();
    initPort.handler = (initialMessage) {
      final commandPort = initialMessage as SendPort;
      connection.complete((
        ReceivePort.fromRawReceivePort(initPort),
        commandPort,
      ));
    };

    try {
      await Isolate.spawn(
        evaluatorManagerIsolateEntrypoint,
        initPort.sendPort,
      );
    } on Object {
      initPort.close();
      rethrow;
    }

    final (ReceivePort receivePort, SendPort sendPort) =
        await connection.future;
    return EvaluatorManager._(receivePort, sendPort);
  }

  EvaluatorManager._(this._receivePortFromIsolate, this._sendPortToIsolate) {
    _receivePortFromIsolate.listen(_handleIsolateMessage);
  }

  /// Creates a new evaluator with the provided options.
  Future<Evaluator> newEvaluator({EvaluatorOptions? options}) async {
    options ??= await EvaluatorOptions.preconfigured;
    if (_isClosed) {
      throw PklError(
        'The evaluator manager is closed. Create a new manager by calling EvaluatorManager.spawn().',
      );
    }

    // Register readers and logger, get their IDs
    final clientResourceReaders = <ResourceReaderMessage>[];
    for (final reader in options.resourceReaders ?? <ResourceReader>[]) {
      final id = _nextReaderId++;
      _resourceReaders[id] = reader;
      clientResourceReaders.add(reader.toMessage(id));
    }

    final clientModuleReaders = <ModuleReaderMessage>[];
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

    final evaluator = Evaluator(
      evaluatorId: evaluatorId as int,
      managerSendPort: _sendPortToIsolate,
      commandCompleters: _commandCompleters,
      generateCommandId: () => _nextCommandId++,
    );
    _evaluatorProxies[evaluatorId] = evaluator;

    return evaluator;
  }

  /// Creates a new evaluator that is configured from the provided project.
  ///
  /// The provided [uri] should be the base uri of the project.
  Future<Evaluator> newProjectEvaluator({
    required Uri uri,
    EvaluatorOptions? options,
  }) async {
    // This helper creates a temporary evaluator on the current manager,
    // runs an action, and guarantees its cleanup without spawning a new isolate.
    Future<T> withTempEvaluator<T>(Future<T> Function(Evaluator) action) async {
      final tempEvaluator = await newEvaluator(
        options: await EvaluatorOptions.preconfigured,
      );
      try {
        return await action(tempEvaluator);
      } finally {
        await tempEvaluator.close();
      }
    }

    // Use the temporary evaluator to read the project file.
    final project = await withTempEvaluator((tempEv) async {
      final result =
          await tempEv.evaluateModule(ModuleSource.uri(uri))
              as Map<String, dynamic>;
      return Project.fromJson(result);
    });

    final finalOptions = (options ?? await EvaluatorOptions.preconfigured)
        .withProject(project);
    return await newEvaluator(options: finalOptions);
  }

  /// Closes the evaluator manager, and closes any evaluators that have spawned.
  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    await _sendCommand(CloseManagerCommand(_nextCommandId++));
    _receivePortFromIsolate.close();
  }

  // Send commands to the background Isolate
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

  // Handle messages from the background Isolate
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

  // Handle callbacks from the background Isolate
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
          result = (result as List<PathElement>)
              .map((e) => e.toMessage())
              .toList();
          break;
        case ListResourcesCallback cb:
          final reader = _resourceReaders[cb.readerId];
          if (reader == null) {
            throw PklError('ResourceReader with ID ${cb.readerId} not found.');
          }
          result = await reader.listElements(uri: cb.uri);
          result = (result as List<PathElement>)
              .map((e) => e.toMessage())
              .toList();
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
      _sendPortToIsolate.send(
        CallbackSuccessResponse(callback.callbackId, result),
      );
    } catch (e) {
      log('Error handling callback ${callback.runtimeType}: $e');
      _sendPortToIsolate.send(
        CallbackErrorResponse(callback.callbackId, e.toString()),
      );
    }
  }
}
