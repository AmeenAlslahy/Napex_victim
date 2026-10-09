import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:napex_victim_app/core/constants/app_constants.dart';
import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/repositories/auth_repository.dart';
import 'package:napex_victim_app/domain/usecases/base_usecase.dart';

class VerifyOtpParams extends Equatable {
  const VerifyOtpParams({required this.phoneNumber, required this.otp});

  final String phoneNumber;
  final String otp;

  @override
  List<Object?> get props => [phoneNumber, otp];
}

class VerifyOtpUseCase extends UseCase<bool, VerifyOtpParams> {
  VerifyOtpUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, bool>> call(VerifyOtpParams params) async {
    final otp = params.otp.trim();

    if (otp.length != AppConstants.otpLength) {
      return const Left(
        ValidationFailure(
          message:
              'رمز التحقق يجب أن يكون ${AppConstants.otpLength} أرقام',
          details: {},
        ),
      );
    }

    final (success, failure) = await _repository.verifyOtp(
      phoneNumber: params.phoneNumber,
      otp: otp,
    );

    if (failure != null) return Left(failure);
    return Right(success);
  }
}
