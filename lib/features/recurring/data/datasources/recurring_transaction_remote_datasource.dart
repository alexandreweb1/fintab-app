import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recurring_transaction_model.dart';

abstract class RecurringTransactionRemoteDataSource {
  Stream<List<RecurringTransactionModel>> watchAll({required String userId});
  Future<void> add(RecurringTransactionModel model);
  Future<void> update(RecurringTransactionModel model);
  Future<void> delete({required String id});
  Future<void> updateLastGenerated({
    required String id,
    required DateTime date,
  });
}

class RecurringTransactionRemoteDataSourceImpl
    implements RecurringTransactionRemoteDataSource {
  final FirebaseFirestore _db;

  RecurringTransactionRemoteDataSourceImpl(this._db);

  CollectionReference get _col => _db.collection('recurring_transactions');

  @override
  Stream<List<RecurringTransactionModel>> watchAll({required String userId}) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map(RecurringTransactionModel.fromFirestore).toList());
  }

  @override
  Future<void> add(RecurringTransactionModel model) async {
    final data = model.toFirestore();
    if (model.id.isEmpty) {
      await _col.add(data);
    } else {
      await _col.doc(model.id).set(data);
    }
  }

  @override
  Future<void> update(RecurringTransactionModel model) async {
    await _col.doc(model.id).update(model.toFirestore());
  }

  @override
  Future<void> delete({required String id}) async {
    await _col.doc(id).delete();
  }

  @override
  Future<void> updateLastGenerated({
    required String id,
    required DateTime date,
  }) async {
    await _col.doc(id).update({
      'lastGeneratedDate': Timestamp.fromDate(date),
    });
  }
}
