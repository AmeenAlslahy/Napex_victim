import 'package:dartz/dartz.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/repositories/report_repository.dart';
import 'package:napex_victim_app/domain/usecases/base_usecase.dart';

/// مزامنة البلاغات المعلقة مع الخادم — يُعيد عدد البلاغات المرسلة
class SyncReportsUseCase extends NoParamUseCase<int> {
  SyncReportsUseCase(this._repository);

  final ReportRepository _repository;

  @override
  Future<Either<Failure, int>> call() async {
    final (count, failure) = await _repository.syncReports();
    if (failure != null) return Left(failure);
    return Right(count);
  }
}
