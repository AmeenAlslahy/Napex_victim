import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:napex_victim_app/presentation/features/dashboard/screens/dashboard_screen.dart';
import 'package:napex_victim_app/presentation/features/education/screens/education_screen.dart';
import 'package:napex_victim_app/presentation/features/education/screens/quiz_screen.dart';
import 'package:napex_victim_app/presentation/features/notifications/screens/victim_notifications_screen.dart';
import 'package:napex_victim_app/presentation/features/onboarding/screens/otp_screen.dart';
import 'package:napex_victim_app/presentation/features/onboarding/screens/permissions_screen.dart';
import 'package:napex_victim_app/presentation/features/onboarding/screens/registration_screen.dart';
import 'package:napex_victim_app/presentation/features/onboarding/screens/splash_screen.dart';
import 'package:napex_victim_app/presentation/features/onboarding/screens/welcome_screen.dart';
import 'package:napex_victim_app/presentation/features/reports/screens/analytics_screen.dart';
import 'package:napex_victim_app/presentation/features/reports/screens/report_detail_screen.dart';
import 'package:napex_victim_app/presentation/features/reports/screens/reports_list_screen.dart';
import 'package:napex_victim_app/presentation/features/settings/screens/activity_screen.dart';
import 'package:napex_victim_app/presentation/features/settings/screens/personal_blocklist_screen.dart';
import 'package:napex_victim_app/presentation/features/settings/screens/settings_screen.dart';
import 'package:napex_victim_app/presentation/features/support/screens/support_screen.dart';
import 'package:napex_victim_app/presentation/features/support/screens/trusted_contacts_screen.dart';
import 'package:napex_victim_app/presentation/features/shell/main_shell.dart';
import 'package:napex_victim_app/presentation/providers/flow_providers.dart';

/// مفتاح التنقل الجذري — يُستخدم لفتح مسارات من خارج الويدجات (مثل الإشعارات)
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// موجّه التطبيق — يُعيد التوجيه تلقائياً حسب حالة التدفق
/// (Splash → Onboarding → التسجيل → التطبيق الرئيسي)
final appRouterProvider = Provider<GoRouter>((ref) {
  // إعادة تقييم التوجيه عند أي تغيير في حالة التدفق
  final refreshNotifier = ValueNotifier<int>(0);
  ref.listen<FlowState>(flowProvider, (previous, next) {
    refreshNotifier.value++;
  });
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final flow = ref.read(flowProvider);
      final location = state.matchedLocation;

      // 1. انتظار استعادة الجلسة
      if (!flow.restored) {
        return location == '/splash' ? null : '/splash';
      }

      final isOnboarding = location.startsWith('/onboarding');

      // 2. لم يكمل الاستعراض الأول → شاشة الترحيب
      if (!flow.onboardingCompleted) {
        return isOnboarding ? null : '/onboarding/welcome';
      }

      // 3. لم يسجّل الدخول → شاشة التسجيل
      if (!flow.authenticated) {
        return isOnboarding ? null : '/onboarding/register';
      }

      // 4. مسجّل الدخول → التطبيق الرئيسي (إلا لو داخل قسم شرعي)
      if (location == '/' ||
          location == '/splash' ||
          location == '/onboarding') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding/permissions',
        builder: (context, state) => const PermissionsScreen(),
      ),
      GoRoute(
        path: '/onboarding/register',
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: '/onboarding/otp',
        builder: (context, state) => const OtpScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const VictimNotificationsScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/trusted-contacts',
        builder: (context, state) => const TrustedContactsScreen(),
      ),
      GoRoute(
        path: '/personal-blocklist',
        builder: (context, state) => const PersonalBlocklistScreen(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/activity',
        builder: (context, state) => const ActivityScreen(),
      ),
      GoRoute(
        path: '/quiz',
        builder: (context, state) => const QuizScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          // ============ الحماية ============
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          // ============ البلاغات ============
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsListScreen(),
                routes: [
                  GoRoute(
                    path: 'detail/:id',
                    builder: (context, state) => ReportDetailScreen(
                      reportId: state.pathParameters['id'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          // ============ التثقيف ============
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/education',
                builder: (context, state) => const EducationScreen(),
              ),
            ],
          ),
          // ============ الإعدادات ============
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
