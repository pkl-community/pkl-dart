// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import './evaluation/pkl_evaluator_settings.dart';
import 'extensions.dart';

sealed class Message {
  int? get requestId;

  /// Converts the message map.
  ///
  /// A nullable type means that the property should be omitted.
  Map<String, dynamic> propertyMap();
}

sealed class OneWayMessage implements Message {}

sealed class RequestMessage implements Message {
  @override
  int requestId = 0;
}

sealed class ResponseMessage implements Message {
  @override
  int get requestId;
}

sealed class ClientMessage implements Message {}

sealed class ClientRequestMessage implements ClientMessage, RequestMessage {}

sealed class ClientResponseMessage implements ClientMessage, ResponseMessage {}

sealed class ClientOneWayMessage implements ClientMessage, OneWayMessage {}

sealed class ServerMessage implements Message {}

sealed class ServerRequestMessage implements ServerMessage, RequestMessage {}

sealed class ServerResponseMessage implements ServerMessage, ResponseMessage {}

sealed class ServerOneWayMessage implements ServerMessage, OneWayMessage {}

class ModuleReaderMessage {
  final int id;
  final String scheme;
  final bool hasHierarchicalUris;
  final bool isLocal;
  final bool isGlobbable;

  ModuleReaderMessage({
    this.id = 0,
    required this.scheme,
    required this.hasHierarchicalUris,
    required this.isLocal,
    required this.isGlobbable,
  });

  Map<String, dynamic> toJson() => {
    'scheme': scheme,
    'hasHierarchicalUris': hasHierarchicalUris,
    'isLocal': isLocal,
    'isGlobbable': isGlobbable,
  };

  factory ModuleReaderMessage.fromJson(Map<String, dynamic> json) =>
      ModuleReaderMessage(
        scheme: json['scheme'] as String,
        hasHierarchicalUris: json['hasHierarchicalUris'] as bool,
        isLocal: json['isLocal'] as bool,
        isGlobbable: json['isGlobbable'] as bool,
      );

  Map<String, dynamic> propertyMap() {
    final map = toJson();
    map.removeWhere((key, value) => value == null);

    return map;
  }
}

class ResourceReaderMessage {
  final int id;
  final String scheme;
  final bool hasHierarchicalUris;
  final bool isGlobbable;

  ResourceReaderMessage({
    required this.scheme,
    required this.hasHierarchicalUris,
    required this.isGlobbable,
    this.id = 0,
  });

  Map<String, dynamic> toJson() => {
    'scheme': scheme,
    'hasHierarchicalUris': hasHierarchicalUris,
    'isGlobbable': isGlobbable,
  };

  factory ResourceReaderMessage.fromJson(Map<String, dynamic> json) =>
      ResourceReaderMessage(
        scheme: json['scheme'] as String,
        hasHierarchicalUris: json['hasHierarchicalUris'] as bool,
        isGlobbable: json['isGlobbable'] as bool,
      );

  Map<String, dynamic> propertyMap() {
    final map = toJson();
    map.removeWhere((key, value) => value == null);

    return map;
  }
}

enum MessageType {
  createEvaluatorRequest(0x20),
  createEvaluatorResponse(0x21),
  closeEvaluator(0x22),
  evaluateRequest(0x23),
  evaluateResponse(0x24),
  logMessage(0x25),
  readResourceRequest(0x26),
  readResourceResponse(0x27),
  readModuleRequest(0x28),
  readModuleResponse(0x29),
  listResourcesRequest(0x2A),
  listResourcesResponse(0x2B),
  listModulesRequest(0x2C),
  listModulesResponse(0x2D),
  initializeModuleReaderRequest(0x2E),
  initializeModuleReaderResponse(0x2F),
  initializeResourceReaderRequest(0x30),
  initializeResourceReaderResponse(0x31),
  closeExternalProcess(0x32);

  const MessageType(this.value);

  final int value;

  static MessageType getMessageType(Message message) {
    return switch (message) {
      CreateEvaluatorRequest() => MessageType.createEvaluatorRequest,
      CreateEvaluatorResponse() => MessageType.createEvaluatorResponse,
      CloseEvaluatorRequest() => MessageType.closeEvaluator,
      EvaluateRequest() => MessageType.evaluateRequest,
      EvaluateResponse() => MessageType.evaluateResponse,
      LogMessage() => MessageType.logMessage,
      ReadResourceRequest() => MessageType.readResourceRequest,
      ReadResourceResponse() => MessageType.readResourceResponse,
      ReadModuleRequest() => MessageType.readModuleRequest,
      ReadModuleResponse() => MessageType.readModuleResponse,
      ListResourcesRequest() => MessageType.listResourcesRequest,
      ListResourcesResponse() => MessageType.listResourcesResponse,
      ListModulesRequest() => MessageType.listModulesRequest,
      ListModulesResponse() => MessageType.listModulesResponse,
      InitializeModuleReaderRequest() =>
        MessageType.initializeModuleReaderRequest,
      InitializeModuleReaderResponse() =>
        MessageType.initializeModuleReaderResponse,
      InitializeResourceReaderRequest() =>
        MessageType.initializeResourceReaderRequest,
      InitializeResourceReaderResponse() =>
        MessageType.initializeResourceReaderResponse,
      CloseExternalProcess() => MessageType.closeExternalProcess,
    };
  }

  /// Add functionality to get message type from code
  static MessageType? fromValue(int value) {
    for (final type in MessageType.values) {
      if (type.value == value) {
        return type;
      }
    }
    return null;
  }
}

class CreateEvaluatorRequest implements ClientRequestMessage {
  @override
  int requestId = 0;
  List<String>? allowedModules;
  List<String>? allowedResources;
  List<ModuleReaderMessage>? clientModuleReaders;
  List<ResourceReaderMessage>? clientResourceReaders;
  List<String>? modulePaths;
  Map<String, String>? env;
  Map<String, String>? properties;
  int? timeoutInSeconds;
  String? rootDir;
  String? cacheDir;
  String? outputFormat;
  ProjectOrDependency? project;
  Http? http;
  final Map<String, ExternalReader>? externalModuleReaders;
  final Map<String, ExternalReader>? externalResourceReaders;
  int? loggerId;

  CreateEvaluatorRequest({
    this.requestId = 0,
    this.allowedModules,
    this.allowedResources,
    this.clientModuleReaders,
    this.clientResourceReaders,
    this.modulePaths,
    this.env,
    this.properties,
    this.timeoutInSeconds,
    this.rootDir,
    this.cacheDir,
    this.outputFormat,
    this.project,
    this.http,
    this.externalModuleReaders,
    this.externalResourceReaders,
    this.loggerId,
  });

  @override
  Map<String, dynamic> propertyMap() {
    final moduleReaders = clientModuleReaders
        ?.map((r) => r.propertyMap())
        .toList();
    final resourceReaders = clientResourceReaders
        ?.map((r) => r.propertyMap())
        .toList();
    final externalMr = externalModuleReaders?.map(
      (k, v) => MapEntry(k, v.propertiesMap()),
    );
    final externalRr = externalResourceReaders?.map(
      (k, v) => MapEntry(k, v.propertiesMap()),
    );
    return <String, dynamic>{}
        .addIfNotNull('requestId', requestId)
        .addIfNotNull('allowedModules', allowedModules)
        .addIfNotNull('allowedResources', allowedResources)
        .addIfNotNull('clientModuleReaders', moduleReaders)
        .addIfNotNull('clientResourceReaders', resourceReaders)
        .addIfNotNull('modulePaths', modulePaths)
        .addIfNotNull('env', env)
        .addIfNotNull('properties', properties)
        .addIfNotNull('timeoutInSeconds', timeoutInSeconds)
        .addIfNotNull('rootDir', rootDir)
        .addIfNotNull('cacheDir', cacheDir)
        .addIfNotNull('outputFormat', outputFormat)
        .addIfNotNull('project', project?.propertiesMap())
        .addIfNotNull('http', http?.propertiesMap())
        .addIfNotNull('externalModuleReaders', externalMr)
        .addIfNotNull('externalResourceReaders', externalRr)
        .addIfNotNull('loggerId', loggerId);
  }
}

class ProjectOrDependency extends Equatable {
  final String? packageUri;
  final String type;
  final String? projectFileUri;
  final Checksums? checksums;
  final Map<String, ProjectOrDependency>? dependencies;

  ProjectOrDependency({
    this.packageUri,
    required this.type,
    this.projectFileUri,
    this.checksums,
    this.dependencies,
  });

  @override
  List<Object?> get props => [
    packageUri,
    type,
    projectFileUri,
    checksums,
    dependencies,
  ];

  Map<String, dynamic> toJson() => {
    'packageUri': packageUri,
    'type': type,
    'projectFileUri': projectFileUri,
    'checksums': checksums?.toJson(),
    'dependencies': dependencies?.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory ProjectOrDependency.fromJson(Map<String, dynamic> json) =>
      ProjectOrDependency(
        packageUri: json['packageUri'] as String?,
        type: json['type'] as String,
        projectFileUri: json['projectFileUri'] as String?,
        checksums: json['checksums'] != null
            ? Checksums.fromJson(json['checksums'])
            : null,
        dependencies: json['dependencies'] != null
            ? (json['dependencies'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, ProjectOrDependency.fromJson(v)),
              )
            : null,
      );

  Map<String, dynamic> propertiesMap() {
    final map = toJson();
    map.removeWhere((key, value) => value == null);
    final Map<String, dynamic>? deps = map['dependencies'];
    if (deps != null) {
      /// Remove keys with null values in [deps]
      deps.removeWhere((key, value) => value == null);
    }

    return map;
  }
}

class Checksums extends Equatable {
  final String? sha256;

  Checksums({this.sha256});

  @override
  List<Object?> get props => [sha256];

  Map<String, dynamic> toJson() => {'sha256': sha256};

  factory Checksums.fromJson(Map<String, dynamic> json) =>
      Checksums(sha256: json['sha256'] as String?);

  Map<String, dynamic> propertiesMap() {
    final map = toJson();
    map.removeWhere((key, value) => value == null);

    return map;
  }
}

class CreateEvaluatorResponse implements ServerResponseMessage {
  @override
  final int requestId;
  final int? evaluatorId;
  final String? error;

  CreateEvaluatorResponse({
    required this.requestId,
    this.evaluatorId,
    this.error,
  });

  @override
  Map<String, dynamic> propertyMap() {
    return <String, dynamic>{}
        .addIfNotNull('requestId', requestId)
        .addIfNotNull('evaluatorId', evaluatorId)
        .addIfNotNull('error', error);
  }
}

class ReadResourceRequest implements ServerRequestMessage {
  @override
  int requestId;
  final int evaluatorId;
  final Uri uri;

  ReadResourceRequest({
    required this.requestId,
    required this.evaluatorId,
    required this.uri,
  });

  @override
  Map<String, dynamic> propertyMap() {
    return <String, dynamic>{}
        .addIfNotNull('requestId', requestId)
        .addIfNotNull('evaluatorId', evaluatorId)
        .addIfNotNull('uri', uri.toString());
  }
}

class ReadResourceResponse implements ClientResponseMessage {
  @override
  int requestId;
  int evaluatorId;
  Uint8List? contents;
  String? error;

  ReadResourceResponse({
    required this.requestId,
    required this.evaluatorId,
    this.contents,
    this.error,
  });

  @override
  Map<String, dynamic> propertyMap() {
    return <String, dynamic>{}
        .addIfNotNull('requestId', requestId)
        .addIfNotNull('evaluatorId', evaluatorId)
        .addIfNotNull('contents', contents)
        .addIfNotNull('error', error);
  }
}

class ReadModuleRequest implements ServerRequestMessage {
  @override
  int requestId;
  final int evaluatorId;
  final Uri uri;

  ReadModuleRequest({
    required this.requestId,
    required this.evaluatorId,
    required this.uri,
  });

  @override
  Map<String, dynamic> propertyMap() {
    return <String, dynamic>{}
        .addIfNotNull('requestId', requestId)
        .addIfNotNull('evaluatorId', evaluatorId)
        .addIfNotNull('uri', uri.toString());
  }
}

class ReadModuleResponse implements ClientResponseMessage {
  @override
  int requestId;
  int evaluatorId;
  String? contents;
  String? error;

  ReadModuleResponse({
    required this.requestId,
    required this.evaluatorId,
    this.contents,
    this.error,
  });

  @override
  Map<String, dynamic> propertyMap() {
    return <String, dynamic>{}
        .addIfNotNull('requestId', requestId)
        .addIfNotNull('evaluatorId', evaluatorId)
        .addIfNotNull('contents', contents)
        .addIfNotNull('error', error);
  }
}

class ListResourcesRequest implements ServerRequestMessage {
  @override
  int requestId;
  int evaluatorId;
  Uri uri;

  ListResourcesRequest({
    required this.requestId,
    required this.evaluatorId,
    required this.uri,
  });

  @override
  Map<String, dynamic> propertyMap() {
    return <String, dynamic>{}
        .addIfNotNull('requestId', requestId)
        .addIfNotNull('evaluatorId', evaluatorId)
        .addIfNotNull('uri', uri.toString());
  }
}

class ListResourcesResponse implements ClientResponseMessage {
  @override
  int requestId;
  int evaluatorId;
  List<PathElementMessage>? pathElements;
  String? error;

  ListResourcesResponse({
    required this.requestId,
    required this.evaluatorId,
    this.pathElements,
    this.error,
  });

  @override
  Map<String, dynamic> propertyMap() {
    return <String, dynamic>{}
        .addIfNotNull('requestId', requestId)
        .addIfNotNull('evaluatorId', evaluatorId)
        .addIfNotNull(
          'pathElements',
          pathElements?.map((e) => e.propertyMap()).toList(),
        )
        .addIfNotNull('error', error);
  }
}

class PathElementMessage {
  String name;
  bool isDirectory;

  PathElementMessage({required this.name, required this.isDirectory});

  Map<String, dynamic> toJson() => {'name': name, 'isDirectory': isDirectory};

  factory PathElementMessage.fromJson(Map<String, dynamic> json) =>
      PathElementMessage(
        name: json['name'] as String,
        isDirectory: json['isDirectory'] as bool,
      );

  Map<String, dynamic> propertyMap() {
    final map = toJson();
    map.removeWhere((key, value) => value == null);

    return map;
  }
}

class ListModulesRequest implements ServerRequestMessage {
  @override
  int requestId;
  int evaluatorId;
  Uri uri;

  ListModulesRequest({
    required this.requestId,
    required this.evaluatorId,
    required this.uri,
  });

  @override
  Map<String, dynamic> propertyMap() {
    return <String, dynamic>{}
        .addIfNotNull('requestId', requestId)
        .addIfNotNull('evaluatorId', evaluatorId)
        .addIfNotNull('uri', uri.toString());
  }
}

class ListModulesResponse implements ClientResponseMessage {
  @override
  int requestId;
  int evaluatorId;
  List<PathElementMessage>? pathElements;
  String? error;

  ListModulesResponse({
    required this.requestId,
    required this.evaluatorId,
    this.pathElements,
    this.error,
  });

  @override
  Map<String, dynamic> propertyMap() {
    return <String, dynamic>{}
        .addIfNotNull('requestId', requestId)
        .addIfNotNull('evaluatorId', evaluatorId)
        .addIfNotNull(
          'pathElements',
          pathElements?.map((e) => e.propertyMap()).toList(),
        )
        .addIfNotNull('error', error);
  }
}

class CloseEvaluatorRequest implements ClientOneWayMessage {
  int evaluatorId;

  CloseEvaluatorRequest({required this.evaluatorId});

  @override
  int? get requestId => null;

  @override
  Map<String, dynamic> propertyMap() {
    return <String, dynamic>{}.addIfNotNull('evaluatorId', evaluatorId);
  }
}

class EvaluateRequest implements ClientRequestMessage {
  @override
  int requestId;
  int evaluatorId;
  Uri moduleUri;
  String? moduleText;
  String? expr;

  EvaluateRequest({
    required this.requestId,
    required this.evaluatorId,
    required this.moduleUri,
    this.moduleText,
    this.expr,
  });

  @override
  Map<String, dynamic> propertyMap() {
    return <String, dynamic>{}
        .addIfNotNull('requestId', requestId)
        .addIfNotNull('evaluatorId', evaluatorId)
        .addIfNotNull('moduleUri', moduleUri.toString())
        .addIfNotNull('moduleText', moduleText)
        .addIfNotNull('expr', expr);
  }
}

class EvaluateResponse implements ServerResponseMessage {
  @override
  final int requestId;
  final int evaluatorId;
  final Uint8List? result;
  final String? error;

  EvaluateResponse({
    required this.requestId,
    required this.evaluatorId,
    this.result,
    this.error,
  });

  @override
  Map<String, dynamic> propertyMap() {
    return <String, dynamic>{}
        .addIfNotNull('requestId', requestId)
        .addIfNotNull('evaluatorId', evaluatorId)
        .addIfNotNull('result', result)
        .addIfNotNull('error', error);
  }
}

enum LogLevel {
  trace(0),
  warn(1);

  const LogLevel(this.value);

  final int value;
}

class LogMessage implements ServerOneWayMessage {
  final int evaluatorId;
  final LogLevel level;
  final String message;
  final String frameUri;

  LogMessage({
    required this.evaluatorId,
    required this.level,
    required this.message,
    required this.frameUri,
  });

  @override
  int? get requestId => null;

  @override
  Map<String, dynamic> propertyMap() {
    return <String, dynamic>{
      'evaluatorId': evaluatorId,
      'level': level.value,
      'message': message,
      'frameUri': frameUri,
    };
  }
}

class InitializeModuleReaderRequest implements ServerRequestMessage {
  @override
  int requestId;
  final String scheme;

  InitializeModuleReaderRequest({
    required this.requestId,
    required this.scheme,
  });

  @override
  Map<String, dynamic> propertyMap() {
    return {'requestId': requestId, 'scheme': scheme};
  }
}

class InitializeModuleReaderResponse implements ClientResponseMessage {
  @override
  int requestId;
  ModuleReaderMessage? spec;

  InitializeModuleReaderResponse({required this.requestId, this.spec});

  @override
  Map<String, dynamic> propertyMap() {
    return {'requestId': requestId}..addIfNotNull('spec', spec?.propertyMap());
  }
}

class InitializeResourceReaderRequest implements ServerRequestMessage {
  @override
  int requestId;
  final String scheme;

  InitializeResourceReaderRequest({
    required this.requestId,
    required this.scheme,
  });

  @override
  Map<String, dynamic> propertyMap() {
    return {'requestId': requestId, 'scheme': scheme};
  }
}

class InitializeResourceReaderResponse implements ClientResponseMessage {
  @override
  int requestId;
  ResourceReaderMessage? spec;

  InitializeResourceReaderResponse({required this.requestId, this.spec});

  @override
  Map<String, dynamic> propertyMap() {
    return {'requestId': requestId}..addIfNotNull('spec', spec?.propertyMap());
  }
}

class CloseExternalProcess implements ServerOneWayMessage {
  @override
  int? get requestId => null;

  @override
  Map<String, dynamic> propertyMap() => {};
}

class ExternalReader extends Equatable {
  final String executable;
  final List<String>? arguments;

  const ExternalReader({required this.executable, this.arguments});

  factory ExternalReader.fromJson(Map<String, dynamic> json) {
    return ExternalReader(
      executable: json['executable'] as String,
      arguments: json['arguments'] != null
          ? List<String>.from(json['arguments'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'executable': executable, 'arguments': arguments};
  }

  @override
  List<Object?> get props => [executable, arguments];

  Map<String, dynamic> propertiesMap() {
    final map = toJson();
    map.removeWhere((key, value) => value == null);

    return map;
  }
}
