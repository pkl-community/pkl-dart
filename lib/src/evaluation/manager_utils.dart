// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:io';
import 'package:logging/logging.dart';
import 'package:pkl_dart/src/evaluation/pkl_error.dart';
import 'package:pub_semver/pub_semver.dart';

// Platform-specific constants
final String _pklExecName = Platform.isWindows ? 'pkl.exe' : 'pkl';

/// Gets an environment variable, handling case-insensitivity on Windows.
/// Returns null if the variable is not found.
String? getEnv(String key) {
  if (Platform.isWindows) {
    final lowercasedKey = key.toLowerCase();
    for (final entry in Platform.environment.entries) {
      if (entry.key.toLowerCase() == lowercasedKey) {
        return entry.value;
      }
    }

    return null;
  } else {
    return Platform.environment[key];
  }
}

/// Finds the full path of an executable [command] by searching the system's PATH.
///
/// Returns the full path as a [String] if found, otherwise returns `null`.
/// This uses the `where` command on Windows and `which` on macOS/Linux.
Future<String?> findOnPath(String command) async {
  try {
    final result = await Process.run(Platform.isWindows ? 'where' : 'which', [command]);

    if (result.exitCode == 0) {
      // `where` on Windows can return multiple paths on separate lines.
      // `which` on Unix-like systems typically returns a single path.
      // We take the first valid line from stdout.
      return (result.stdout as String).split(Platform.lineTerminator).first.trim();
    }
  } catch (e) {
    // This can happen if 'where' or 'which' are not available, though highly unlikely.
    log('Could not execute "where" or "which" to find command: $command. Error: $e');
  }

  return null;
}

/// Resolves the (CLI) command to invoke Pkl.
///
/// First, checks the `PKL_EXEC` environment variable. If that is not set,
/// searches the `PATH` for a directory containing `pkl`.
Future<List<String>> getPklCommand() async {
  final pklExec = getEnv('PKL_EXEC');
  if (pklExec != null && pklExec.isNotEmpty) {
    return pklExec.split(' ');
  }

  final pklPath = await findOnPath(_pklExecName);
  if (pklPath != null) {
    return [pklPath];
  }

  throw PklError(
    'Unable to find `$_pklExecName` on PATH. Please ensure Pkl is installed and its location is in the PATH environment variable, or set the PKL_EXEC environment variable.',
  );
}

/// Gets the semantic version as a String of the Pkl interpreter being used.
Future<String> getPklVersion() async {
  final pklCommand = await getPklCommand();
  final result = await Process.run(pklCommand[0], pklCommand.skip(1).toList()..add('--version'));

  if (result.exitCode != 0) {
    throw PklError('Failed to get Pkl version: ${result.stderr}');
  }

  final output = result.stdout.toString().trim();
  final parts = output.split(' ');

  if (parts.length < 2 || parts[0] != 'Pkl') {
    throw PklError('Could not parse Pkl version from output: $output');
  }

  return parts[1];
}

final pklVersion0_25 = Version.parse('0.25.0');
final pklVersion0_26 = Version.parse('0.26.0');
final pklVersion0_27 = Version.parse('0.27.0');
final pklVersion0_28 = Version.parse('0.28.0');

final List<Version> supportedPklVersions = [
  pklVersion0_25,
  pklVersion0_26,
  pklVersion0_27,
  pklVersion0_28,
];

void log(String message) {
  final log = Logger("PklManager");
  log.info(message);
}

/// Gets the current home directory of the current user.
String getHomeDir() {
  String? home;
  if (Platform.isWindows) {
    home = getEnv('USERPROFILE');
  } else {
    home = getEnv('HOME');
  }

  if (home == null || home.isEmpty) {
    throw PklError(
      'Could not determine home directory. Please ensure that either the HOME (Linux/macOS) or USERPROFILE (Windows) environment variable is set.',
    );
  }

  return home;
}
