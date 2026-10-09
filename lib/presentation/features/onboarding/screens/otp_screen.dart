import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:napex_victim_app/core/constants/app_constants.dart';
import 'package:napex_victim_app/core/theme/app_colors.dart';
import 'package:napex_victim_app/presentation/features/onboarding/widgets/step_header.dart';
import 'package:napex_victim_app/presentation/providers/auth_providers.dart';
import 'package:napex_victim_app/presentation/shared/widgets/entrance.dart';
import 'package:napex_victim_app/presentation/shared/widgets/otp_input.dart';
import 'package:napex_victim_app/presentation/shared/widgets/primary_button.dart';

/// شاشة رمز التحقق — الخطوة 3 من 3
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  String? _code;
  Timer? _resendTimer;
  int _remainingSeconds = AppConstants.otpResendDelay.inSeconds;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _remainingSeconds = AppConstants.otpResendDelay.inSeconds;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
      } else if (_remainingSeconds <= 0) {
        timer.cancel();
        setState(() {});
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _verify() async {
    if (_code == null || _code!.length != AppConstants.otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رمز التحقق كاملاً')),
      );
      return;
    }

    await ref.read(authProvider.notifier).verifyOtp(_code!);

    final state = ref.read(authProvider);
    if (state.step == AuthStep.authenticated && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null && next.step == AuthStep.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    final resendProgress = _remainingSeconds / AppConstants.otpResendDelay.inSeconds;

    return Scaffold(
      appBar: AppBar(title: const Text('رمز التحقق')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Entrance(
                child: OnboardingStepHeader(
                  currentStep: 3,
                  totalSteps: 3,
                  title: 'أدخل رمز التحقق',
                ),
              ),
              const SizedBox(height: 24),

              // ============ الأيقونة ============
              Entrance(
                delay: const Duration(milliseconds: 120),
                child: Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_clock_outlined,
                      size: 42,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Entrance(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'أرسلنا رمزاً من 6 أرقام إلى',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              Entrance(
                delay: const Duration(milliseconds: 240),
                child: Text(
                  auth.phoneNumber,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(height: 28),
              Entrance(
                delay: const Duration(milliseconds: 320),
                child: OtpInput(
                  onCompleted: (code) {
                    _code = code;
                    _verify();
                  },
                ),
              ),

              const SizedBox(height: 28),
              Entrance(
                delay: const Duration(milliseconds: 400),
                child: PrimaryButton(
                  label: 'تأكيد وتفعيل الحماية',
                  isLoading: auth.isLoading,
                  onPressed: _verify,
                ),
              ),

              const SizedBox(height: 20),
              Entrance(
                delay: const Duration(milliseconds: 480),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: resendProgress,
                        minHeight: 4,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _remainingSeconds > 0
                        ? Text(
                            'يمكنك طلب رمز جديد بعد $_remainingSeconds ثانية',
                            style: theme.textTheme.bodySmall,
                          )
                        : TextButton.icon(
                            onPressed: _startResendTimer,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('لم يصلك الرمز؟ أعد الإرسال'),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
