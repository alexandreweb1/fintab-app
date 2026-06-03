import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/transaction_entity.dart';

abstract class TransactionRepository {
  Stream<Either<Failure, List<TransactionEntity>>> watchTransactions(
      String userId);

  Future<Either<Failure, TransactionEntity>> addTransaction(
      TransactionEntity transaction);

  Future<Either<Failure, void>> updateTransaction(
      TransactionEntity transaction);

  Future<Either<Failure, void>> deleteTransaction(String transactionId);
}
