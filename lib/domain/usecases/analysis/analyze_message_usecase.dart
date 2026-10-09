import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:napex_victim_app/core/error/failures.dart';
import 'package:napex_victim_app/domain/entities/analysis_result.dart';
import 'package:napex_victim_app/domain/repositories/ml_repository.dart';
import 'package:napex_victim_app/domain/usecases/base_usecase.dart';

class AnalyzeMessageParams extends Equatable {
  const AnalyzeMessageParams({
    required this.content,
    this.mediaPath,
    this.mediaType,
  });

  final String content;
  final String? mediaPath;
  final String? mediaType;

  @override
  List<Object?> get props => [content, mediaPath, mediaType];
}

class AnalyzeMessageUseCase
    extends UseCase<AnalysisResult, AnalyzeMessageParams> {
  AnalyzeMessageUseCase(this._repository);

  final MLRepository _repository;

  @override
  Future<Either<Failure, AnalysisResult>> call(
    AnalyzeMessageParams params,
  ) async {
    if (params.content.trim().isEmpty && params.mediaPath == null) {
      return const Right(AnalysisResult.normal);
    }

    final (result, failure) = await _repository.analyzeMessage(
      content: params.content,
      mediaPath: params.mediaPath,
      mediaType: params.mediaType,
    );

    if (failure != null) return Left(failure);
    return Right(result ?? AnalysisResult.normal);
  }
}
