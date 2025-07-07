import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;
import 'manager_utils.dart';
import '../project.dart';
import '../reader.dart';
import 'logger.dart';
import 'pkl_error.dart';
import 'pkl_evaluator_settings.dart';
import 'package:pkl_dart/src/message.dart';

/// Options for configuring a Pkl evaluator.
class EvaluatorOptions extends Equatable {
  /// Regular expression patterns that control what modules are allowed to be imported in a Pkl program.
  final List<String>? allowedModules;

  /// Regular expression patterns that control what resources are allowed to be read in a Pkl program.
  final List<String>? allowedResources;

  /// Readers that allow importing custom modules in Pkl.
  final List<ResourceReader>? resourceReaders;

  /// Readers that allow reading custom resources in Pkl.
  final List<ModuleReader>? moduleReaders;

  /// The set of zip files, or directories, that get passed to the `modulepath:` scheme.
  final List<String>? modulePaths;

  /// The set of environment variables that can be read using the `env:` scheme.
  final Map<String, String>? env;

  /// The set of properties that can be read using the `prop:` scheme.
  final Map<String, String>? properties;

  /// The evaluation timeout.
  final Duration? timeout;

  /// The root directory for file-based imports and reads.
  /// If set, forbids reading/importing past the specified directory.
  final String? rootDir;

  /// The directory in which `package:` modules are cached.
  final String? cacheDir;

  /// The value of the `pkl.outputFormat` flag.
  /// Equivalent to the `-f` flag in the CLI.
  final String? outputFormat;

  /// The logger interface to write trace and warn messages.
  final Logger? logger;

  /// The project directory for the evaluator.
  ///
  /// Setting this determines how Pkl resolves dependency notation imports.
  /// It causes Pkl to look for the resolved dependencies relative to this directory,
  /// and load resolved dependencies from a PklProject.deps.json file inside this directory.
  ///
  /// NOTE:
  /// Setting this option is not equivalent to setting the `--project-dir` flag from the CLI.
  /// When the `--project-dir` flag is set, the CLI will evaluate the PklProject file,
  /// and then applies any evaluator settings and dependencies set in the PklProject file
  /// for the main evaluation.
  ///
  /// In contrast, this option only determines how Pkl considers whether files are part of a
  /// project.
  /// It is meant to be set by lower level logic in Swift code that first evaluates the PklProject,
  /// which then configures `EvaluatorOptions` accordingly.
  ///
  /// To emulate the CLI's `--project-dir` flag, create an evaluator with `withProjectEvaluator(projectBaseUri:action:)`,
  /// or `EvaluatorManager.newProjectEvaluator()`.
  final Uri? projectBaseUri;

  /// Settings that control how Pkl talks to HTTP(S) servers.
  /// Added in Pkl 0.26.
  /// These fields are ignored if targeting Pkl 0.25.
  final Http? http;

  /// The set of dependencies available to modules within `projectBaseUri`.
  ///
  /// When importing dependencies, a `PklProject.deps.json` file must exist within `projectBaseUri`
  /// that contains the project's resolved dependencies.
  final Map<String, ProjectOrDependency>? declaredProjectDependencies;

  /// Registered external commands that implement module reader schemes.
  /// Added in Pkl 0.27.
  /// If the underlying Pkl does not support external readers, evaluation will fail when a registered scheme is used.
  final Map<String, ExternalReader>? externalModuleReaders;

  /// Registered external commands that implement resource reader schemes.
  /// Added in Pkl 0.27.
  /// If the underlying Pkl does not support external readers, evaluation will fail when a registered scheme is used.
  final Map<String, ExternalReader>? externalResourceReaders;

  const EvaluatorOptions({
    this.allowedModules,
    this.allowedResources,
    this.resourceReaders,
    this.moduleReaders,
    this.modulePaths,
    this.env,
    this.properties,
    this.timeout,
    this.rootDir,
    this.cacheDir,
    this.outputFormat,
    this.logger,
    this.projectBaseUri,
    this.http,
    this.declaredProjectDependencies,
    this.externalModuleReaders,
    this.externalResourceReaders,
  });

  @override
  List<Object?> get props => [
    allowedModules,
    allowedResources,
    resourceReaders,
    moduleReaders,
    modulePaths,
    env,
    properties,
    timeout,
    rootDir,
    cacheDir,
    outputFormat,
    logger,
    projectBaseUri,
    http,
    declaredProjectDependencies,
    externalModuleReaders,
    externalResourceReaders,
  ];

  static const List<String> defaultAllowedModules = [
    "pkl:",
    "repl:",
    "file:",
    "http:",
    "https:",
    "modulepath:",
    "package:",
    "projectpackage:",
  ];

  static const List<String> defaultAllowedResources = [
    "http:",
    "https:",
    "file:",
    "env:",
    "prop:",
    "modulepath:",
    "package:",
    "projectpackage:",
  ];

  static Future<String> get _defaultCacheDir async {
    final appSupportDir = getHomeDir();
    return p.join(appSupportDir, ".pkl", "cache");
  }

  /// A sensible default set of options for the evaluator.
  static Future<EvaluatorOptions> get preconfigured async {
    return EvaluatorOptions(
      allowedModules: defaultAllowedModules,
      allowedResources: defaultAllowedResources,
      env: Platform.environment,
      cacheDir: await _defaultCacheDir,
      logger: Loggers.standardOutput,
    );
  }

  /// An empty set of evaluator options.
  static const EvaluatorOptions empty = EvaluatorOptions();

  /// Converts these options into a `CreateEvaluatorRequest` message.
  ///
  /// `clientResourceReaders` and `clientModuleReaders` are provided by the `EvaluatorManager`
  /// as it assigns IDs to the readers.
  CreateEvaluatorRequest toCreateEvaluatorRequest({
    required List<ResourceReaderMessage> clientResourceReaders,
    required List<ModuleReaderMessage> clientModuleReaders,
  }) {
    return CreateEvaluatorRequest(
      requestId: 0,
      // This will be set by the manager
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
      project: toProjectOrDependency(),
      http: http,
      externalModuleReaders: externalModuleReaders,
      externalResourceReaders: externalResourceReaders,
    );
  }

  /// Converts the `projectBaseUri` and `declaredProjectDependencies` into a `ProjectOrDependency` message.
  ProjectOrDependency? toProjectOrDependency() {
    if (projectBaseUri == null) {
      return null;
    }
    return ProjectOrDependency(
      packageUri: null,
      type: "project",
      projectFileUri: p.join(projectBaseUri!.path, "PklProject"),
      checksums: null,
      dependencies: declaredProjectDependencies,
    );
  }

  /// Builds options that registers the provided module reader, and allowance to import modules starting with its scheme.
  EvaluatorOptions withModuleReader(ModuleReader reader) {
    return copyWith(
      allowedModules: [...?allowedModules, reader.scheme],
      moduleReaders: [...?moduleReaders, reader],
    );
  }

  /// Builds options that registers the provided resource reader, and allowance to read resources starting with its scheme.
  EvaluatorOptions withResourceReader(ResourceReader reader) {
    return copyWith(
      allowedResources: [...?allowedResources, reader.scheme],
      resourceReaders: [...?resourceReaders, reader],
    );
  }

  /// Builds options that configures the evaluator with settings set on the project.
  /// Skips any settings that are nil.
  EvaluatorOptions withProjectEvaluatorSettings(PklEvaluatorSettings evaluatorSettings) {
    return copyWith(
      properties: evaluatorSettings.externalProperties ?? properties,
      env: evaluatorSettings.env ?? env,
      allowedModules: evaluatorSettings.allowedModules ?? allowedModules,
      allowedResources: evaluatorSettings.allowedResources ?? allowedResources,
      cacheDir: evaluatorSettings.noCache != true
          ? (evaluatorSettings.moduleCacheDir ?? cacheDir)
          : null,
      rootDir: evaluatorSettings.rootDir ?? rootDir,
      http: evaluatorSettings.http ?? http,
      externalModuleReaders: evaluatorSettings.externalModuleReaders ?? externalModuleReaders,
      externalResourceReaders: evaluatorSettings.externalResourceReaders ?? externalResourceReaders,
    );
  }

  /// Private helper to convert `Project` dependencies into `ProjectOrDependency` map.
  Map<String, ProjectOrDependency> _projectDependencies(Project project) {
    final Map<String, ProjectOrDependency> result = {};
    for (final entry in project.dependencies.entries) {
      final k = entry.key;
      final v = entry.value;
      if (v is Project) {
        result[k] = ProjectOrDependency(
          packageUri: v.package!.uri,
          type: "local",
          projectFileUri: v.projectFileUri,
          dependencies: _projectDependencies(v),
        );
      } else if (v is RemoteDependency) {
        result[k] = ProjectOrDependency(type: "remote", packageUri: v.uri, checksums: v.checksums);
      } else {
        throw PklBugError.invalidMessageCode("Unknown project dependency type: ${v.runtimeType}");
      }
    }
    return result;
  }

  /// Builds options with dependencies from the input project.
  EvaluatorOptions withProjectDependencies(Project project) {
    // Swift uses URL(string: project.projectFileUri)! and then deleteLastPathComponent()
    // Dart's Uri.parse handles this.
    final projectBase = Uri.parse(project.projectFileUri).resolve('.'); // Get parent directory URI

    return copyWith(
      projectBaseUri: projectBase,
      declaredProjectDependencies: _projectDependencies(project),
    );
  }

  /// Builds options with evaluator settings as well as dependencies from the input project.
  EvaluatorOptions withProject(Project project) {
    return withProjectEvaluatorSettings(project.evaluatorSettings).withProjectDependencies(project);
  }

  /// Creates a new `EvaluatorOptions` instance with specified properties replaced.
  EvaluatorOptions copyWith({
    List<String>? allowedModules,
    List<String>? allowedResources,
    List<ResourceReader>? resourceReaders,
    List<ModuleReader>? moduleReaders,
    List<String>? modulePaths,
    Map<String, String>? env,
    Map<String, String>? properties,
    Duration? timeout,
    String? rootDir,
    String? cacheDir,
    String? outputFormat,
    Logger? logger,
    Uri? projectBaseUri,
    Http? http,
    Map<String, ProjectOrDependency>? declaredProjectDependencies,
    Map<String, ExternalReader>? externalModuleReaders,
    Map<String, ExternalReader>? externalResourceReaders,
  }) {
    return EvaluatorOptions(
      allowedModules: allowedModules ?? this.allowedModules,
      allowedResources: allowedResources ?? this.allowedResources,
      resourceReaders: resourceReaders ?? this.resourceReaders,
      moduleReaders: moduleReaders ?? this.moduleReaders,
      modulePaths: modulePaths ?? this.modulePaths,
      env: env ?? this.env,
      properties: properties ?? this.properties,
      timeout: timeout ?? this.timeout,
      rootDir: rootDir ?? this.rootDir,
      cacheDir: cacheDir ?? this.cacheDir,
      outputFormat: outputFormat ?? this.outputFormat,
      logger: logger ?? this.logger,
      projectBaseUri: projectBaseUri ?? this.projectBaseUri,
      http: http ?? this.http,
      declaredProjectDependencies: declaredProjectDependencies ?? this.declaredProjectDependencies,
      externalModuleReaders: externalModuleReaders ?? this.externalModuleReaders,
      externalResourceReaders: externalResourceReaders ?? this.externalResourceReaders,
    );
  }
}
