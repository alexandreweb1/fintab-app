import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/effective_user_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../data/datasources/goal_remote_datasource.dart';
import '../../data/repositories/goal_repository_impl.dart';
import '../../domain/entities/goal_entity.dart';
import '../../domain/repositories/goal_repository.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final goalDataSourceProvider = Provider<GoalRemoteDataSource>(
  (ref) => GoalRemoteDataSourceImpl(ref.watch(firestoreProvider)),
);

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => GoalRepositoryImpl(ref.watch(goalDataSourceProvider)),
);

// ── Stream ────────────────────────────────────────────────────────────────────

final goalsStreamProvider = StreamProvider<List<GoalEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  return authState.when(
    data: (user) {
      if (user == null || effectiveUserId.isEmpty) return const Stream.empty();
      return ref
          .watch(goalRepositoryProvider)
          .watchGoals(userId: effectiveUserId);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ── Progress (currentAmount derived from transactions) ────────────────────────

/// Returns a map of goalId → currentAmount (sum of transactions linked to goal)
final goalProgressMapProvider = Provider<Map<String, double>>((ref) {
  final transactions = ref.watch(transactionsStreamProvider).value ?? [];
  final Map<String, double> map = {};
  for (final t in transactions) {
    final gid = t.goalId;
    if (gid != null && gid.isNotEmpty) {
      map[gid] = (map[gid] ?? 0) + t.amount;
    }
  }
  return map;
});

/// Returns current accumulated amount for a specific goal
final goalCurrentAmountProvider =
    Provider.family<double, String>((ref, goalId) {
  return ref.watch(goalProgressMapProvider)[goalId] ?? 0;
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class GoalsNotifier extends StateNotifier<AsyncValue<void>> {
  final GoalRepository _repo;
  final String _userId;

  GoalsNotifier(this._repo, this._userId) : super(const AsyncValue.data(null));

  Future<bool> add({
    required String title,
    required double targetAmount,
    DateTime? deadline,
    required int iconCodePoint,
    required int colorValue,
  }) async {
    state = const AsyncValue.loading();
    try {
      final goal = GoalEntity(
        id: const Uuid().v4(),
        userId: _userId,
        title: title,
        targetAmount: targetAmount,
        deadline: deadline,
        iconCodePoint: iconCodePoint,
        colorValue: colorValue,
        createdAt: DateTime.now(),
      );
      await _repo.addGoal(goal);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> update(GoalEntity goal) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateGoal(goal);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> delete(String goalId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteGoal(goalId: goalId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final goalsNotifierProvider =
    StateNotifierProvider<GoalsNotifier, AsyncValue<void>>((ref) {
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  return GoalsNotifier(
    ref.watch(goalRepositoryProvider),
    effectiveUserId,
  );
});
