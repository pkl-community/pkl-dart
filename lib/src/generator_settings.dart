import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

class GeneratorSettings {
  List<String> files;

  bool? dryRun;

  String? outputPath;
  String? projectDir;
  String? generateScript;

  GeneratorSettings(
      {this.files = const [],
      this.dryRun,
      this.outputPath,
      this.projectDir,
      this.generateScript});

  GeneratorSettings.empty() : files = const <String>[];
}

String _generateScriptUrl() {
  throw UnimplementedError("TODO: Implement _generateScriptUrl");
}

GeneratorSettings getGeneratorSettingsFromFile(String file,
    {String? projectDir}) {
  throw UnimplementedError();
}

// TODO: Would be nice to use package:file to test this with other file systems other than
//  just bare dart:io
Future<GeneratorSettings> createGeneratorSettings(
    {bool dryRun = false,
    String? generatorSettingsFile,
    String? currentDirectory,
    String? outputPath,
    String? projectPath,
    String? generateScript,
    List<String> files = const []}) async {

  GeneratorSettings baseSettings = generatorSettingsFile != null
      ? getGeneratorSettingsFromFile(generatorSettingsFile)
      : GeneratorSettings.empty();

  if (files.isNotEmpty) {
    baseSettings.files = files
        .expand((file) => Glob(file, recursive: true)
            .listSync(root: currentDirectory)
            .map((fs) => fs.path))
        .toList();
  }

  if (dryRun) baseSettings.dryRun = true;
  if (outputPath case final out?) baseSettings.outputPath = out;
  baseSettings.generateScript = generateScript ?? _generateScriptUrl();
  if (projectPath ?? await findProjectDir(projectPath)
      case final project?) {
    baseSettings.projectDir = project;
  }

  return baseSettings;
}

Future<String?> findProjectDir(String? projectDirFlag) async {
  if (projectDirFlag != null) return projectDirFlag;

  await for (final file
      in Directory(p.current).list(recursive: true)) {
    if (file is File) {
      if (p.basenameWithoutExtension(file.path) == 'Pklproject') {
        return file.parent.path;
      }
    }
  }

  return null;
}
