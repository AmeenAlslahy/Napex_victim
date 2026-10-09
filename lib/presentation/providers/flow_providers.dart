import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:napex_victim_app/core/constants/app_constants.dart';
import 'package:napex_victim_app/core/storage/local_storage.dart';
import 'package:napex_victim_app/domain/repositories/auth_repository.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';

/// حالة مسار التطبيق (Splash → Onboarding → التطبيق الرئيسي)
class FlowState {
  const FlowState({
    this.restored = false,
    this.onboardingCompleted = false,
    this.authenticated = false,
  });

  final bool restored;
  final bool onboardingCompleted;
  final bool authenticated;

  FlowState copyWith({
    bool? restored,
    bool? onboardingCompleted,
    bool? authenticated,
  }) {
    return FlowState(
      restored: restored ?? this.restored,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      authenticated: authenticated ?? this.authenticated,
    );
  }
}

class FlowController extends StateNotifier<FlowState> {
  FlowController(
    this._storage,
    this._authRepository, {
    required bool initialAuthenticated,
  })  : _bootstrapAuthenticated = initialAuthenticated,
        super(const FlowState()) {
    _restore();
  }

  final LocalStorage _storage;
  final AuthRepository _authRepository;
  final bool _bootstrapAuthenticated;

  Future<void> _restore() async {
    final completed = _storage.getBool(AppConstants.keyOnboardingCompleted);

    var authenticated = false;
    if (completed) {
      authenticated =
          _bootstrapAuthenticated || await _authRepository.isAuthenticated();
    }

    state = FlowState(
      restored: true,
      onboardingCompleted: completed,
      authenticated: authenticated,
    );
  }

  /// بعد إكمال التسجيل والتحقق بنجاح
  Future<void> completeRegistration() async {
    await _storage.setBool(AppConstants.keyOnboardingCompleted, true);
    state = state.copyWith(
      onboardingCompleted: true,
      authenticated: true,
    );
  }

  /// عند تسجيل الخروج (يبقى الـ Onboarding مكتملاً)
  Future<void> logout() async {
    state = state.copyWith(authenticated: false);
  }

  /// مسح كامل (حذف الحساب)
  Future<void> reset() async {
    await _storage.setBool(AppConstants.keyOnboardingCompleted, false);
    state = const FlowState(restored: true);
  }
}

final flowProvider = StateNotifierProvider<FlowController, FlowState>((ref) {
  return FlowController(
    ref.watch(localStorageProvider),
    ref.watch(authRepositoryProvider),
    initialAuthenticated: ref.watch(initialAuthenticatedProvider),
  );
});
