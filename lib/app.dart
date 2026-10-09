import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:napex_victim_app/core/router/app_router.dart';
import 'package:napex_victim_app/core/theme/app_theme.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';
import 'package:napex_victim_app/presentation/providers/settings_providers.dart';

/// جذر التطبيق — عربي RTL أولاً
class NapexApp extends ConsumerWidget {
  const NapexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(
      settingsProvider.select((s) => s.themeMode),
    );

    // نقر إشعار الابتزاز يفتح قائمة البلاغات
    ref.read(notificationServiceProvider).onNotificationTap = router.go;

    return MaterialApp.router(
      title: 'NAP-EX — منصة مكافحة الابتزاز الإلكتروني',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
