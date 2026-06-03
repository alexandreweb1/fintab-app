import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/exceptions.dart';
import '../models/subscription_model.dart';

abstract class SubscriptionRemoteDataSource {
  Stream<SubscriptionModel> watchSubscription(String userId);
  Future<void> saveSubscription(String userId, SubscriptionModel model);
  Future<void> clearSubscription(String userId);
}

class SubscriptionRemoteDataSourceImpl implements SubscriptionRemoteDataSource {
  final FirebaseFirestore _firestore;

  SubscriptionRemoteDataSourceImpl(this._firestore);

  CollectionReference get _collection => _firestore.collection('subscriptions');

  @override
  Stream<SubscriptionModel> watchSubscription(String userId) {
    return _collection.doc(userId).snapshots().map(
          (snapshot) => SubscriptionModel.fromFirestore(snapshot),
        );
  }

  @override
  Future<void> saveSubscription(String userId, SubscriptionModel model) async {
    try {
      await _collection
          .doc(userId)
          .set(model.toFirestore(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> clearSubscription(String userId) async {
    try {
      await _collection.doc(userId).set({
        'status': 'expired',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 12));
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
