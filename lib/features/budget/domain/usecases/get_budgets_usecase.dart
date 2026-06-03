import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../entities/budget_entity.dart';
import '../repositories/budget_repository.dart';

class GetBudgetsUseCase {
  final BudgetRepository repository;

  GetBudgetsUseCase(this.repository);

  Stream<Either<Failure, List<BudgetEntity>>> call(GetBudgetsParams params) {
    return repository.watchBudgets(params.userId, params.month);
  }
}

class GetBudgetsParams extends Equatable {
  final String userId;
  final DateTime month;

  const GetBudgetsParams({required this.userId, required this.month});

  @override
  List<Object> get props => [userId, month];
}
