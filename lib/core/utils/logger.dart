import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// مستويات التسجيل
enum LogLevel { debug, info, warning, error }

/// مسجّل مركزي للتطبيق — يستخدم dart:developer ليظهر في DevTools
abstract final class AppLogger {
  static void debug(String message, {String tag = 'APP'}) =>
      _log(LogLevel.debug, tag, message);

  static void info(String message, {String tag = 'APP'}) =>
      _log(LogLevel.info, tag, message);

  static void warning(String message, {String tag = 'APP'}) =>
      _log(LogLevel.warning, tag, message);

  static void error(String message, {String tag = 'APP', Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, tag, message, error: error, stackTrace: stackTrace);

  static void _log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kReleaseMode && level != LogLevel.error) return;

    developer.log(
      '[$tag] $message',
      name: 'NAP-EX',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: stackTrace,
    );
  }
}
