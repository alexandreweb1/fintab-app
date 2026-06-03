import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../entities/wallet_entity.dart';
import '../repositories/wallet_repository.dart';

class GetWalletsUseCase {
  final WalletRepository repository;
  GetWalletsUseCase(this.repository);

  Stream<Either<Failure, List<WalletEntity>>> call(GetWalletsParams params) {
    return repository.watchWallets(params.userId);
  }
}

class GetWalletsParams extends Equatable {
  final String userId;
  const GetWalletsParams({required this.userId});

  @override
  List<Object> get props => [userId];
}
