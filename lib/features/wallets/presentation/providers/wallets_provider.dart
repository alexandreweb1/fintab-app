import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/effective_user_provider.dart';
import '../../../../core/providers/workspace_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/wallet_remote_datasource.dart';
import '../../data/models/wallet_model.dart';
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
  final scope = ref.watch(activeLedgerScopeProvider);

  // New-style shared member: query the workspace's docs server-side.
  if (scope is MemberScope) {
    return workspaceCollectionQuery(
            ref.watch(firestoreProvider), 'wallets', scope.workspaceId)
        .snapshots()
        .map((snap) {
      final List<WalletEntity> list =
          snap.docs.map(WalletModel.fromFirestore).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  final authState = ref.watch(authStateProvider);
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  return authState.when(
    data: (user) {
      if (user == null || effectiveUserId.isEmpty) return const Stream.empty();
      return ref
          .watch(getWalletsUseCaseProvider)
          .call(GetWalletsParams(userId: effectiveUserId))
          .map((either) => either.getOrElse(() => []))
          .map((list) =>
              applyWorkspaceScope(list, (w) => w.workspaceId, scope));
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// --- Seed provider (auto-creates "Conta corrente" on first load) ---

final walletsSeedProvider = Provider<void>((ref) {
  // NEVER seed defaults into a shared workspace (MemberScope).
  if (ref.watch(activeLedgerScopeProvider) is! UserScope) return;
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
  final String? _workspaceId;

  WalletsNotifier(
    this._addWallet,
    this._updateWallet,
    this._deleteWallet,
    this._repository,
    this._workspaceId,
  ) : super(const AsyncValue.data(null));

  Future<bool> add({
    required String userId,
    required String name,
    required int iconCodePoint,
    required int colorValue,
    String currencyCode = '',
    WalletType type = WalletType.regular,
    double targetAmount = 0,
    double creditLimit = 0,
    int closingDay = 1,
    int dueDay = 10,
  }) async {
    state = const AsyncValue.loading();
    final wallet = WalletEntity(
      id: const Uuid().v4(),
      userId: userId,
      workspaceId: _workspaceId,
      name: name,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      currencyCode: currencyCode,
      type: type,
      targetAmount: targetAmount,
      creditLimit: creditLimit,
      closingDay: closingDay,
      dueDay: dueDay,
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

  /// Creates the default "Conta corrente" wallet. Constructed here (instead
  /// of the datasource seed) so the new doc carries the workspaceId stamp.
  Future<void> seedDefaults(String userId) async {
    final wallet = WalletEntity(
      id: const Uuid().v4(),
      userId: userId,
      workspaceId: _workspaceId,
      name: 'Conta corrente',
      iconCodePoint: 0xe4c9, // Icons.account_balance_wallet
      colorValue: 0xFF1976D2,
      isDefault: true,
      currencyCode: 'BRL',
    );
    final result = await _repository.addWallet(wallet);
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
    ref.watch(workspaceStampProvider),
  );
});
