import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class UpdateTransactionUseCase extends UseCase<void, UpdateTransactionParams> {
  final TransactionRepository repository;
  UpdateTransactionUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateTransactionParams params) {
    return repository.updateTransaction(params.transaction);
  }
}

class UpdateTransactionParams extends Equatable {
  final TransactionEntity transaction;
  const UpdateTransactionParams({required this.transaction});

  @override
  List<Object> get props => [transaction];
}
