


import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:pkl_dart/src/generator.dart';
import 'package:pkl_dart/src/generator_settings.dart';
import 'package:test/test.dart';

void main() {
  group('Integration Test', () {
    final projectDir = p.join('test', 'integration', 'pkl');
    final FileSystem fileSystem = LocalFileSystem();

    for (final file in fileSystem.directory(projectDir).listSync()) {
      final fileName = p.basenameWithoutExtension(file.path);
      if (fileName.endsWith('_input') && p.extension(file.path) == '.pkl') {
        final testName = fileName.replaceFirst('_input', '');
        final expectedFile = '${testName}_expected.dart';

        test(testName, () async {
          // run generator
          await generatePklGenCode(
            fileSystem: fileSystem, 
            file: file.path, 
            inputDir: projectDir
          );

          // check for generated file
          final outputFile = p.join(projectDir, '_temp', '${testName}_input.pkl.dart');
          final outputFileContents = await fileSystem.file(outputFile).readAsString();
          final expectedFileContents = await fileSystem.file(p.join(projectDir, expectedFile)).readAsString();

          expect(outputFileContents, equals(expectedFileContents));
        });
      }
    }
  });
}

Future<void> generatePklGenCode({
  required FileSystem fileSystem,
  required String file,
  required String inputDir
}) async {
  final GeneratorSettings settings = await createGeneratorSettings(
    currentDirectory: p.current,
    outputPath: p.join(inputDir, '_temp'),
    projectPath: inputDir,
    files: [file],
    fileSystem: fileSystem,
  );

  // create generator
  final Generator generator = Generator(
    settings: settings, 
    workingDirectory: p.current,     
  );

  // run generator
  await generator.run();
}