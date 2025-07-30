// Copyright (c) 2025, the Pkl community authors. Please see the AUTHORS file
// for details. This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:io';
import 'package:logging/logging.dart' as dl;
import 'package:equatable/equatable.dart';

/// Handler to control logging messages emitted by the Pkl evaluator.
///
/// To set a logger, register it on EvaluatorOptions.Logger when building an Evaluator.
abstract class Logger {
  const Logger();

  /// Log the message using level TRACE.
  ///
  ///   - [message]: The message to log
  ///   - [frameUri]: A string representing the location where the log message was emitted.
  void trace({required String message, required String frameUri});

  /// Log the message using level WARN.
  ///
  ///   - [message]: The message to log
  ///   - [frameUri]: A string representing the location where the log message was emitted.
  void warn({required String message, required String frameUri});

  /// The default format for log messages.
  String formatLogMessage({
    required String level,
    required String message,
    required String frameUri,
  }) {
    return 'pkl: $level: $message ($frameUri)';
  }
}

/// A logger that discards log messages.
class NoOpLogger extends Logger {
  const NoOpLogger();

  @override
  void trace({required String message, required String frameUri}) {
    // no-op
  }

  @override
  void warn({required String message, required String frameUri}) {
    // no-op
  }
}

/// A logger that delegates to Dart's standard logging package.
class DartLogger extends Logger with EquatableMixin {
  final dl.Logger _logger;

  const DartLogger(this._logger);

  /// Creates a logger with the specified name.
  factory DartLogger.named(String name) {
    return DartLogger(dl.Logger(name));
  }

  /// Creates the default Pkl logger.
  factory DartLogger.pkl() {
    return DartLogger(dl.Logger('pkl'));
  }

  @override
  void trace({required String message, required String frameUri}) {
    final formattedMessage = formatLogMessage(level: 'TRACE', message: message, frameUri: frameUri);
    _logger.finest(formattedMessage);
  }

  @override
  void warn({required String message, required String frameUri}) {
    final formattedMessage = formatLogMessage(level: 'WARN', message: message, frameUri: frameUri);
    _logger.warning(formattedMessage);
  }

  @override
  List<Object?> get props => [_logger.name];
}

/// A logger that writes messages to the provided [IOSink].
class IOSinkLogger extends Logger with EquatableMixin {
  final IOSink ioSink;

  const IOSinkLogger(this.ioSink);

  @override
  void trace({required String message, required String frameUri}) {
    final formattedMessage = formatLogMessage(level: 'TRACE', message: message, frameUri: frameUri);
    ioSink.writeln(formattedMessage);
  }

  @override
  void warn({required String message, required String frameUri}) {
    final formattedMessage = formatLogMessage(level: 'WARN', message: message, frameUri: frameUri);
    ioSink.writeln(formattedMessage);
  }

  @override
  List<Object?> get props => [ioSink];
}

/// Predefined logger instances for common use cases.
// TODO: We can just have these as static properties on [Logger]
class Loggers {
  /// A logger that writes everything to stdout using Dart's logging package.
  static Logger get standardOutput {
    final logger = DartLogger.pkl();
    // Configure to write to stdout
    dl.Logger.root.onRecord.listen((record) {
      stdout.writeln('${record.level.name}: ${record.message}');
    });

    return logger;
  }

  /// A logger that writes everything to stderr using Dart's logging package.
  static Logger get standardError {
    final logger = DartLogger.pkl();
    // Configure to write to stderr
    dl.Logger.root.onRecord.listen((record) {
      stderr.writeln('${record.level.name}: ${record.message}');
    });
    return logger;
  }

  /// A logger that writes everything to stdout using IOSink directly.
  static Logger get simpleStandardOutput => IOSinkLogger(stdout);

  /// A logger that writes everything to stderr using IOSink directly.
  static Logger get simpleStandardError => IOSinkLogger(stderr);

  /// A logger that discards log messages.
  static const Logger noop = NoOpLogger();

  /// Private constructor to prevent instantiation.
  Loggers._();
}

/// Extension to configure logging easily.
extension LoggingConfiguration on dl.Logger {
  /// Sets up console logging with a custom format.
  static void setupConsoleLogging({dl.Level level = dl.Level.INFO}) {
    dl.Logger.root.level = level;
    dl.Logger.root.onRecord.listen((record) {
      final message =
          '${record.time}: ${record.level.name}: ${record.loggerName}: ${record.message}';
      if (record.level >= dl.Level.SEVERE) {
        stderr.writeln(message);
      } else {
        stdout.writeln(message);
      }
      if (record.error != null) {
        stderr.writeln('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        stderr.writeln('Stack trace:\n${record.stackTrace}');
      }
    });
  }
}
