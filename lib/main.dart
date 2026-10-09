import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:napex_victim_app/app.dart';
import 'package:napex_victim_app/core/constants/app_constants.dart';
import 'package:napex_victim_app/core/constants/security_constants.dart';
import 'package:napex_victim_app/core/security/secure_storage.dart';
import 'package:napex_victim_app/core/storage/local_storage.dart';
import 'package:napex_victim_app/core/utils/logger.dart';
import 'package:napex_victim_app/data/datasources/local/app_database.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';

Future<void> main() async {
  // ============ تهيئة الربط ============
  WidgetsFlutterBinding.ensureInitialized();

  // التقاط الأخطاء غير المتوقعة
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error(
      details.exceptionAsString(),
      tag: 'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error(
      'Uncaught platform error',
      tag: 'Platform',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  // ============ تهيئة البنية التحتية ============
  final prefs = await SharedPreferences.getInstance();
  final localStorage = LocalStorage(prefs);
  final database = await AppDatabase.getInstance();

  // فحص المصادقة المبدئي (توكن حقيقي أو وضع تجريبي)
  final onboardingCompleted =
      localStorage.getBool(AppConstants.keyOnboardingCompleted);
  var initialAuthenticated = false;
  if (onboardingCompleted) {
    final demoMode = localStorage.getBool(AppConstants.keyOfflineDemoMode);
    final token = await SecureStorage(const FlutterSecureStorage())
        .readString(SecurityConstants.keyAccessToken);
    initialAuthenticated = demoMode || (token != null && token.isNotEmpty);
  }

  AppLogger.info('Bootstrapping NAP-EX victim app…', tag: 'Boot');

  // ============ التشغيل ============
  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(localStorage),
        appDatabaseProvider.overrideWithValue(database),
        initialAuthenticatedProvider.overrideWithValue(initialAuthenticated),
      ],
      child: const NapexApp(),
    ),
  );
}
