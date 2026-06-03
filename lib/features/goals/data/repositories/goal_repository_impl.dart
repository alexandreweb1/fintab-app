import '../../domain/entities/goal_entity.dart';
import '../../domain/repositories/goal_repository.dart';
import '../datasources/goal_remote_datasource.dart';
import '../models/goal_model.dart';

class GoalRepositoryImpl implements GoalRepository {
  final GoalRemoteDataSource _ds;

  GoalRepositoryImpl(this._ds);

  @override
  Stream<List<GoalEntity>> watchGoals({required String userId}) =>
      _ds.watchGoals(userId: userId);

  @override
  Future<void> addGoal(GoalEntity goal) =>
      _ds.addGoal(GoalModel.fromEntity(goal));

  @override
  Future<void> updateGoal(GoalEntity goal) =>
      _ds.updateGoal(GoalModel.fromEntity(goal));

  @override
  Future<void> deleteGoal({required String goalId}) =>
      _ds.deleteGoal(goalId: goalId);
}
