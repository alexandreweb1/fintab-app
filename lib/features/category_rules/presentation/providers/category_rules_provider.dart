import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/effective_user_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../data/datasources/category_rule_remote_datasource.dart';
import '../../data/repositories/category_rule_repository_impl.dart';
import '../../domain/entities/category_rule_entity.dart';
import '../../domain/repositories/category_rule_repository.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final categoryRuleDataSourceProvider =
    Provider<CategoryRuleRemoteDataSource>(
  (ref) => CategoryRuleRemoteDataSourceImpl(ref.watch(firestoreProvider)),
);

final categoryRuleRepositoryProvider = Provider<CategoryRuleRepository>(
  (ref) => CategoryRuleRepositoryImpl(ref.watch(categoryRuleDataSourceProvider)),
);

// ── Stream ────────────────────────────────────────────────────────────────────

final categoryRulesStreamProvider =
    StreamProvider<List<CategoryRuleEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  return authState.when(
    data: (user) {
      if (user == null || effectiveUserId.isEmpty) return const Stream.empty();
      return ref
          .watch(categoryRuleRepositoryProvider)
          .watchRules(userId: effectiveUserId);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// Synchronous view of the user's rules. Safe to read from event/timer
/// callbacks (the add-transaction dialog and the notification auto-save path).
final categoryRulesProvider = Provider<List<CategoryRuleEntity>>((ref) {
  return ref.watch(categoryRulesStreamProvider).value ?? const [];
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class CategoryRulesNotifier extends StateNotifier<AsyncValue<void>> {
  final CategoryRuleRepository _repo;
  final String _userId;

  CategoryRulesNotifier(this._repo, this._userId)
      : super(const AsyncValue.data(null));

  Future<bool> add({
    required String keyword,
    required String categoryName,
    TransactionType? type,
  }) async {
    state = const AsyncValue.loading();
    try {
      final rule = CategoryRuleEntity(
        id: const Uuid().v4(),
        userId: _userId,
        keyword: keyword.trim(),
        categoryName: categoryName,
        type: type,
        createdAt: DateTime.now(),
      );
      await _repo.addRule(rule);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> update(CategoryRuleEntity rule) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateRule(rule);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> delete(String ruleId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteRule(ruleId: ruleId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final categoryRulesNotifierProvider =
    StateNotifierProvider<CategoryRulesNotifier, AsyncValue<void>>((ref) {
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  return CategoryRulesNotifier(
    ref.watch(categoryRuleRepositoryProvider),
    effectiveUserId,
  );
});
