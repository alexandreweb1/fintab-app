import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_remote_datasource.dart';
import '../models/subscription_model.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionRemoteDataSource remoteDataSource;

  SubscriptionRepositoryImpl(this.remoteDataSource);

  @override
  Stream<SubscriptionEntity> watchSubscription(String userId) {
    return remoteDataSource.watchSubscription(userId).transform(
          StreamTransformer.fromHandlers(
            handleData: (model, sink) => sink.add(model),
            handleError: (_, __, sink) =>
                sink.add(SubscriptionModel.none()),
          ),
        );
  }

  @override
  Future<Either<Failure, void>> saveSubscription(
    String userId,
    SubscriptionEntity entity,
  ) async {
    try {
      final model = SubscriptionModel(
        type: entity.type,
        status: entity.status,
        purchaseToken: entity.purchaseToken,
        productId: entity.productId,
        expiryDate: entity.expiryDate,
        updatedAt: entity.updatedAt,
      );
      await remoteDataSource.saveSubscription(userId, model);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> clearSubscription(String userId) async {
    try {
      await remoteDataSource.clearSubscription(userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
