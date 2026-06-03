import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/wallets/presentation/providers/wallets_provider.dart';
import '../../data/datasources/subscription_remote_datasource.dart';
import '../../data/repositories/subscription_repository_impl.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../domain/usecases/save_subscription_usecase.dart';
import '../../domain/usecases/watch_subscription_usecase.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IDs dos produtos no Google Play / App Store
// ─────────────────────────────────────────────────────────────────────────────

const kIapMonthly = 'pro_monthly';
const kIapAnnual = 'pro_annual';

const _kProductIds = {kIapMonthly, kIapAnnual};

// ─────────────────────────────────────────────────────────────────────────────
// Infraestrutura
// ─────────────────────────────────────────────────────────────────────────────

final subscriptionDataSourceProvider =
    Provider<SubscriptionRemoteDataSource>((ref) {
  return SubscriptionRemoteDataSourceImpl(ref.watch(firestoreProvider));
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepositoryImpl(ref.watch(subscriptionDataSourceProvider));
});

final watchSubscriptionUseCaseProvider = Provider((ref) {
  return WatchSubscriptionUseCase(ref.watch(subscriptionRepositoryProvider));
});

final saveSubscriptionUseCaseProvider = Provider((ref) {
  return SaveSubscriptionUseCase(ref.watch(subscriptionRepositoryProvider));
});

// ─────────────────────────────────────────────────────────────────────────────
// Stream do Firestore — fonte de verdade
// ─────────────────────────────────────────────────────────────────────────────

final subscriptionStreamProvider = StreamProvider<SubscriptionEntity>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(SubscriptionEntity.none());
      return ref
          .watch(watchSubscriptionUseCaseProvider)
          .call(userId: user.id);
    },
    loading: () => Stream.value(SubscriptionEntity.none()),
    error: (_, __) => Stream.value(SubscriptionEntity.none()),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// GATE CENTRAL — bool síncrono, padrão false (seguro para free)
// ─────────────────────────────────────────────────────────────────────────────

final isProProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionStreamProvider).whenOrNull(
        data: (entity) => entity.isActive,
      ) ??
      false;
});

/// True enquanto o status de assinatura ainda está sendo buscado no Firestore.
/// Usado pelos gates para não bloquear usuários Pro antes do carregamento terminar.
final isSubscriptionLoadingProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionStreamProvider).isLoading;
});

// ─────────────────────────────────────────────────────────────────────────────
// Gate de carteiras (free = máx 1 carteira seedada)
// ─────────────────────────────────────────────────────────────────────────────

final canAddWalletProvider = Provider<bool>((ref) {
  if (ref.watch(isProProvider)) return true;
  final wallets = ref.watch(walletsStreamProvider).value ?? [];
  return wallets.isEmpty;
});

// ─────────────────────────────────────────────────────────────────────────────
// Estado do IAP
// ─────────────────────────────────────────────────────────────────────────────

class IAPState {
  final bool isLoading;
  final bool isAvailable;
  final List<ProductDetails> products;
  final String? errorMessage;
  final bool purchaseSuccess;

  const IAPState({
    this.isLoading = false,
    this.isAvailable = false,
    this.products = const [],
    this.errorMessage,
    this.purchaseSuccess = false,
  });

  IAPState copyWith({
    bool? isLoading,
    bool? isAvailable,
    List<ProductDetails>? products,
    String? errorMessage,
    bool? purchaseSuccess,
    bool clearError = false,
  }) {
    return IAPState(
      isLoading: isLoading ?? this.isLoading,
      isAvailable: isAvailable ?? this.isAvailable,
      products: products ?? this.products,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      purchaseSuccess: purchaseSuccess ?? this.purchaseSuccess,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IAPNotifier — gerencia todo o ciclo de vida das compras
// ─────────────────────────────────────────────────────────────────────────────

class IAPNotifier extends StateNotifier<IAPState> {
  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  IAPNotifier(this._ref) : super(const IAPState());

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    if (kIsWeb) return;
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);

    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      state = state.copyWith(isLoading: false, isAvailable: false);
      return;
    }

    // Escuta atualizações de compras
    _purchaseSub?.cancel();
    _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (e) =>
          state = state.copyWith(errorMessage: e.toString(), isLoading: false),
    );

    // Busca detalhes dos produtos
    final response =
        await InAppPurchase.instance.queryProductDetails(_kProductIds);
    assert(() {
      debugPrint('[IAP] encontrados: ${response.productDetails.map((p) => p.id).toList()}');
      debugPrint('[IAP] não encontrados: ${response.notFoundIDs}');
      debugPrint('[IAP] erro: ${response.error}');
      return true;
    }());
    state = state.copyWith(
      isLoading: false,
      isAvailable: true,
      products: response.productDetails,
    );

    // Restaura compras existentes para sincronizar
    await InAppPurchase.instance.restorePurchases();
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        state = state.copyWith(isLoading: true);
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _verifyAndSave(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: purchase.error?.message ?? 'Erro ao processar compra.',
        );
      }

      if (purchase.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyAndSave(PurchaseDetails purchase) async {
    final userId = _ref.read(authStateProvider).value?.id;
    if (userId == null) return;

    final type = _productIdToType(purchase.productID);
    final expiryDate = _computeExpiry(type);

    final entity = SubscriptionEntity(
      type: type,
      status: SubscriptionStatus.active,
      purchaseToken: purchase.verificationData.serverVerificationData,
      productId: purchase.productID,
      expiryDate: expiryDate,
      updatedAt: DateTime.now(),
    );

    await _ref
        .read(saveSubscriptionUseCaseProvider)
        .call(userId: userId, entity: entity);

    state = state.copyWith(isLoading: false, purchaseSuccess: true);
  }

  static SubscriptionType _productIdToType(String productId) {
    switch (productId) {
      case kIapMonthly:
        return SubscriptionType.monthly;
      case kIapAnnual:
        return SubscriptionType.annual;
      default:
        return SubscriptionType.none;
    }
  }

  static DateTime? _computeExpiry(SubscriptionType type) {
    final now = DateTime.now();
    switch (type) {
      case SubscriptionType.monthly:
        return now.add(const Duration(days: 32));
      case SubscriptionType.annual:
        return now.add(const Duration(days: 366));
      default:
        return null;
    }
  }

  Future<void> buyMonthly() => _buy(kIapMonthly);
  Future<void> buyAnnual() => _buy(kIapAnnual);

  Future<void> _buy(String productId) async {
    if (kIsWeb) {
      state = state.copyWith(
          errorMessage: 'Compras não disponíveis na versão web.');
      return;
    }
    final product =
        state.products.where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      state = state.copyWith(
          errorMessage: 'Produto não encontrado. Tente novamente.');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final PurchaseParam param;
      if (!kIsWeb && Platform.isAndroid) {
        // Google Play Billing v5+: assinaturas requerem GooglePlayPurchaseParam
        // com o offerToken do plano base da assinatura.
        final googleProduct = product as GooglePlayProductDetails;
        final offerToken = googleProduct.offerToken;
        if (offerToken == null) {
          state = state.copyWith(
            isLoading: false,
            errorMessage:
                'Plano de assinatura não configurado na Play Store. '
                'Certifique-se de que o produto tem um plano base ativo.',
          );
          return;
        }
        param = GooglePlayPurchaseParam(
          productDetails: googleProduct,
          offerToken: offerToken,
        );
      } else {
        param = PurchaseParam(productDetails: product);
      }
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Não foi possível iniciar a compra.',
      );
    }
  }

  Future<void> restorePurchases() async {
    if (kIsWeb) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erro ao restaurar compras.',
      );
    }
  }
}

final iapNotifierProvider =
    StateNotifierProvider<IAPNotifier, IAPState>((ref) {
  return IAPNotifier(ref);
});

// ─────────────────────────────────────────────────────────────────────────────
// Provider de inicialização — watched no MainScreen junto com seeds
// ─────────────────────────────────────────────────────────────────────────────

final iapInitProvider = Provider<void>((ref) {
  ref.listen<AsyncValue>(
    authStateProvider,
    (_, next) {
      next.whenData((user) {
        if (user != null) {
          ref.read(iapNotifierProvider.notifier).initialize();
        }
      });
    },
    fireImmediately: true,
  );
});
