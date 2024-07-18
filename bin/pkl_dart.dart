// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This is an example of converting the args in test.dart to use this API.
/// It shows what it looks like to build an [ArgParser] and then, when the code
/// is run, demonstrates what the generated usage text looks like.
library;

import 'dart:io';

import 'package:args/args.dart';

final parser = ArgParser(allowTrailingOptions: true)
  ..addFlag('version', abbr: 'v', help: "Print the version and exit")
  ..addOption('output', abbr: 'o', help: 'The output directory to write generated sources to')
  ..addFlag('dry-run', abbr: 'n', help: 'Print out info about the run, but do not write to any files')
  ..addOption('generator-settings', abbr: 'g', help: "The 'generator-settings.pkl' file to use", defaultsTo: 'generator-settings.pkl');

void main(List<String> args) {
  var results = parser.parse(args);
  if (results.wasParsed('version')) {

  }
}