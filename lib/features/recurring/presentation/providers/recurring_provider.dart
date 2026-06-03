import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/effective_user_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../transactions/domain/usecases/add_transaction_usecase.dart';
import '../../data/datasources/recurring_transaction_remote_datasource.dart';
import '../../data/repositories/recurring_transaction_repository_impl.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../../domain/repositories/recurring_transaction_repository.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final recurringDataSourceProvider =
    Provider<RecurringTransactionRemoteDataSource>(
  (ref) => RecurringTransactionRemoteDataSourceImpl(
      ref.watch(firestoreProvider)),
);

final recurringRepositoryProvider =
    Provider<RecurringTransactionRepository>(
  (ref) => RecurringTransactionRepositoryImpl(
      ref.watch(recurringDataSourceProvider)),
);

// ── Stream ────────────────────────────────────────────────────────────────────

final recurringStreamProvider =
    StreamProvider<List<RecurringTransactionEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  return authState.when(
    data: (user) {
      if (user == null || effectiveUserId.isEmpty) return const Stream.empty();
      return ref
          .watch(recurringRepositoryProvider)
          .watchAll(userId: effectiveUserId);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// Only active recurrences.
final activeRecurrencesProvider =
    Provider<List<RecurringTransactionEntity>>((ref) {
  final all = ref.watch(recurringStreamProvider).value ?? [];
  return all.where((r) => r.isActive).toList();
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class RecurringNotifier extends StateNotifier<AsyncValue<void>> {
  final RecurringTransactionRepository _repo;
  final String _userId;

  RecurringNotifier(this._repo, this._userId)
      : super(const AsyncValue.data(null));

  Future<bool> add({
    required String title,
    required double amount,
    required TransactionType type,
    required String category,
    String? description,
    String walletId = '',
    required RecurrenceFrequency frequency,
    required int dayOfRecurrence,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      final entity = RecurringTransactionEntity(
        id: const Uuid().v4(),
        userId: _userId,
        title: title,
        amount: amount,
        type: type,
        category: category,
        description: description,
        walletId: walletId,
        frequency: frequency,
        dayOfRecurrence: dayOfRecurrence,
        startDate: startDate,
        endDate: endDate,
        createdAt: DateTime.now(),
      );
      await _repo.add(entity);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> update(RecurringTransactionEntity entity) async {
    state = const AsyncValue.loading();
    try {
      await _repo.update(entity);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> delete(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(id: id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> toggleActive(RecurringTransactionEntity entity) async {
    return update(entity.copyWith(isActive: !entity.isActive));
  }
}

final recurringNotifierProvider =
    StateNotifierProvider<RecurringNotifier, AsyncValue<void>>((ref) {
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  return RecurringNotifier(
    ref.watch(recurringRepositoryProvider),
    effectiveUserId,
  );
});

// ── Auto-generation service ──────────────────────────────────────────────────

/// Provider that generates pending transactions from active recurrences.
/// Call `ref.read(recurringGeneratorProvider)` once at app startup.
final recurringGeneratorProvider = FutureProvider<int>((ref) async {
  final recurrences = ref.watch(activeRecurrencesProvider);
  if (recurrences.isEmpty) return 0;

  final addUseCase = ref.read(addTransactionUseCaseProvider);
  final ds = ref.read(recurringDataSourceProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
  int generated = 0;

  for (final rec in recurrences) {
    DateTime? next = rec.nextOccurrence();
    while (next != null && !next.isAfter(today)) {
      final tx = TransactionEntity(
        id: const Uuid().v4(),
        userId: rec.userId,
        title: rec.title,
        amount: rec.amount,
        type: rec.type,
        category: rec.category,
        date: next,
        description: rec.description,
        walletId: rec.walletId,
      );

      final result = await addUseCase(
        AddTransactionParams(transaction: tx),
      );

      result.fold((_) => null, (_) => generated++);

      await ds.updateLastGenerated(id: rec.id, date: next);
      next = rec.nextOccurrence(afterDate: next);
    }
  }

  return generated;
});
