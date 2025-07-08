// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

class PklError implements Exception {
  final String message;

  PklError(this.message);

  @override
  String toString() => 'PklError: $message';
}

class PklBugError implements Exception {
  final String message;

  PklBugError.invalidMessageCode(this.message);

  PklBugError.invalidEvaluatorId(this.message);

  PklBugError.unknownMessage(this.message); // Added for completeness
  @override
  String toString() => 'PklBugError: $message';
}
