import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/budget_repository.dart';

class DeleteBudgetUseCase extends UseCase<void, DeleteBudgetParams> {
  final BudgetRepository repository;

  DeleteBudgetUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteBudgetParams params) {
    return repository.deleteBudget(params.budgetId);
  }
}

class DeleteBudgetParams extends Equatable {
  final String budgetId;

  const DeleteBudgetParams({required this.budgetId});

  @override
  List<Object> get props => [budgetId];
}
