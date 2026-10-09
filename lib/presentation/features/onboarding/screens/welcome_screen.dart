import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:napex_victim_app/presentation/shared/widgets/entrance.dart';

/// شاشة الترحيب — تصميم حديث بخلفية متدرجة ودخول متحرك
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _gradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF0D3B66), Color(0xFF092A4A), Color(0xFF061C31)],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ============ الشعار ============
                Entrance(
                  child: Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E5A96), Color(0xFF0D3B66)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B998B).withValues(alpha: 0.35),
                          blurRadius: 48,
                          spreadRadius: 4,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Entrance(
                  delay: const Duration(milliseconds: 150),
                  child: Text(
                    'NAP-EX',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Entrance(
                  delay: const Duration(milliseconds: 250),
                  child: Text(
                    'منصة مكافحة الابتزاز الإلكتروني',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ============ المزايا ============
                Entrance(
                  delay: const Duration(milliseconds: 400),
                  child: _featureCard(
                    Icons.radar_outlined,
                    'كشف فوري للابتزاز',
                    'محلل ذكي يدعم العربية يرصد رسائل التهديد تلقائياً',
                  ),
                ),
                const SizedBox(height: 12),
                Entrance(
                  delay: const Duration(milliseconds: 520),
                  child: _featureCard(
                    Icons.lock_outlined,
                    'أدلة مشفرة على جهازك',
                    'تُحفَظ الرسائل مشفرة ببصمة تثبت عدم التلاعب بها',
                  ),
                ),
                const SizedBox(height: 12),
                Entrance(
                  delay: const Duration(milliseconds: 640),
                  child: _featureCard(
                    Icons.local_police_outlined,
                    'بلاغ رسمي بضغطة واحدة',
                    'يُنشئ بلاغاً جاهزاً للجهات المختصة فوراً',
                  ),
                ),

                const Spacer(),

                // ============ الإجراء ============
                Entrance(
                  delay: const Duration(milliseconds: 800),
                  child: Column(
                    children: [
                      Text(
                        'بالاستمرار فأنت توافق على معالجة رسائلك وفق إرشادات الخصوصية',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0D3B66),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => context.go('/onboarding/permissions'),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'ابدأ الآن',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_back, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF3FB8AA), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
