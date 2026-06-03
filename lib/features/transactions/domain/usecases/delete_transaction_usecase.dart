import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/transaction_repository.dart';

class DeleteTransactionUseCase extends UseCase<void, DeleteTransactionParams> {
  final TransactionRepository repository;
  DeleteTransactionUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteTransactionParams params) {
    return repository.deleteTransaction(params.transactionId);
  }
}

class DeleteTransactionParams extends Equatable {
  final String transactionId;
  const DeleteTransactionParams({required this.transactionId});

  @override
  List<Object> get props => [transactionId];
}
