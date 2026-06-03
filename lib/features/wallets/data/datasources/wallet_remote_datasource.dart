import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../models/wallet_model.dart';

abstract class WalletRemoteDataSource {
  Stream<List<WalletModel>> watchWallets(String userId);
  Future<WalletModel> addWallet(WalletModel wallet);
  Future<void> updateWallet(WalletModel wallet);
  Future<void> deleteWallet(String walletId);
  Future<void> seedDefaults(String userId);
}

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  final FirebaseFirestore _firestore;

  WalletRemoteDataSourceImpl(this._firestore);

  CollectionReference get _collection => _firestore.collection('wallets');

  static const _kTimeout = Duration(seconds: 12);

  @override
  Stream<List<WalletModel>> watchWallets(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => WalletModel.fromFirestore(d)).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  @override
  Future<WalletModel> addWallet(WalletModel wallet) async {
    try {
      final ref = await _collection
          .add(wallet.toFirestore())
          .timeout(_kTimeout);
      final doc = await ref.get().timeout(_kTimeout);
      return WalletModel.fromFirestore(doc);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateWallet(WalletModel wallet) async {
    try {
      await _collection
          .doc(wallet.id)
          .update(wallet.toFirestore())
          .timeout(_kTimeout);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> deleteWallet(String walletId) async {
    try {
      await _collection.doc(walletId).delete().timeout(_kTimeout);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> seedDefaults(String userId) async {
    try {
      final batch = _firestore.batch();
      final defaults = _defaultWallets(userId);
      for (final w in defaults) {
        final ref = _collection.doc(const Uuid().v4());
        batch.set(ref, w.toFirestore());
      }
      await batch.commit().timeout(_kTimeout);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  List<WalletModel> _defaultWallets(String userId) => [
        WalletModel(
          id: '',
          userId: userId,
          name: 'Conta corrente',
          iconCodePoint: 0xe4c9, // Icons.account_balance_wallet
          colorValue: 0xFF1976D2,
          isDefault: true,
          currencyCode: 'BRL',
        ),
      ];
}
