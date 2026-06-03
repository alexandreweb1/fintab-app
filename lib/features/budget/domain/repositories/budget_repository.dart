import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/budget_entity.dart';

abstract class BudgetRepository {
  Stream<Either<Failure, List<BudgetEntity>>> watchBudgets(
      String userId, DateTime month);

  /// Watches every budget whose [BudgetEntity.month] falls in the calendar
  /// year [year]. Used by the period views (quarterly / semestral / annual).
  Stream<Either<Failure, List<BudgetEntity>>> watchBudgetsByYear(
      String userId, int year);

  Future<Either<Failure, BudgetEntity>> setBudget(BudgetEntity budget);
  Future<Either<Failure, void>> deleteBudget(String budgetId);
}
