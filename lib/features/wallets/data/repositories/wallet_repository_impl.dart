import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_remote_datasource.dart';
import '../models/wallet_model.dart';

class WalletRepositoryImpl implements WalletRepository {
  final WalletRemoteDataSource remoteDataSource;

  WalletRepositoryImpl(this.remoteDataSource);

  @override
  Stream<Either<Failure, List<WalletEntity>>> watchWallets(String userId) {
    return remoteDataSource.watchWallets(userId).transform(
      StreamTransformer.fromHandlers(
        handleData: (models, sink) =>
            sink.add(Right(List<WalletEntity>.from(models))),
        handleError: (error, _, sink) =>
            sink.add(Left(ServerFailure(error.toString()))),
      ),
    );
  }

  @override
  Future<Either<Failure, WalletEntity>> addWallet(WalletEntity wallet) async {
    try {
      final model = WalletModel.fromEntity(wallet);
      final result = await remoteDataSource.addWallet(model);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updateWallet(WalletEntity wallet) async {
    try {
      final model = WalletModel.fromEntity(wallet);
      await remoteDataSource.updateWallet(model);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteWallet(String walletId) async {
    try {
      await remoteDataSource.deleteWallet(walletId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> seedDefaults(String userId) async {
    try {
      await remoteDataSource.seedDefaults(userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
