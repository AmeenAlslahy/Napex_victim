import 'dart:async';

import 'package:flutter/material.dart';

import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';

/// شاشة الدعم النفسي — "أنت لست وحدك": خطوط دعم + تمرين تنفس 4-7-8
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  // أرقام تُحدَّث حسب الجهات الفعلية المتاحة محلياً
  static const _hotlines = [
    ('الطوارئ الأمنية', '199'),
    ('خط الدعم النفسي', '139'),
  ];

  // ============ تمرين التنفس 4-7-8 ============
  static const _phases = [
    ('شهيق من الأنف', 4, Icons.south),
    ('احبس النفس', 7, Icons.pause),
    ('زفير من الفم ببطء', 8, Icons.north),
  ];

  Timer? _timer;
  int _phaseIndex = -1;
  int _remaining = 0;
  int _cycles = 0;

  bool get _running => _phaseIndex >= 0;

  void _startBreathing() {
    _cycles = 0;
    _nextPhase();
  }

  void _nextPhase() {
    setState(() {
      _phaseIndex = (_phaseIndex + 1) % _phases.length;
      if (_phaseIndex == 0) _cycles++;
      _remaining = _phases[_phaseIndex].$2;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining <= 1) {
        if (_phaseIndex == _phases.length - 1 && _cycles >= 3) {
          timer.cancel();
          setState(() => _phaseIndex = -1);
          return;
        }
        _nextPhase();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _stopBreathing() {
    _timer?.cancel();
    setState(() {
      _phaseIndex = -1;
      _cycles = 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('دعم نفسي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NapexCard(
            color: AppColors.secondary.withValues(alpha: 0.07),
            borderColor: AppColors.secondary.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أنت لست وحدك.',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ما حدث لك ليس ذنبك، والمبتز هو المسؤول وحده قانونياً. '
                  'أنت الآن تتحرك بالطريقة الصحيحة.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ============ خطوط الدعم ============
          Text('خطوط الدعم الفوري', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final (name, number) in _hotlines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NapexCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.support_agent_outlined, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(name)),
                    Text(
                      number,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // ============ تمرين التنفس ============
          Text('تمرين التنفس 4-7-8 (تهدئة سريعة)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          NapexCard(
            child: Column(
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _running
                        ? AppColors.secondary.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.06),
                    border: Border.all(
                      color: _running ? AppColors.secondary : AppColors.primary,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_running) ...[
                        Icon(_phases[_phaseIndex].$3, color: AppColors.secondary, size: 32),
                        const SizedBox(height: 6),
                        Text(
                          _phases[_phaseIndex].$1,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$_remaining',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.secondary,
                          ),
                        ),
                      ] else
                        const Icon(Icons.self_improvement_outlined,
                            size: 44, color: AppColors.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _running ? 'الدورة $_cycles من 3' : 'ثلاث دورات كاملة تهدئ الجهاز العصبي',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _running
                    ? OutlinedButton(
                        onPressed: _stopBreathing,
                        child: const Text('إيقاف'),
                      )
                    : FilledButton(
                        onPressed: _startBreathing,
                        child: const Text('ابدأ التمرين'),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ============ موارد دولية ============
          Text('موارد دولية لمحاربة نشر المحتوى', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          NapexCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SelectableText(
                  'StopNCII.org — إزالة الصور الحميمة المنشورة رضاخةً\n'
                  'https://stopncii.org',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                SizedBox(height: 8),
                SelectableText(
                  'INHOPE — شبكة خطوط الإبلاغ العالمية\n'
                  'https://inhope.org',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ============ خطوات عملية ============
          Text('خطوات عملية الآن', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          NapexCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final step in const [
                  'لا تدفع — الدفع لا يوقف الابتزاز أبداً',
                  'لا تحذف أي رسالة — الأدلة محفوظة مشفرة في التطبيق',
                  'أخبر شخصاً تثق به — الحديث يخفف نصف الحمل',
                  'توقف عن الرد على المبتز فوراً',
                  'راجع بلاغاتك في تبويب البلاغات وتابع حالتها',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 18, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(step, style: theme.textTheme.bodyMedium),
                        ),
                      ],
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
