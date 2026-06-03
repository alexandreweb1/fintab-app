import '../entities/recurring_transaction_entity.dart';

abstract class RecurringTransactionRepository {
  Stream<List<RecurringTransactionEntity>> watchAll({required String userId});
  Future<void> add(RecurringTransactionEntity entity);
  Future<void> update(RecurringTransactionEntity entity);
  Future<void> delete({required String id});
}
