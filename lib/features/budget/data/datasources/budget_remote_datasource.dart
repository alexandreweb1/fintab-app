import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/exceptions.dart';
import '../models/budget_model.dart';

abstract class BudgetRemoteDataSource {
  Stream<List<BudgetModel>> watchBudgets(String userId, DateTime month);
  Stream<List<BudgetModel>> watchBudgetsByYear(String userId, int year);
  Future<BudgetModel> setBudget(BudgetModel budget);
  Future<void> deleteBudget(String budgetId);
}

class BudgetRemoteDataSourceImpl implements BudgetRemoteDataSource {
  final FirebaseFirestore _firestore;

  BudgetRemoteDataSourceImpl(this._firestore);

  CollectionReference get _collection => _firestore.collection('budgets');

  static const _kTimeout = Duration(seconds: 12);

  @override
  Stream<List<BudgetModel>> watchBudgets(String userId, DateTime month) {
    final start = Timestamp.fromDate(DateTime(month.year, month.month, 1));
    final end = Timestamp.fromDate(DateTime(month.year, month.month + 1, 1));
    return _collection
        .where('userId', isEqualTo: userId)
        .where('month', isGreaterThanOrEqualTo: start)
        .where('month', isLessThan: end)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList());
  }

  @override
  Stream<List<BudgetModel>> watchBudgetsByYear(String userId, int year) {
    final start = Timestamp.fromDate(DateTime(year, 1, 1));
    final end = Timestamp.fromDate(DateTime(year + 1, 1, 1));
    return _collection
        .where('userId', isEqualTo: userId)
        .where('month', isGreaterThanOrEqualTo: start)
        .where('month', isLessThan: end)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList());
  }

  @override
  Future<BudgetModel> setBudget(BudgetModel budget) async {
    try {
      final docRef = _collection.doc(budget.id);
      await docRef
          .set(budget.toFirestore())
          .timeout(_kTimeout, onTimeout: () => throw const ServerException(
              'Tempo limite excedido ao salvar orçamento.'));
      final doc = await docRef.get().timeout(_kTimeout);
      return BudgetModel.fromFirestore(doc);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteBudget(String budgetId) async {
    try {
      await _collection.doc(budgetId).delete().timeout(_kTimeout);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
