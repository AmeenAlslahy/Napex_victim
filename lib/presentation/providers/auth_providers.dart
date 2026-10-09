import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/repositories/auth_repository.dart';
import 'package:napex_victim_app/domain/usecases/auth/logout_usecase.dart';
import 'package:napex_victim_app/domain/usecases/auth/register_user_usecase.dart';
import 'package:napex_victim_app/domain/usecases/auth/verify_otp_usecase.dart';
import 'package:napex_victim_app/presentation/providers/core_providers.dart';
import 'package:napex_victim_app/presentation/providers/flow_providers.dart';

/// خطوات تدفق المصادقة
enum AuthStep { idle, registering, otpSent, verifying, authenticated, failure }

class AuthState {
  const AuthState({
    this.step = AuthStep.idle,
    this.error,
    this.phoneNumber = '',
    this.fullName,
    this.governorate,
    this.demoModeOffered = false,
  });

  final AuthStep step;
  final String? error;
  final String phoneNumber;
  final String? fullName;
  final String? governorate;
  final bool demoModeOffered;

  bool get isLoading =>
      step == AuthStep.registering || step == AuthStep.verifying;

  AuthState copyWith({
    AuthStep? step,
    String? error,
    bool clearError = false,
    String? phoneNumber,
    String? fullName,
    String? governorate,
    bool? demoModeOffered,
  }) {
    return AuthState(
      step: step ?? this.step,
      error: clearError ? null : (error ?? this.error),
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fullName: fullName ?? this.fullName,
      governorate: governorate ?? this.governorate,
      demoModeOffered: demoModeOffered ?? this.demoModeOffered,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(
    this._registerUseCase,
    this._verifyUseCase,
    this._logoutUseCase,
    this._authRepository,
    this._flow,
  ) : super(const AuthState());

  final RegisterUserUseCase _registerUseCase;
  final VerifyOtpUseCase _verifyUseCase;
  final LogoutUseCase _logoutUseCase;
  final AuthRepository _authRepository;
  final FlowController _flow;

  /// الخطوة 1: إرسال رقم الهاتف لتلقي OTP
  Future<void> register({
    required String phoneNumber,
    String? fullName,
    String? governorate,
  }) async {
    state = state.copyWith(
      step: AuthStep.registering,
      clearError: true,
      demoModeOffered: false,
      phoneNumber: phoneNumber,
      fullName: fullName,
      governorate: governorate,
    );

    final result = await _registerUseCase(
      RegisterUserParams(
        phoneNumber: phoneNumber,
        fullName: fullName,
        governorate: governorate,
      ),
    );

    result.fold(
      (failure) {
        // عرض خيار الوضع التجريبي عند تعذر الوصول للخادم
        final serverUnavailable = failure is NoInternetFailure ||
            failure is TimeoutFailure ||
            failure is NetworkFailure ||
            failure is ServerFailure ||
            failure is UnknownFailure;

        state = state.copyWith(
          step: AuthStep.failure,
          error: failure.message,
          demoModeOffered: serverUnavailable,
        );
      },
      (_) => state = state.copyWith(step: AuthStep.otpSent, clearError: true),
    );
  }

  /// الخطوة 2: التحقق من رمز OTP
  Future<void> verifyOtp(String otp) async {
    state = state.copyWith(step: AuthStep.verifying, clearError: true);

    final result = await _verifyUseCase(
      VerifyOtpParams(phoneNumber: state.phoneNumber, otp: otp),
    );

    result.fold(
      (failure) {
        state = state.copyWith(step: AuthStep.failure, error: failure.message);
      },
      (success) async {
        if (success) {
          await _flow.completeRegistration();
          state = state.copyWith(step: AuthStep.authenticated, clearError: true);
        } else {
          state = state.copyWith(
            step: AuthStep.failure,
            error: 'رمز التحقق غير صحيح',
          );
        }
      },
    );
  }

  /// الوضع التجريبي المحلي — عند غياب الخادم (للتطوير والعرض)
  Future<void> continueAsDemo() async {
    final (user, failure) = await _authRepository.registerOfflineDemo(
      phoneNumber:
          state.phoneNumber.isEmpty ? '+967700000000' : state.phoneNumber,
      fullName: state.fullName,
      governorate: state.governorate,
    );

    if (failure != null) {
      state = state.copyWith(step: AuthStep.failure, error: failure.message);
      return;
    }

    await _flow.completeRegistration();
    state = state.copyWith(step: AuthStep.authenticated, clearError: true);
  }

  Future<void> logout() async {
    await _logoutUseCase();
    await _flow.logout();
    state = const AuthState();
  }

  void reset() => state = const AuthState();
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(registerUserUseCaseProvider),
    ref.watch(verifyOtpUseCaseProvider),
    ref.watch(logoutUseCaseProvider),
    ref.watch(authRepositoryProvider),
    ref.watch(flowProvider.notifier),
  );
});
