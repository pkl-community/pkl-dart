import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart' as log;

/// An interface for logging messages emitted by the Pkl evaluator
abstract interface class Logger {
  void trace(String message, String frameUri);

  /// Logs the given message on level WARN.
  void warn(String message, String frameUri);

  static final Logger standardOutput = StreamLogger(stdout.nonBlocking);
  static final Logger standardError = StreamLogger(stderr.nonBlocking);
}

/// An implementation of [Logger] that writes to a given stream
class StreamLogger implements Logger {
  final StreamSink sink;
  final log.Logger _logger;

  StreamLogger(this.sink) : _logger = log.Logger('PKL') {
    _logger.level = log.Level.ALL;
    _logger.onRecord.listen((record) {
      // record.object becomes the `frameUri`
      sink.add('${record.loggerName}: ${record.level == log.Level.INFO ? 'TRACE' : record.level}: ${record.message}');
    });
  }

  @override
  void trace(String message, String frameUri) => _logger.info(LogMessage(message, frameUri));

  @override
  void warn(String message, String frameUri) => _logger.warning(LogMessage(message, frameUri));
}

class LogMessage {
  final String message;
  final String frameUri;

  const LogMessage(this.message, this.frameUri);

  @override
  String toString() => '$message ($frameUri)';
}