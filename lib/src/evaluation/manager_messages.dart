// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import '../message.dart';
import 'pkl_evaluator_settings.dart';

// --- Commands from Main Isolate to Background Isolate ---
sealed class IsolateCommand {
  final int commandId;

  IsolateCommand(this.commandId);
}

class SpawnCommand extends IsolateCommand {
  SpawnCommand(super.commandId);
}

class AskCommand extends IsolateCommand {
  final ClientRequestMessage message;

  AskCommand(super.commandId, this.message);
}

class TellCommand extends IsolateCommand {
  final dynamic message;

  TellCommand(super.commandId, this.message)
    : assert(
        message is ClientOneWayMessage || message is ClientResponseMessage,
        'message must be ClientOneWayMessage or ClientResponseMessage',
      );
}

class CloseEvaluatorCommand extends IsolateCommand {
  final int evaluatorId;

  CloseEvaluatorCommand(super.commandId, this.evaluatorId);
}

class CloseManagerCommand extends IsolateCommand {
  CloseManagerCommand(super.commandId);
}

class NewEvaluatorCommand extends IsolateCommand {
  // Pass all relevant EvaluatorOptions fields directly
  final List<String>? moduleReaders;
  final List<String>? resourceReaders;
  final List<ModuleReaderMessage>? clientModuleReaders;
  final List<ResourceReaderMessage>? clientResourceReaders;
  final List<String>? modulePaths;
  final Map<String, String>? env;
  final Map<String, String>? properties;
  final Duration? timeout;
  final String? rootDir;
  final String? cacheDir;
  final String? outputFormat;
  final ProjectOrDependency? project;
  final Http? http;
  final Map<String, ExternalReader>? externalModuleReaders;
  final Map<String, ExternalReader>? externalResourceReaders;
  final int? loggerId;

  NewEvaluatorCommand(
    super.commandId, {
    this.moduleReaders,
    this.resourceReaders,
    this.clientModuleReaders,
    this.clientResourceReaders,
    this.modulePaths,
    this.env,
    this.properties,
    this.timeout,
    this.rootDir,
    this.cacheDir,
    this.outputFormat,
    this.project,
    this.http,
    this.externalModuleReaders,
    this.externalResourceReaders,
    this.loggerId,
  });
}

// --- Callbacks from Background Isolate to Main Isolate (for user-defined readers/logger) ---
sealed class IsolateCallback {
  final int callbackId;

  IsolateCallback(this.callbackId);
}

class ReadModuleCallback extends IsolateCallback {
  final int readerId;
  final Uri uri;

  ReadModuleCallback(super.callbackId, this.readerId, this.uri);
}

class ReadResourceCallback extends IsolateCallback {
  final int readerId;
  final Uri uri;

  ReadResourceCallback(super.callbackId, this.readerId, this.uri);
}

class ListModulesCallback extends IsolateCallback {
  final int readerId;
  final Uri uri;

  ListModulesCallback(super.callbackId, this.readerId, this.uri);
}

class ListResourcesCallback extends IsolateCallback {
  final int readerId;
  final Uri uri;

  ListResourcesCallback(super.callbackId, this.readerId, this.uri);
}

class LogCallback extends IsolateCallback {
  final int loggerId;
  final LogLevel level;
  final String message;
  final String? frameUri;

  LogCallback(super.callbackId, this.loggerId, this.level, this.message, this.frameUri);
}

// --- Responses from Background Isolate to Main Isolate (for commands) ---
sealed class IsolateResponse {
  final int commandId;

  IsolateResponse(this.commandId);
}

class SuccessResponse extends IsolateResponse {
  final dynamic result;

  SuccessResponse(super.commandId, this.result);
}

class ErrorResponse extends IsolateResponse {
  final String errorMessage;

  ErrorResponse(super.commandId, this.errorMessage);
}

// --- Responses from Main Isolate to Background Isolate (for callbacks) ---
sealed class IsolateCallbackResponse {
  final int callbackId;

  IsolateCallbackResponse(this.callbackId);
}

class CallbackSuccessResponse extends IsolateCallbackResponse {
  final dynamic result; // Can be String, Uint8List, List<PathElementMessage>
  CallbackSuccessResponse(super.callbackId, this.result);
}

class CallbackErrorResponse extends IsolateCallbackResponse {
  final String errorMessage;

  CallbackErrorResponse(super.callbackId, this.errorMessage);
}

// --- Internal messages for the background isolate's message loop ---
class InternalMessage {
  final ServerResponseMessage message;

  InternalMessage(this.message);
}

class InternalRequest {
  final ClientRequestMessage request;

  InternalRequest(this.request);
}
