import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/budget_entity.dart';
import '../repositories/budget_repository.dart';

class SetBudgetUseCase extends UseCase<BudgetEntity, SetBudgetParams> {
  final BudgetRepository repository;

  SetBudgetUseCase(this.repository);

  @override
  Future<Either<Failure, BudgetEntity>> call(SetBudgetParams params) {
    return repository.setBudget(params.budget);
  }
}

class SetBudgetParams extends Equatable {
  final BudgetEntity budget;

  const SetBudgetParams({required this.budget});

  @override
  List<Object> get props => [budget];
}
