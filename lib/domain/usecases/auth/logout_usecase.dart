import 'package:dartz/dartz.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/repositories/auth_repository.dart';
import 'package:napex_victim_app/domain/usecases/base_usecase.dart';

class LogoutUseCase extends NoParamUseCase<bool> {
  LogoutUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, bool>> call() async {
    final (success, failure) = await _repository.logout();
    if (failure != null) return Left(failure);
    return Right(success);
  }
}
