import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/entities/message.dart';
import 'package:napex_victim_app/domain/entities/report.dart';
import 'package:napex_victim_app/domain/repositories/report_repository.dart';
import 'package:napex_victim_app/domain/usecases/base_usecase.dart';

class CreateReportParams extends Equatable {
  const CreateReportParams({required this.message, required this.analysis});

  final CollectedMessage message;
  final AnalysisResult analysis;

  @override
  List<Object?> get props => [message, analysis];
}

class CreateReportUseCase extends UseCase<Report, CreateReportParams> {
  CreateReportUseCase(this._repository);

  final ReportRepository _repository;
  final Uuid _uuid = const Uuid();

  @override
  Future<Either<Failure, Report>> call(CreateReportParams params) async {
    final report = Report(
      id: _uuid.v4(),
      localId: _uuid.v4(),
      sender: params.message.sender,
      content: params.message.content,
      source: params.message.source,
      analysis: params.analysis,
      messageTimestamp: params.message.timestamp,
      createdAt: DateTime.now(),
      status: ReportStatus.pending,
    );

    final (saved, failure) = await _repository.saveReport(report);

    if (failure != null) return Left(failure);
    return Right(saved ?? report);
  }
}
