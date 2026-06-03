import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/effective_user_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/wallet_remote_datasource.dart';
import '../../data/repositories/wallet_repository_impl.dart';
import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../../domain/usecases/add_wallet_usecase.dart';
import '../../domain/usecases/delete_wallet_usecase.dart';
import '../../domain/usecases/get_wallets_usecase.dart';
import '../../domain/usecases/update_wallet_usecase.dart';

// --- Infrastructure ---

final walletDataSourceProvider = Provider<WalletRemoteDataSource>(
  (ref) => WalletRemoteDataSourceImpl(ref.watch(firestoreProvider)),
);

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepositoryImpl(ref.watch(walletDataSourceProvider)),
);

// --- Use Cases ---

final getWalletsUseCaseProvider = Provider(
  (ref) => GetWalletsUseCase(ref.watch(walletRepositoryProvider)),
);

final addWalletUseCaseProvider = Provider(
  (ref) => AddWalletUseCase(ref.watch(walletRepositoryProvider)),
);

final updateWalletUseCaseProvider = Provider(
  (ref) => UpdateWalletUseCase(ref.watch(walletRepositoryProvider)),
);

final deleteWalletUseCaseProvider = Provider(
  (ref) => DeleteWalletUseCase(ref.watch(walletRepositoryProvider)),
);

// --- Filtered providers by wallet type ---

final regularWalletsProvider = Provider<List<WalletEntity>>((ref) {
  final all = ref.watch(walletsStreamProvider).value ?? [];
  return all.where((w) => w.type == WalletType.regular).toList();
});

final reserveWalletsProvider = Provider<List<WalletEntity>>((ref) {
  final all = ref.watch(walletsStreamProvider).value ?? [];
  return all.where((w) => w.type == WalletType.reserve).toList();
});

final investmentWalletsProvider = Provider<List<WalletEntity>>((ref) {
  final all = ref.watch(walletsStreamProvider).value ?? [];
  return all.where((w) => w.type == WalletType.investment).toList();
});

// --- Stream Provider ---

final walletsStreamProvider = StreamProvider<List<WalletEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  return authState.when(
    data: (user) {
      if (user == null || effectiveUserId.isEmpty) return const Stream.empty();
      return ref
          .watch(getWalletsUseCaseProvider)
          .call(GetWalletsParams(userId: effectiveUserId))
          .map((either) => either.getOrElse(() => []));
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// --- Seed provider (auto-creates "Conta corrente" on first load) ---

final walletsSeedProvider = Provider<void>((ref) {
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  ref.listen<AsyncValue<List<WalletEntity>>>(
    walletsStreamProvider,
    (_, next) {
      next.whenData((wallets) {
        if (wallets.isEmpty && effectiveUserId.isNotEmpty) {
          ref.read(walletsNotifierProvider.notifier).seedDefaults(effectiveUserId);
        }
      });
    },
    fireImmediately: true,
  );
});

// --- Notifier ---

class WalletsNotifier extends StateNotifier<AsyncValue<void>> {
  final AddWalletUseCase _addWallet;
  final UpdateWalletUseCase _updateWallet;
  final DeleteWalletUseCase _deleteWallet;
  final WalletRepository _repository;

  WalletsNotifier(
      this._addWallet, this._updateWallet, this._deleteWallet, this._repository)
      : super(const AsyncValue.data(null));

  Future<bool> add({
    required String userId,
    required String name,
    required int iconCodePoint,
    required int colorValue,
    String currencyCode = '',
    WalletType type = WalletType.regular,
    double targetAmount = 0,
  }) async {
    state = const AsyncValue.loading();
    final wallet = WalletEntity(
      id: const Uuid().v4(),
      userId: userId,
      name: name,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      currencyCode: currencyCode,
      type: type,
      targetAmount: targetAmount,
    );
    final result = await _addWallet(AddWalletParams(wallet: wallet));
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> update(WalletEntity wallet) async {
    state = const AsyncValue.loading();
    final result = await _updateWallet(UpdateWalletParams(wallet: wallet));
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> delete(String walletId) async {
    state = const AsyncValue.loading();
    final result =
        await _deleteWallet(DeleteWalletParams(walletId: walletId));
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<void> seedDefaults(String userId) async {
    final result = await _repository.seedDefaults(userId);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (_) => state = const AsyncValue.data(null),
    );
  }
}

final walletsNotifierProvider =
    StateNotifierProvider<WalletsNotifier, AsyncValue<void>>((ref) {
  return WalletsNotifier(
    ref.watch(addWalletUseCaseProvider),
    ref.watch(updateWalletUseCaseProvider),
    ref.watch(deleteWalletUseCaseProvider),
    ref.watch(walletRepositoryProvider),
  );
});
