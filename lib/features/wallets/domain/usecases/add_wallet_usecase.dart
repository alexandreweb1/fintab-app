import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/wallet_entity.dart';
import '../repositories/wallet_repository.dart';

class AddWalletUseCase extends UseCase<WalletEntity, AddWalletParams> {
  final WalletRepository repository;
  AddWalletUseCase(this.repository);

  @override
  Future<Either<Failure, WalletEntity>> call(AddWalletParams params) {
    return repository.addWallet(params.wallet);
  }
}

class AddWalletParams extends Equatable {
  final WalletEntity wallet;
  const AddWalletParams({required this.wallet});

  @override
  List<Object> get props => [wallet];
}
