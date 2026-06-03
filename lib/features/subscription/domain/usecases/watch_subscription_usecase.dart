import '../entities/subscription_entity.dart';
import '../repositories/subscription_repository.dart';

class WatchSubscriptionUseCase {
  final SubscriptionRepository _repository;

  WatchSubscriptionUseCase(this._repository);

  Stream<SubscriptionEntity> call({required String userId}) {
    return _repository.watchSubscription(userId);
  }
}
