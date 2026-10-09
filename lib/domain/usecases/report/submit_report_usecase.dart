import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/entities/report.dart';
import 'package:napex_victim_app/domain/repositories/report_repository.dart';
import 'package:napex_victim_app/domain/usecases/base_usecase.dart';

class SubmitReportParams extends Equatable {
  const SubmitReportParams({required this.report});

  final Report report;

  @override
  List<Object?> get props => [report];
}

class SubmitReportUseCase extends UseCase<String, SubmitReportParams> {
  SubmitReportUseCase(this._repository);

  final ReportRepository _repository;

  @override
  Future<Either<Failure, String>> call(SubmitReportParams params) async {
    final (reportNumber, failure) = await _repository.submitReport(params.report);

    if (failure != null) return Left(failure);
    return Right(reportNumber ?? params.report.localId);
  }
}
