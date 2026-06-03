import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/wallet_entity.dart';

abstract class WalletRepository {
  Stream<Either<Failure, List<WalletEntity>>> watchWallets(String userId);
  Future<Either<Failure, WalletEntity>> addWallet(WalletEntity wallet);
  Future<Either<Failure, void>> updateWallet(WalletEntity wallet);
  Future<Either<Failure, void>> deleteWallet(String walletId);
  Future<Either<Failure, void>> seedDefaults(String userId);
}
