import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

class GeneratorSettings {
  List<String> files;

  bool? dryRun;

  String? outputPath;
  String? projectDir;

  GeneratorSettings({this.files = const [], this.dryRun, this.outputPath, this.projectDir});

  GeneratorSettings.empty() : files = const <String>[];
}

GeneratorSettings getGeneratorSettingsFromFile(String file, {
  String? projectDir
}) {
  throw UnimplementedError();
}

Future<GeneratorSettings> createGeneratorSettings(
    {bool dryRun = false,
    String? generatorSettingsFile,
    String? currentDirectory,
    String? outputPath,
    String? projectPath,
    List<String> files = const [],
    FileSystem? fileSystem}) async {
  fileSystem ??= LocalFileSystem();

  GeneratorSettings baseSettings = generatorSettingsFile != null
      ? getGeneratorSettingsFromFile(generatorSettingsFile)
      : GeneratorSettings.empty();
  
  if (files.isNotEmpty) {
    baseSettings.files = files
        .expand((file) => Glob(file, recursive: true)
            .listFileSystemSync(fileSystem!, root: currentDirectory)
            .map((fs) => fs.path))
        .toList();
  }

  if (dryRun) baseSettings.dryRun = true;
  if (outputPath case final out?) baseSettings.outputPath = out;
  if (projectPath case final project?) { 
    baseSettings.projectDir = project; 
  } else if (await findProjectDir(projectPath, fileSystem: fileSystem) case final project?) {
    baseSettings.projectDir = project;
  }
  
  return baseSettings;
}

Future<String?> findProjectDir(String? projectDirFlag, {FileSystem? fileSystem}) async {
  if (projectDirFlag != null) return projectDirFlag;

  fileSystem ??= LocalFileSystem();

  await for (final file in fileSystem.directory(p.current).list(recursive: true)) {
    if (file is File) {
      if (p.basenameWithoutExtension(file.path) == 'Pklproject') return file.parent.path;
    } 
  }

  return null;
}