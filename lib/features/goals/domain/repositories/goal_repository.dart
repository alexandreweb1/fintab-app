import '../entities/goal_entity.dart';

abstract class GoalRepository {
  Stream<List<GoalEntity>> watchGoals({required String userId});
  Future<void> addGoal(GoalEntity goal);
  Future<void> updateGoal(GoalEntity goal);
  Future<void> deleteGoal({required String goalId});
}
