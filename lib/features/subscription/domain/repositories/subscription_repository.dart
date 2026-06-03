import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/subscription_entity.dart';

abstract class SubscriptionRepository {
  Stream<SubscriptionEntity> watchSubscription(String userId);

  Future<Either<Failure, void>> saveSubscription(
    String userId,
    SubscriptionEntity entity,
  );

  Future<Either<Failure, void>> clearSubscription(String userId);
}
