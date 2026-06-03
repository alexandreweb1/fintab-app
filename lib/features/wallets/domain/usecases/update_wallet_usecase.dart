import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/wallet_entity.dart';
import '../repositories/wallet_repository.dart';

class UpdateWalletUseCase extends UseCase<void, UpdateWalletParams> {
  final WalletRepository repository;

  UpdateWalletUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateWalletParams params) {
    return repository.updateWallet(params.wallet);
  }
}

class UpdateWalletParams extends Equatable {
  final WalletEntity wallet;

  const UpdateWalletParams({required this.wallet});

  @override
  List<Object> get props => [wallet];
}
