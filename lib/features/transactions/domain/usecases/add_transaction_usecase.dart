import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class AddTransactionUseCase extends UseCase<TransactionEntity, AddTransactionParams> {
  final TransactionRepository repository;
  AddTransactionUseCase(this.repository);

  @override
  Future<Either<Failure, TransactionEntity>> call(
      AddTransactionParams params) {
    return repository.addTransaction(params.transaction);
  }
}

class AddTransactionParams extends Equatable {
  final TransactionEntity transaction;
  const AddTransactionParams({required this.transaction});

  @override
  List<Object> get props => [transaction];
}
