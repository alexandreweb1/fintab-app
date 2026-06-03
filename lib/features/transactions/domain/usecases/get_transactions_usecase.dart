import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class GetTransactionsUseCase {
  final TransactionRepository repository;
  GetTransactionsUseCase(this.repository);

  Stream<Either<Failure, List<TransactionEntity>>> call(
      GetTransactionsParams params) {
    return repository.watchTransactions(params.userId);
  }
}

class GetTransactionsParams extends Equatable {
  final String userId;
  const GetTransactionsParams({required this.userId});

  @override
  List<Object> get props => [userId];
}
