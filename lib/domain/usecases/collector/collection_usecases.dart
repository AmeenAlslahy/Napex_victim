import 'package:dartz/dartz.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/repositories/collector_repository.dart';
import 'package:napex_victim_app/domain/usecases/base_usecase.dart';

class StartCollectionUseCase extends NoParamUseCase<bool> {
  StartCollectionUseCase(this._repository);

  final CollectorRepository _repository;

  @override
  Future<Either<Failure, bool>> call() async {
    // تحقق مسبق: خدمة إمكانية الوصول (على أندرويد فقط — تتجاهل على المنصات الأخرى)
    final hasAccessibility = await _repository.isAccessibilityEnabled();
    if (!hasAccessibility) {
      return const Left(
        ServiceNotEnabledFailure(
          message: 'خدمة إمكانية الوصول غير مفعّلة',
        ),
      );
    }

    final (success, failure) = await _repository.startCollection();
    if (failure != null) return Left(failure);
    return Right(success);
  }
}

class StopCollectionUseCase extends NoParamUseCase<bool> {
  StopCollectionUseCase(this._repository);

  final CollectorRepository _repository;

  @override
  Future<Either<Failure, bool>> call() async {
    final (success, failure) = await _repository.stopCollection();
    if (failure != null) return Left(failure);
    return Right(success);
  }
}
