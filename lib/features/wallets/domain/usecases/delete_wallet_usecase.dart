import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/wallet_repository.dart';

class DeleteWalletUseCase extends UseCase<void, DeleteWalletParams> {
  final WalletRepository repository;
  DeleteWalletUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteWalletParams params) {
    return repository.deleteWallet(params.walletId);
  }
}

class DeleteWalletParams extends Equatable {
  final String walletId;
  const DeleteWalletParams({required this.walletId});

  @override
  List<Object> get props => [walletId];
}
