import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:napex_victim_app/core/error/failures.dart';

/// النوع الأساسي للـ UseCase
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// UseCase بدون معاملات
abstract class NoParamUseCase<T> {
  Future<Either<Failure, T>> call();
}

/// UseCase ببث مباشر
abstract class StreamUseCase<T, Params> {
  Stream<Either<Failure, T>> call(Params params);
}

/// لا توجد معاملات
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
