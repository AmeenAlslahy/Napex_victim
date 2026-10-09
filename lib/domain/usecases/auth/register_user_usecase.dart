import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/core/utils/extensions.dart';
import 'package:napex_victim_app/domain/entities/user.dart';
import 'package:napex_victim_app/domain/repositories/auth_repository.dart';
import 'package:napex_victim_app/domain/usecases/base_usecase.dart';

class RegisterUserParams extends Equatable {
  const RegisterUserParams({
    required this.phoneNumber,
    this.fullName,
    this.governorate,
  });

  final String phoneNumber;
  final String? fullName;
  final String? governorate;

  @override
  List<Object?> get props => [phoneNumber, fullName, governorate];
}

class RegisterUserUseCase extends UseCase<User?, RegisterUserParams> {
  RegisterUserUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, User?>> call(RegisterUserParams params) async {
    final phone = params.phoneNumber.trim();

    if (phone.isEmpty) {
      return const Left(
        ValidationFailure(message: 'رقم الهاتف مطلوب', details: {}),
      );
    }

    if (!phone.isPhoneNumber) {
      return const Left(
        ValidationFailure(
          message: 'رقم الهاتف غير صالح — أدخل رقماً صحيحاً مع رمز الدولة',
          details: {},
        ),
      );
    }

    final (user, failure) = await _repository.register(
      phoneNumber: phone,
      fullName: params.fullName?.trim(),
      governorate: params.governorate,
    );

    if (failure != null) return Left(failure);
    return Right(user);
  }
}
