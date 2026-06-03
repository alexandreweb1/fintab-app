import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/exceptions.dart';
import '../models/transaction_model.dart';

abstract class TransactionRemoteDataSource {
  Stream<List<TransactionModel>> watchTransactions(String userId);
  Future<TransactionModel> addTransaction(TransactionModel transaction);
  Future<void> updateTransaction(TransactionModel transaction);
  Future<void> deleteTransaction(String transactionId);
}

class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  final FirebaseFirestore _firestore;

  TransactionRemoteDataSourceImpl(this._firestore);

  CollectionReference get _collection =>
      _firestore.collection('transactions');

  @override
  Stream<List<TransactionModel>> watchTransactions(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  static const _kTimeout = Duration(seconds: 12);

  @override
  Future<TransactionModel> addTransaction(TransactionModel transaction) async {
    try {
      final docRef = await _collection
          .add(transaction.toFirestore())
          .timeout(_kTimeout, onTimeout: () => throw const ServerException(
              'Tempo limite excedido. Verifique se o Firestore está habilitado '
              'no Firebase Console.'));
      final doc = await docRef.get().timeout(_kTimeout);
      return TransactionModel.fromFirestore(doc);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateTransaction(TransactionModel transaction) async {
    try {
      await _collection
          .doc(transaction.id)
          .update(transaction.toFirestore())
          .timeout(_kTimeout);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _collection
          .doc(transactionId)
          .delete()
          .timeout(_kTimeout);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
