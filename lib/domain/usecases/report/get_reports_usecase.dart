import 'package:dartz/dartz.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/entities/report.dart';
import 'package:napex_victim_app/domain/repositories/report_repository.dart';
import 'package:napex_victim_app/domain/usecases/base_usecase.dart';

/// بث مباشر لقائمة البلاغات (تُحدَّث تلقائياً عند أي تغيير)
class GetReportsUseCase extends StreamUseCase<List<Report>, NoParams> {
  GetReportsUseCase(this._repository);

  final ReportRepository _repository;

  @override
  Stream<Either<Failure, List<Report>>> call(NoParams params) async* {
    await for (final reports in _repository.watchReports()) {
      yield Right(reports);
    }
  }
}
