import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:pub_semver/pub_semver.dart';

import '../message.dart';
import 'logger.dart';
import 'manager_messages.dart';
import 'manager_utils.dart';
import 'pkl_error.dart';
import 'pkl_evaluator_settings.dart';
import 'transport.dart';

/// Copyright (c) 2025 Kirk Agbenyegah
///
/// This source code is licensed under the MIT license found in the
/// LICENSE file in the root directory of this source tree.

/// The entry point for the background Isolate that runs the EvaluatorManager logic.
Future<void> evaluatorManagerIsolateEntrypoint(SendPort mainIsolateSendPort) async {
  final receivePort = ReceivePort();
  mainIsolateSendPort.send(receivePort.sendPort); // Send back the receive port's SendPort

  final logic = _EvaluatorManagerLogic(mainIsolateSendPort);
  await logic._init();

  receivePort.listen((message) async {
    if (message is IsolateCommand) {
      try {
        dynamic result;
        switch (message) {
          case SpawnCommand _:
            // Handled by the Isolate setup itself
            break;
          case AskCommand cmd:
            result = await logic._ask(cmd.message);
            break;
          case TellCommand cmd:
            logic._tell(cmd.message);
            break;
          case CloseEvaluatorCommand cmd:
            await logic._closeEvaluator(cmd.evaluatorId);
            break;
          case CloseManagerCommand _:
            await logic._close();
            break;
          case NewEvaluatorCommand cmd:
            result = await logic._newEvaluator(
              allowedModules: cmd.moduleReaders,
              allowedResources: cmd.resourceReaders,
              clientModuleReaders: cmd.clientModuleReaders,
              clientResourceReaders: cmd.clientResourceReaders,
              modulePaths: cmd.modulePaths,
              env: cmd.env,
              properties: cmd.properties,
              timeout: cmd.timeout,
              rootDir: cmd.rootDir,
              cacheDir: cmd.cacheDir,
              outputFormat: cmd.outputFormat,
              project: cmd.project,
              http: cmd.http,
              externalModuleReaders: cmd.externalModuleReaders,
              externalResourceReaders: cmd.externalResourceReaders,
              loggerId: cmd.loggerId,
            );
            break;
        }
        mainIsolateSendPort.send(SuccessResponse(message.commandId, result));
      } catch (e) {
        Loggers.standardError.warn(
          message: 'Error processing command ${message.runtimeType}: $e',
          frameUri: '',
        );
        mainIsolateSendPort.send(ErrorResponse(message.commandId, e.toString()));
      }
    } else if (message is IsolateCallbackResponse) {
      // Handle responses to callbacks initiated by this isolate
      logic._callbackCompleters.remove(message.callbackId)?.complete(message);
    }
  });
}

/// Manages the lifecycle of Pkl evaluators within a background Isolate.
class _EvaluatorManagerLogic {
  final SendPort _mainIsolateSendPort;
  late final MessageTransport _transport;

  final Map<int, Completer<ServerResponseMessage>> _inFlightRequests = {};
  final Map<int, Completer<IsolateCallbackResponse>> _callbackCompleters = {};
  int _nextCallbackId = 0;

  final Map<int, _EvaluatorInternal> _evaluators = {};

  bool _isClosed = false;
  String? _pklVersion;

  _EvaluatorManagerLogic(this._mainIsolateSendPort);

  Future<void> _init() async {
    _transport = await ServerMessageTransport.create();
    _listenForIncomingMessages();
  }

  Future<String> _getVersion() async {
    if (_pklVersion != null) {
      return _pklVersion!;
    }
    _pklVersion = await getPklVersion();
    return _pklVersion!;
  }

  Future<int> _newEvaluator({
    List<String>? allowedModules,
    List<String>? allowedResources,
    List<ModuleReaderMessage>? clientModuleReaders,
    List<ResourceReaderMessage>? clientResourceReaders,
    List<String>? modulePaths,
    Map<String, String>? env,
    Map<String, String>? properties,
    Duration? timeout,
    String? rootDir,
    String? cacheDir,
    String? outputFormat,
    ProjectOrDependency? project,
    Http? http,
    Map<String, ExternalReader>? externalModuleReaders,
    Map<String, ExternalReader>? externalResourceReaders,
    int? loggerId,
  }) async {
    if (_isClosed) {
      throw PklError('The evaluator manager is closed');
    }

    final version = Version.parse(await _getVersion());

    if (http != null && version < pklVersion0_26) {
      throw PklError("http options are not supported on Pkl versions lower than 0.26");
    }
    if ((externalModuleReaders != null || externalResourceReaders != null) &&
        version < pklVersion0_27) {
      throw PklError("external reader options are not supported on Pkl versions lower than 0.27");
    }

    final req = CreateEvaluatorRequest(
      requestId: 0,
      allowedModules: allowedModules,
      allowedResources: allowedResources,
      clientModuleReaders: clientModuleReaders,
      clientResourceReaders: clientResourceReaders,
      modulePaths: modulePaths,
      env: env,
      properties: properties,
      timeoutInSeconds: timeout?.inSeconds,
      rootDir: rootDir,
      cacheDir: cacheDir,
      outputFormat: outputFormat,
      project: project,
      http: http,
      externalModuleReaders: externalModuleReaders,
      externalResourceReaders: externalResourceReaders,
      loggerId: loggerId,
    );

    final response = await _ask(req);

    if (response is! CreateEvaluatorResponse) {
      throw PklBugError.invalidMessageCode(
        'Received invalid response to create evaluator request: ${response.runtimeType}',
      );
    }

    if (response.error != null) {
      throw PklError(response.error!);
    }

    final id = response.evaluatorId!;
    final evaluator = _EvaluatorInternal(
      managerLogic: this,
      evaluatorId: id,
      resourceReaderIds: clientResourceReaders?.map((r) => r.id).toList() ?? [],
      moduleReaderIds: clientModuleReaders?.map((r) => r.id).toList() ?? [],
      loggerId: loggerId,
    );
    _evaluators[id] = evaluator;
    return id; // Return the evaluator ID to the main isolate
  }

  Future<void> _closeEvaluator(int evaluatorId) async {
    _evaluators.remove(evaluatorId);
    _tell(CloseEvaluatorRequest(evaluatorId: evaluatorId));
  }

  Future<void> _close() async {
    _isClosed = true;
    for (final evaluatorId in _evaluators.keys) {
      _tell(CloseEvaluatorRequest(evaluatorId: evaluatorId)); // requestId will be set by transport
    }
    _transport.close();
  }

  Future<ServerResponseMessage> _ask(ClientRequestMessage message) async {
    final completer = Completer<ServerResponseMessage>();
    final requestId = _generateRequestId();
    message.requestId = requestId;

    _inFlightRequests[requestId] = completer;
    try {
      await _transport.send(message);
    } catch (e) {
      _inFlightRequests.remove(requestId)?.completeError(e);
      rethrow;
    }
    return completer.future;
  }

  void _tell(ClientMessage message) {
    try {
      _transport.send(message);
    } catch (e) {
      log('Error sending one-way message: $e');
    }
  }

  void _listenForIncomingMessages() async {
    try {
      await for (final message in _transport.messages) {
        log('Received message: ${message.runtimeType}');
        if (message is ServerResponseMessage) {
          _inFlightRequests.remove(message.requestId)?.complete(message);
        } else if (message is ReadModuleRequest) {
          await _handleReadModuleRequest(message);
        } else if (message is ReadResourceRequest) {
          await _handleReadResourceRequest(message);
        } else if (message is ListModulesRequest) {
          await _handleListModulesRequest(message);
        } else if (message is ListResourcesRequest) {
          await _handleListResourcesRequest(message);
        } else if (message is LogMessage) {
          _handleLog(message);
        } else {
          log('Unknown message type received: ${message.runtimeType}');
          throw PklBugError.unknownMessage('Unknown message type received: ${message.runtimeType}');
        }
      }
    } catch (e) {
      log('Error listening for messages: $e');
      _closeError(error: e);
    }
  }

  void _closeError({required dynamic error}) {
    for (final completer in _inFlightRequests.values) {
      completer.completeError(error);
    }
    _inFlightRequests.clear();
    _close();
  }

  int _generateRequestId() {
    return DateTime.now().microsecondsSinceEpoch;
  }

  // --- Handlers for Pkl-initiated requests (callbacks to main isolate) ---

  Future<void> _handleReadModuleRequest(ReadModuleRequest request) async {
    final evaluator = _evaluators[request.evaluatorId];
    if (evaluator == null) {
      log('Received ReadModuleRequest for unknown evaluator ID: ${request.evaluatorId}');
      _tell(
        ReadModuleResponse(
          requestId: request.requestId,
          evaluatorId: request.evaluatorId,
          error: PklBugError.invalidEvaluatorId(
            'Received request for unknown evaluator id ${request.evaluatorId}',
          ).toString(),
        ),
      );
      return;
    }

    final callbackId = _nextCallbackId++;
    final completer = Completer<IsolateCallbackResponse>();
    _callbackCompleters[callbackId] = completer;

    _mainIsolateSendPort.send(
      ReadModuleCallback(
        callbackId,
        evaluator.moduleReaderIds.firstWhere((id) => true),
        request.uri,
      ),
    ); // Assuming one reader for simplicity

    try {
      final response = await completer.future;
      if (response is CallbackSuccessResponse) {
        _tell(
          ReadModuleResponse(
            requestId: request.requestId,
            evaluatorId: request.evaluatorId,
            contents: response.result as String,
          ),
        );
      } else if (response is CallbackErrorResponse) {
        _tell(
          ReadModuleResponse(
            requestId: request.requestId,
            evaluatorId: request.evaluatorId,
            error: response.errorMessage,
          ),
        );
      }
    } catch (e) {
      log('Error handling ReadModuleRequest callback: $e');
      _tell(
        ReadModuleResponse(
          requestId: request.requestId,
          evaluatorId: request.evaluatorId,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _handleReadResourceRequest(ReadResourceRequest request) async {
    final evaluator = _evaluators[request.evaluatorId];
    if (evaluator == null) {
      log('Received ReadResourceRequest for unknown evaluator ID: ${request.evaluatorId}');
      _tell(
        ReadResourceResponse(
          requestId: request.requestId,
          evaluatorId: request.evaluatorId,
          error: PklBugError.invalidEvaluatorId(
            'Received request for unknown evaluator id ${request.evaluatorId}',
          ).toString(),
        ),
      );
      return;
    }

    final callbackId = _nextCallbackId++;
    final completer = Completer<IsolateCallbackResponse>();
    _callbackCompleters[callbackId] = completer;

    _mainIsolateSendPort.send(
      ReadResourceCallback(
        callbackId,
        evaluator.resourceReaderIds.firstWhere((id) => true),
        request.uri,
      ),
    ); // Assuming one reader for simplicity

    try {
      final response = await completer.future;
      if (response is CallbackSuccessResponse) {
        _tell(
          ReadResourceResponse(
            requestId: request.requestId,
            evaluatorId: request.evaluatorId,
            contents: response.result as Uint8List,
          ),
        );
      } else if (response is CallbackErrorResponse) {
        _tell(
          ReadResourceResponse(
            requestId: request.requestId,
            evaluatorId: request.evaluatorId,
            error: response.errorMessage,
          ),
        );
      }
    } catch (e) {
      log('Error handling ReadResourceRequest callback: $e');
      _tell(
        ReadResourceResponse(
          requestId: request.requestId,
          evaluatorId: request.evaluatorId,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _handleListModulesRequest(ListModulesRequest request) async {
    final evaluator = _evaluators[request.evaluatorId];
    if (evaluator == null) {
      log('Received ListModulesRequest for unknown evaluator ID: ${request.evaluatorId}');
      _tell(
        ListModulesResponse(
          requestId: request.requestId,
          evaluatorId: request.evaluatorId,
          error: PklBugError.invalidEvaluatorId(
            'Received request for unknown evaluator id ${request.evaluatorId}',
          ).toString(),
        ),
      );
      return;
    }

    final callbackId = _nextCallbackId++;
    final completer = Completer<IsolateCallbackResponse>();
    _callbackCompleters[callbackId] = completer;

    _mainIsolateSendPort.send(
      ListModulesCallback(
        callbackId,
        evaluator.moduleReaderIds.firstWhere((id) => true),
        request.uri,
      ),
    ); // Assuming one reader for simplicity

    try {
      final response = await completer.future;
      if (response is CallbackSuccessResponse) {
        _tell(
          ListModulesResponse(
            requestId: request.requestId,
            evaluatorId: request.evaluatorId,
            pathElements: (response.result as List).cast<PathElementMessage>(),
          ),
        );
      } else if (response is CallbackErrorResponse) {
        _tell(
          ListModulesResponse(
            requestId: request.requestId,
            evaluatorId: request.evaluatorId,
            error: response.errorMessage,
          ),
        );
      }
    } catch (e) {
      log('Error handling ListModulesRequest callback: $e');
      _tell(
        ListModulesResponse(
          requestId: request.requestId,
          evaluatorId: request.evaluatorId,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> _handleListResourcesRequest(ListResourcesRequest request) async {
    final evaluator = _evaluators[request.evaluatorId];
    if (evaluator == null) {
      log('Received ListResourcesRequest for unknown evaluator ID: ${request.evaluatorId}');
      _tell(
        ListResourcesResponse(
          requestId: request.requestId,
          evaluatorId: request.evaluatorId,
          error: PklBugError.invalidEvaluatorId(
            'Received request for unknown evaluator id ${request.evaluatorId}',
          ).toString(),
        ),
      );
      return;
    }

    final callbackId = _nextCallbackId++;
    final completer = Completer<IsolateCallbackResponse>();
    _callbackCompleters[callbackId] = completer;

    _mainIsolateSendPort.send(
      ListResourcesCallback(
        callbackId,
        evaluator.resourceReaderIds.firstWhere((id) => true),
        request.uri,
      ),
    ); // Assuming one reader for simplicity

    try {
      final response = await completer.future;
      if (response is CallbackSuccessResponse) {
        _tell(
          ListResourcesResponse(
            requestId: request.requestId,
            evaluatorId: request.evaluatorId,
            pathElements: (response.result as List).cast<PathElementMessage>(),
          ),
        );
      } else if (response is CallbackErrorResponse) {
        _tell(
          ListResourcesResponse(
            requestId: request.requestId,
            evaluatorId: request.evaluatorId,
            error: response.errorMessage,
          ),
        );
      }
    } catch (e) {
      log('Error handling ListResourcesRequest callback: $e');
      _tell(
        ListResourcesResponse(
          requestId: request.requestId,
          evaluatorId: request.evaluatorId,
          error: e.toString(),
        ),
      );
    }
  }

  void _handleLog(LogMessage request) {
    final evaluator = _evaluators[request.evaluatorId];
    if (evaluator == null) {
      log('Received LogMessage for unknown evaluator ID: ${request.evaluatorId}');
      return;
    }

    if (evaluator.loggerId == null) {
      log('Log message received for evaluator ${request.evaluatorId} but no logger configured.');
      return;
    }

    final callbackId = _nextCallbackId++;
    final completer = Completer<IsolateCallbackResponse>();
    _callbackCompleters[callbackId] =
        completer; // Not strictly needed for fire-and-forget, but good for consistency

    _mainIsolateSendPort.send(
      LogCallback(
        callbackId,
        evaluator.loggerId!,
        request.level,
        request.message,
        request.frameUri,
      ),
    );
    // No need to await for log messages, they are one-way from Pkl's perspective
  }
}

/// Internal representation of an Evaluator within the background Isolate.
/// This holds the IDs of the associated readers/logger in the main isolate.
class _EvaluatorInternal {
  final _EvaluatorManagerLogic managerLogic;
  final int evaluatorId;
  final List<int> resourceReaderIds;
  final List<int> moduleReaderIds;
  final int? loggerId;

  _EvaluatorInternal({
    required this.managerLogic,
    required this.evaluatorId,
    required this.resourceReaderIds,
    required this.moduleReaderIds,
    required this.loggerId,
  });
}
