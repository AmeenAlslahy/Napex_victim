import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:napex_victim_app/presentation/features/onboarding/widgets/step_header.dart';
import 'package:napex_victim_app/presentation/providers/auth_providers.dart';
import 'package:napex_victim_app/presentation/shared/widgets/entrance.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_card.dart';
import 'package:napex_victim_app/presentation/shared/widgets/napex_text_field.dart';
import 'package:napex_victim_app/presentation/shared/widgets/primary_button.dart';

/// المحافظات اليمنية
const List<String> kGovernorates = [
  'أمانة العاصمة',
  'صنعاء',
  'عدن',
  'تعز',
  'الحديدة',
  'إب',
  'حضرموت',
  'ذمار',
  'لحج',
  'أبين',
  'شبوة',
  'مأرب',
  'صعدة',
  'عمران',
  'المحويت',
  'البيضاء',
  'الجوف',
  'ريمة',
  'المهرة',
  'سقطرى',
];

/// شاشة التسجيل — الخطوة 2 من 3
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _governorate;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authProvider.notifier).register(
          phoneNumber: _phoneController.text.trim(),
          fullName: _nameController.text.trim(),
          governorate: _governorate,
        );

    if (ref.read(authProvider).step == AuthStep.otpSent && mounted) {
      context.push('/onboarding/otp');
    }
  }

  Future<void> _continueAsDemo() async {
    await ref.read(authProvider.notifier).continueAsDemo();
    if (mounted) context.go('/dashboard');
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

    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Entrance(
                child: OnboardingStepHeader(
                  currentStep: 2,
                  totalSteps: 3,
                  title: 'بياناتك',
                  subtitle:
                      'سجّل رقمك لتصلك تنبيهات الحماية ولربط بلاغاتك بحسابك. '
                      'لا يُعرض رقمك على أحد.',
                ),
              ),
              const SizedBox(height: 26),

              Entrance(
                delay: const Duration(milliseconds: 120),
                child: NapexTextField(
                  controller: _nameController,
                  label: 'الاسم (اختياري)',
                  prefixIcon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 16),
              Entrance(
                delay: const Duration(milliseconds: 200),
                child: DropdownButtonFormField<String>(
                  initialValue: _governorate,
                  icon: const Icon(Icons.expand_more),
                  decoration: const InputDecoration(
                    labelText: 'المحافظة',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  items: kGovernorates
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (value) => setState(() => _governorate = value),
                ),
              ),
              const SizedBox(height: 16),
              Entrance(
                delay: const Duration(milliseconds: 280),
                child: NapexTextField(
                  controller: _phoneController,
                  label: 'رقم الهاتف',
                  hint: '+967 7xx xxx xxx',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[+0-9]')),
                  ],
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'رقم الهاتف مطلوب';
                    if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(v)) {
                      return 'أدخل رقماً صحيحاً مع رمز الدولة (مثال: +967771234567)';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 30),
              Entrance(
                delay: const Duration(milliseconds: 360),
                child: PrimaryButton(
                  label: 'إرسال رمز التحقق',
                  icon: Icons.sms_outlined,
                  isLoading: auth.isLoading,
                  onPressed: _submit,
                ),
              ),

              // الدخول بدون تسجيل — متاح دائماً قبل أي محاولة
              Entrance(
                delay: const Duration(milliseconds: 420),
                child: TextButton.icon(
                  onPressed: auth.isLoading ? null : _continueAsDemo,
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  label: const Text('الدخول بدون تسجيل (تجريبي)'),
                ),
              ),

              // ============ الوضع التجريبي (عند تعذر الخادم) ============
              if (auth.demoModeOffered) ...[
                const SizedBox(height: 22),
                Entrance(
                  child: NapexCard(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.08),
                    borderColor:
                        theme.colorScheme.secondary.withValues(alpha: 0.35),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cloud_off_outlined,
                                color: theme.colorScheme.secondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'تعذر الوصول إلى الخادم حالياً',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'يمكنك المتابعة في وضع تجريبي محلي — الحماية والتحليل '
                          'يعملان كاملاً على جهازك، وترسل البلاغات تلقائياً عند '
                          'توفر الخادم.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(height: 1.6),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _continueAsDemo,
                          child: const Text('المتابعة في الوضع التجريبي'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
