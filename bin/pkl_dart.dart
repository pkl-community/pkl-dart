// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This is an example of converting the args in test.dart to use this API.
/// It shows what it looks like to build an [ArgParser] and then, when the code
/// is run, demonstrates what the generated usage text looks like.
library;

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pkl_dart/src/generator.dart';
import 'package:pkl_dart/src/generator_settings.dart';
import 'package:pkl_dart/src/version.dart';

final parser = ArgParser(allowTrailingOptions: true)
  ..addFlag('version', abbr: 'v', help: "Print the version and exit")
  ..addOption('output',
      abbr: 'o', help: 'The output directory to write generated sources to')
  ..addFlag('dry-run',
      abbr: 'n',
      help: 'Print out info about the run, but do not write to any files')
  ..addFlag('help', abbr: 'h', help: 'Show Help Information')
  ..addOption('project-dir', help: 'The path to the directory containing the PklProject file to load dependency and evaluator settings from')
  ..addOption('generator-settings',
      abbr: 'g',
      help: "The 'generator-settings.pkl' file to use",
      defaultsTo: 'generator-settings.pkl')
  ..addOption('generate-script',
    hide: true,
    help: 'The path to the Generator.pkl file to act as generator script');

void main(List<String> args) async {
  var results = parser.parse(args);

  if (results.wasParsed('version')) {
    print(version);
    return;
  }

  if (results.wasParsed('help')) {
    print(parser.usage);
    return;
  }

  // get args
  final modules = results.rest;
  final generatorSettingsFile = results['generator-settings'] as String?;

  // get generator settings
  final GeneratorSettings settings = await createGeneratorSettings(
    dryRun: results['dry-run'],
    generatorSettingsFile: generatorSettingsFile,
    currentDirectory: p.current,
    outputPath: results['output'],
    projectPath: results['project-dir'],
    files: modules,
    generateScript: results['generate-script']
  );

  // create generator
  final Generator generator = Generator(
    settings: settings, 
    workingDirectory: p.current, 
    verbose: results['verbose'],
  );

  // run generator
  await generator.run();
}
