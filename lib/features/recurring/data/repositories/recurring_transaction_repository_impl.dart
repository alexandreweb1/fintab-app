import '../../domain/entities/recurring_transaction_entity.dart';
import '../../domain/repositories/recurring_transaction_repository.dart';
import '../datasources/recurring_transaction_remote_datasource.dart';
import '../models/recurring_transaction_model.dart';

class RecurringTransactionRepositoryImpl
    implements RecurringTransactionRepository {
  final RecurringTransactionRemoteDataSource _ds;

  RecurringTransactionRepositoryImpl(this._ds);

  @override
  Stream<List<RecurringTransactionEntity>> watchAll({required String userId}) =>
      _ds.watchAll(userId: userId);

  @override
  Future<void> add(RecurringTransactionEntity entity) =>
      _ds.add(RecurringTransactionModel.fromEntity(entity));

  @override
  Future<void> update(RecurringTransactionEntity entity) =>
      _ds.update(RecurringTransactionModel.fromEntity(entity));

  @override
  Future<void> delete({required String id}) => _ds.delete(id: id);
}
