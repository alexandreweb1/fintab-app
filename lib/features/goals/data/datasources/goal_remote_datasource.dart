import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/goal_model.dart';

abstract class GoalRemoteDataSource {
  Stream<List<GoalModel>> watchGoals({required String userId});
  Future<void> addGoal(GoalModel model);
  Future<void> updateGoal(GoalModel model);
  Future<void> deleteGoal({required String goalId});
}

class GoalRemoteDataSourceImpl implements GoalRemoteDataSource {
  final FirebaseFirestore _db;

  GoalRemoteDataSourceImpl(this._db);

  CollectionReference get _col => _db.collection('goals');

  @override
  Stream<List<GoalModel>> watchGoals({required String userId}) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(GoalModel.fromFirestore).toList());
  }

  @override
  Future<void> addGoal(GoalModel model) async {
    final data = model.toFirestore();
    if (model.id.isEmpty) {
      await _col.add(data);
    } else {
      await _col.doc(model.id).set(data);
    }
  }

  @override
  Future<void> updateGoal(GoalModel model) async {
    await _col.doc(model.id).update(model.toFirestore());
  }

  @override
  Future<void> deleteGoal({required String goalId}) async {
    await _col.doc(goalId).delete();
  }
}
