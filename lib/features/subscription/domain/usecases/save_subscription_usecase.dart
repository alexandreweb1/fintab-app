import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/subscription_entity.dart';
import '../repositories/subscription_repository.dart';

class SaveSubscriptionUseCase {
  final SubscriptionRepository _repository;

  SaveSubscriptionUseCase(this._repository);

  Future<Either<Failure, void>> call({
    required String userId,
    required SubscriptionEntity entity,
  }) {
    return _repository.saveSubscription(userId, entity);
  }
}
