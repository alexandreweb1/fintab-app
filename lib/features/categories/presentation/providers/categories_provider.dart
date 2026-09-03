import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/providers/workspace_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../data/datasources/category_remote_datasource.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/usecases/add_category_usecase.dart';
import '../../domain/usecases/delete_category_usecase.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../../domain/usecases/update_category_usecase.dart';

// --- Infrastructure ---

final categoryDataSourceProvider = Provider<CategoryRemoteDataSource>(
  (ref) => CategoryRemoteDataSourceImpl(ref.watch(firestoreProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) =>
      CategoryRepositoryImpl(ref.watch(categoryDataSourceProvider)),
);

// --- Use Cases ---

final getCategoriesUseCaseProvider = Provider(
  (ref) => GetCategoriesUseCase(ref.watch(categoryRepositoryProvider)),
);

final addCategoryUseCaseProvider = Provider(
  (ref) => AddCategoryUseCase(ref.watch(categoryRepositoryProvider)),
);

final updateCategoryUseCaseProvider = Provider(
  (ref) => UpdateCategoryUseCase(ref.watch(categoryRepositoryProvider)),
);

final deleteCategoryUseCaseProvider = Provider(
  (ref) => DeleteCategoryUseCase(ref.watch(categoryRepositoryProvider)),
);

// --- Stream Provider ---

final categoriesStreamProvider =
    StreamProvider<List<CategoryEntity>>((ref) {
  final scope = ref.watch(activeLedgerScopeProvider);

  // New-style shared member: query the workspace server-side (authorized by
  // workspace membership, not by userId).
  if (scope is MemberScope) {
    return workspaceCollectionQuery(
            ref.watch(firestoreProvider), 'categories', scope.workspaceId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => CategoryModel.fromFirestore(doc) as CategoryEntity)
          .toList();
      // Replicates the datasource's orderBy('name').
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  final authState = ref.watch(authStateProvider);
  final effectiveUserId = ref.watch(ledgerQueryUserIdProvider);
  return authState.when(
    data: (user) {
      if (user == null || effectiveUserId.isEmpty) return const Stream.empty();
      return ref
          .watch(getCategoriesUseCaseProvider)
          .call(GetCategoriesParams(userId: effectiveUserId))
          .map((either) => applyWorkspaceScope(
              either.getOrElse(() => []), (c) => c.workspaceId, scope));
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// --- Usage counts (for the "mais usadas" sort mode) ---

/// How many times each category name has been used, split by transaction type.
/// Drives the [CategorySortMode.mostUsed] ordering. Income and expense are kept
/// apart because a name like "Outros" exists in both and must not be conflated.
final categoryUsageCountsProvider =
    Provider<({Map<String, int> income, Map<String, int> expense})>((ref) {
  final transactions = ref.watch(transactionsStreamProvider).value ?? const [];
  final income = <String, int>{};
  final expense = <String, int>{};
  for (final t in transactions) {
    if (t.isIncome) {
      income[t.category] = (income[t.category] ?? 0) + 1;
    } else if (t.isExpense) {
      expense[t.category] = (expense[t.category] ?? 0) + 1;
    }
  }
  return (income: income, expense: expense);
});

/// Orders [categories] according to [mode]. For [CategorySortMode.mostUsed] the
/// primary key is the usage count (desc) with an alphabetical tie-break, so
/// categories the user never touched still come out in a predictable order.
List<CategoryEntity> sortCategoriesByMode(
  List<CategoryEntity> categories,
  CategorySortMode mode,
  Map<String, int> usageCounts,
) {
  int byName(CategoryEntity a, CategoryEntity b) =>
      a.name.toLowerCase().trim().compareTo(b.name.toLowerCase().trim());

  final sorted = [...categories];
  if (mode == CategorySortMode.mostUsed) {
    sorted.sort((a, b) {
      final ua = usageCounts[a.name] ?? 0;
      final ub = usageCounts[b.name] ?? 0;
      if (ua != ub) return ub.compareTo(ua);
      return byName(a, b);
    });
  } else {
    sorted.sort(byName);
  }
  return sorted;
}

// --- Filtered Providers ---

final incomeCategoriesProvider = Provider<List<CategoryEntity>>((ref) {
  final all = ref
          .watch(categoriesStreamProvider)
          .value
          ?.where((c) => c.isIncome)
          .toList() ??
      [];
  final mode = ref.watch(appSettingsProvider).categorySortMode;
  final usage = mode == CategorySortMode.mostUsed
      ? ref.watch(categoryUsageCountsProvider).income
      : const <String, int>{};
  return sortCategoriesByMode(all, mode, usage);
});

final expenseCategoriesProvider = Provider<List<CategoryEntity>>((ref) {
  final all = ref
          .watch(categoriesStreamProvider)
          .value
          ?.where((c) => c.isExpense)
          .toList() ??
      [];
  final mode = ref.watch(appSettingsProvider).categorySortMode;
  final usage = mode == CategorySortMode.mostUsed
      ? ref.watch(categoryUsageCountsProvider).expense
      : const <String, int>{};
  return sortCategoriesByMode(all, mode, usage);
});

// --- Seed initializer (activate in MainScreen) ---

final categoriesSeedProvider = Provider<void>((ref) {
  // Only the owner path seeds defaults — a shared-in member must never seed
  // categories into someone else's workspace.
  final scope = ref.watch(activeLedgerScopeProvider);
  if (scope is! UserScope) return;
  final effectiveUserId = ref.watch(ledgerQueryUserIdProvider);
  ref.listen<AsyncValue<List<CategoryEntity>>>(
    categoriesStreamProvider,
    (_, next) {
      next.whenData((categories) {
        if (categories.isEmpty && effectiveUserId.isNotEmpty) {
          ref.read(categoriesNotifierProvider.notifier).seedDefaults(effectiveUserId);
        }
      });
    },
  );
});

// --- Notifier ---

class CategoriesNotifier extends StateNotifier<AsyncValue<void>> {
  final AddCategoryUseCase _addCategory;
  final UpdateCategoryUseCase _updateCategory;
  final DeleteCategoryUseCase _deleteCategory;
  final CategoryRepository _repository;
  final String? _workspaceId;

  CategoriesNotifier(
    this._addCategory,
    this._updateCategory,
    this._deleteCategory,
    this._repository,
    this._workspaceId,
  ) : super(const AsyncValue.data(null));

  Future<bool> add({
    required String userId,
    required String name,
    required CategoryType type,
    required int iconCodePoint,
    required int colorValue,
  }) async {
    state = const AsyncValue.loading();
    final category = CategoryEntity(
      id: const Uuid().v4(),
      userId: userId,
      workspaceId: _workspaceId,
      name: name,
      type: type,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
    );
    final result = await _addCategory(AddCategoryParams(category: category));
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

  Future<bool> update(CategoryEntity category) async {
    state = const AsyncValue.loading();
    final result =
        await _updateCategory(UpdateCategoryParams(category: category));
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

  Future<bool> delete(String categoryId) async {
    state = const AsyncValue.loading();
    final result =
        await _deleteCategory(DeleteCategoryParams(categoryId: categoryId));
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
    final result =
        await _repository.seedDefaults(userId, workspaceId: _workspaceId);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (_) => state = const AsyncValue.data(null),
    );
  }
}

final categoriesNotifierProvider =
    StateNotifierProvider<CategoriesNotifier, AsyncValue<void>>((ref) {
  return CategoriesNotifier(
    ref.watch(addCategoryUseCaseProvider),
    ref.watch(updateCategoryUseCaseProvider),
    ref.watch(deleteCategoryUseCaseProvider),
    ref.watch(categoryRepositoryProvider),
    ref.watch(workspaceStampProvider),
  );
});
