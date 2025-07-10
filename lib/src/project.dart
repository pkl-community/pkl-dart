// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'package:equatable/equatable.dart';
import 'evaluation/pkl_evaluator_settings.dart';
import 'message.dart';

/// The Dart representation of `pkl.Project`
class Project extends Equatable implements DependencyDeclaredInProjectFile {
  final Package? package;
  final PklEvaluatorSettings evaluatorSettings;
  final String projectFileUri;
  final List<String> tests;
  final Checksums? checksums;
  final Map<String, DependencyDeclaredInProjectFile> dependencies;

  const Project({
    this.package,
    required this.evaluatorSettings,
    required this.projectFileUri,
    required this.tests,
    required this.dependencies,
    this.checksums,
  });

  @override
  List<Object?> get props => [
    package,
    evaluatorSettings,
    projectFileUri,
    tests,
    dependencies,
  ];

  @override
  bool? get stringify => true;

  @override
  Map<String, dynamic> toJson() {
    return {
      'package': package?.toJson(),
      'evaluatorSettings': evaluatorSettings.toJson(),
      'projectFileUri': projectFileUri,
      'tests': tests,
      'dependencies': dependencies.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  factory Project.fromJson(Map<String, dynamic> map) {
    final rawDepsMap = map['dependencies'] as Map<dynamic, dynamic>?;
    final Map<String, dynamic>? depsMap = rawDepsMap?.cast();
    final Map<String, DependencyDeclaredInProjectFile> dependencies = {};
    if (depsMap != null) {
      depsMap.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          // A remote dependency is identified by having a 'uri' key.
          if (value.containsKey('uri')) {
            dependencies[key] = RemoteDependency.fromJson(value);
          } else {
            dependencies[key] = Project.fromJson(value);
          }
        }
      });
    }
    final hasSettings = map.containsKey('evaluatorSettings');
    final hasPackage = map.containsKey('package');
    final hasProjectUri = map.containsKey('projectFileUri');
    final hasTests = map.containsKey('tests');

    return Project(
      package: hasPackage
          ? Package.fromJson(map['package'] as Map<String, dynamic>)
          : null,
      evaluatorSettings: hasSettings
          ? PklEvaluatorSettings.fromJson(
              map['evaluatorSettings'] as Map<String, dynamic>,
            )
          : const PklEvaluatorSettings(),
      projectFileUri: hasProjectUri ? map['projectFileUri'] as String : '',
      tests: hasTests ? List<String>.from(map['tests']) : [],
      dependencies: dependencies,
    );
  }

  /// Convert to [ProjectOrDependency]
  @override
  ProjectOrDependency toProjectOrDependency() {
    return ProjectOrDependency(
      packageUri: package?.uri,
      type: 'local',
      projectFileUri: projectFileUri,
      checksums: checksums,
      dependencies: dependencies.map(
        (k, v) => MapEntry(k, v.toProjectOrDependency()),
      ),
    );
  }
}

/// Base interface for dependencies declared in project files
abstract class DependencyDeclaredInProjectFile extends Equatable {
  Map<String, dynamic> toJson();

  DependencyDeclaredInProjectFile.fromJson(Map<String, dynamic> json);

  /// Convert to [ProjectOrDependency]
  ProjectOrDependency toProjectOrDependency();

  @override
  bool? get stringify => true;
}

/// The Dart representation of `pkl.Project#RemoteDependency`
class RemoteDependency extends Equatable
    implements DependencyDeclaredInProjectFile {
  final String uri;
  final Checksums? checksums;

  const RemoteDependency({required this.uri, this.checksums});

  factory RemoteDependency.fromJson(Map<String, dynamic> json) {
    return RemoteDependency(
      uri: json['uri'] as String,
      checksums: json['checksums'] != null
          ? Checksums.fromJson(json['checksums'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {'uri': uri, 'checksums': checksums?.toJson()};
  }

  @override
  List<Object?> get props => [uri, checksums];

  @override
  ProjectOrDependency toProjectOrDependency() {
    return ProjectOrDependency(
      packageUri: uri,
      type: 'remote',
      checksums: checksums,
      dependencies: null,
    );
  }
}

/// The Dart representation of `pkl.Project#Package`
class Package extends Equatable {
  final String name;
  final String baseUri;
  final String version;
  final String packageZipUrl;
  final String? description;
  final List<String> authors;
  final String? website;
  final String? documentation;
  final String? sourceCode;
  final String? sourceCodeUrlScheme;
  final String? license;
  final String? licenseText;
  final String? issueTracker;
  final List<String> apiTests;
  final List<String> exclude;
  final String uri;

  const Package({
    required this.name,
    required this.baseUri,
    required this.version,
    required this.packageZipUrl,
    this.description,
    required this.authors,
    this.website,
    this.documentation,
    this.sourceCode,
    this.sourceCodeUrlScheme,
    this.license,
    this.licenseText,
    this.issueTracker,
    required this.apiTests,
    required this.exclude,
    required this.uri,
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      name: json['name'] as String,
      baseUri: json['baseUri'] as String,
      version: json['version'] as String,
      packageZipUrl: json['packageZipUrl'] as String,
      description: json['description'] as String?,
      authors: List<String>.from(json['authors'] ?? []),
      website: json['website'] as String?,
      documentation: json['documentation'] as String?,
      sourceCode: json['sourceCode'] as String?,
      sourceCodeUrlScheme: json['sourceCodeUrlScheme'] as String?,
      license: json['license'] as String?,
      licenseText: json['licenseText'] as String?,
      issueTracker: json['issueTracker'] as String?,
      apiTests: List<String>.from(json['apiTests'] ?? []),
      exclude: List<String>.from(json['exclude'] ?? []),
      uri: json['uri'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'baseUri': baseUri,
      'version': version,
      'packageZipUrl': packageZipUrl,
      'description': description,
      'authors': authors,
      'website': website,
      'documentation': documentation,
      'sourceCode': sourceCode,
      'sourceCodeUrlScheme': sourceCodeUrlScheme,
      'license': license,
      'licenseText': licenseText,
      'issueTracker': issueTracker,
      'apiTests': apiTests,
      'exclude': exclude,
      'uri': uri,
    };
  }

  @override
  List<Object?> get props => [
    name,
    baseUri,
    version,
    packageZipUrl,
    description,
    authors,
    website,
    documentation,
    sourceCode,
    sourceCodeUrlScheme,
    license,
    licenseText,
    issueTracker,
    apiTests,
    exclude,
    uri,
  ];

  @override
  bool? get stringify => true;
}
