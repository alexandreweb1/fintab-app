import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/providers/effective_user_provider.dart';
import '../../../../core/providers/selected_month_provider.dart';
import '../../../../core/providers/workspace_provider.dart';
import '../../data/datasources/transaction_remote_datasource.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import '../../domain/usecases/delete_transaction_usecase.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/update_transaction_usecase.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// --- Infrastructure ---

final transactionDataSourceProvider = Provider<TransactionRemoteDataSource>(
  (ref) => TransactionRemoteDataSourceImpl(ref.watch(firestoreProvider)),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepositoryImpl(ref.watch(transactionDataSourceProvider)),
);

// --- Use Cases ---

final getTransactionsUseCaseProvider = Provider(
  (ref) => GetTransactionsUseCase(ref.watch(transactionRepositoryProvider)),
);

final addTransactionUseCaseProvider = Provider(
  (ref) => AddTransactionUseCase(ref.watch(transactionRepositoryProvider)),
);

final deleteTransactionUseCaseProvider = Provider(
  (ref) => DeleteTransactionUseCase(ref.watch(transactionRepositoryProvider)),
);

final updateTransactionUseCaseProvider = Provider(
  (ref) => UpdateTransactionUseCase(ref.watch(transactionRepositoryProvider)),
);

// --- Stream Providers ---

final transactionsStreamProvider =
    StreamProvider<List<TransactionEntity>>((ref) {
  final scope = ref.watch(activeLedgerScopeProvider);

  // New-style shared member: server-side query by workspaceId.
  if (scope is MemberScope) {
    return workspaceCollectionQuery(
            ref.watch(firestoreProvider), 'transactions', scope.workspaceId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map(TransactionModel.fromFirestore)
          .cast<TransactionEntity>()
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  final authState = ref.watch(authStateProvider);
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  return authState.when(
    data: (user) {
      if (user == null || effectiveUserId.isEmpty) return const Stream.empty();
      return ref
          .watch(getTransactionsUseCaseProvider)
          .call(GetTransactionsParams(userId: effectiveUserId))
          .map((either) => either.getOrElse(() => []))
          .map((list) =>
              applyWorkspaceScope(list, (t) => t.workspaceId, scope));
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// --- Selected month (shared across all tabs) ---

// ignore: non_constant_identifier_names
final transactionsSelectedMonthProvider = selectedMonthProvider;

// --- Visible transactions (excludes transactions from hidden wallets) ---

final visibleTransactionsProvider = Provider<List<TransactionEntity>>((ref) {
  final all = ref.watch(transactionsStreamProvider).value ?? [];
  final hidden = ref.watch(appSettingsProvider).hiddenWalletIds;
  if (hidden.isEmpty) return all;
  return all.where((t) => !hidden.contains(t.walletId)).toList();
});

// --- All-time summary (used by dashboard balance) ---

/// Total balance across all wallets. Transfers between user wallets
/// (sourceWalletId set) are net-zero. External aportes (sourceWalletId == null)
/// add to the total.
final balanceProvider = Provider<double>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  double total = 0;
  for (final t in transactions) {
    if (t.isIncome) {
      total += t.amount;
    } else if (t.isExpense) {
      total -= t.amount;
    } else if (t.isTransfer && t.sourceWalletId == null) {
      total += t.amount;
    }
  }
  return total;
});

final totalIncomeProvider = Provider<double>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  return transactions
      .where((t) => t.isIncome)
      .fold(0.0, (sum, t) => sum + t.amount);
});

final totalExpenseProvider = Provider<double>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  return transactions
      .where((t) => t.isExpense)
      .fold(0.0, (sum, t) => sum + t.amount);
});

// --- Per-month summary for the statement screen ---

final statementMonthIncomeProvider = Provider<double>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  final month = ref.watch(transactionsSelectedMonthProvider);
  return transactions
      .where((t) =>
          t.isIncome &&
          t.date.year == month.year &&
          t.date.month == month.month)
      .fold(0.0, (sum, t) => sum + t.amount);
});

final statementMonthExpenseProvider = Provider<double>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  final month = ref.watch(transactionsSelectedMonthProvider);
  return transactions
      .where((t) =>
          t.isExpense &&
          t.date.year == month.year &&
          t.date.month == month.month)
      .fold(0.0, (sum, t) => sum + t.amount);
});

final statementMonthTransactionsProvider =
    Provider<List<TransactionEntity>>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  final month = ref.watch(transactionsSelectedMonthProvider);
  return transactions
      .where((t) =>
          t.date.year == month.year && t.date.month == month.month)
      .toList();
});

// --- Type filter for statement (null = show all) ---

final statementTypeFilterProvider = StateProvider<TransactionType?>(
  (ref) => null,
);

// --- Custom date range for statement – PRO feature ---
// Stored as (startDate, endDate); null = not active.
final statementDateRangeProvider = StateProvider<(DateTime, DateTime)?>(
  (ref) => null,
);

// --- Advanced filters ---

/// Set of category names to show. Empty = all categories.
final statementCategoryFilterProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

/// Set of wallet IDs to show. Empty = all wallets.
final statementWalletFilterProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

/// Minimum transaction amount. Null = no minimum.
final statementMinAmountFilterProvider = StateProvider<double?>((ref) => null);

/// Maximum transaction amount. Null = no maximum.
final statementMaxAmountFilterProvider = StateProvider<double?>((ref) => null);

/// Set of tags to show. Empty = all tags.
final statementTagFilterProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

/// All unique tags across all transactions (for filter UI).
final allTagsProvider = Provider<List<String>>((ref) {
  final txs = ref.watch(visibleTransactionsProvider);
  final tags = <String>{};
  for (final t in txs) {
    tags.addAll(t.tags);
  }
  final list = tags.toList()..sort();
  return list;
});

/// Count of currently active filters.
final statementActiveFilterCountProvider = Provider<int>((ref) {
  int n = 0;
  if (ref.watch(statementTypeFilterProvider) != null) n++;
  if (ref.watch(statementCategoryFilterProvider).isNotEmpty) n++;
  if (ref.watch(statementWalletFilterProvider).isNotEmpty) n++;
  if (ref.watch(statementMinAmountFilterProvider) != null) n++;
  if (ref.watch(statementMaxAmountFilterProvider) != null) n++;
  if (ref.watch(statementTagFilterProvider).isNotEmpty) n++;
  return n;
});

/// Whether any filter is currently active.
final statementHasFiltersProvider = Provider<bool>(
  (ref) => ref.watch(statementActiveFilterCountProvider) > 0,
);

/// Search query for filtering transactions by title.
final statementSearchQueryProvider = StateProvider<String>((ref) => '');

// --- Display providers: respects date range + type + advanced filters ---

final statementDisplayTransactionsProvider =
    Provider<List<TransactionEntity>>((ref) {
  final isAnnual = ref.watch(statementIsAnnualProvider);
  final typeFilter = ref.watch(statementTypeFilterProvider);
  final dateRange = ref.watch(statementDateRangeProvider);
  final categoryFilter = ref.watch(statementCategoryFilterProvider);
  final walletFilter = ref.watch(statementWalletFilterProvider);
  final minAmount = ref.watch(statementMinAmountFilterProvider);
  final maxAmount = ref.watch(statementMaxAmountFilterProvider);
  final searchQuery = ref.watch(statementSearchQueryProvider);
  final tagFilter = ref.watch(statementTagFilterProvider);

  List<TransactionEntity> txs;
  if (dateRange != null) {
    final (start, end) = dateRange;
    final endInclusive = DateTime(end.year, end.month, end.day, 23, 59, 59);
    txs = ref
        .watch(visibleTransactionsProvider)
        .where((t) =>
            !t.date.isBefore(start) && !t.date.isAfter(endInclusive))
        .toList();
  } else if (isAnnual) {
    txs = ref.watch(statementAnnualTransactionsProvider);
  } else {
    txs = ref.watch(statementMonthTransactionsProvider);
  }

  if (typeFilter != null) {
    txs = txs.where((t) => t.type == typeFilter).toList();
  }
  if (categoryFilter.isNotEmpty) {
    txs = txs.where((t) => categoryFilter.contains(t.category)).toList();
  }
  if (walletFilter.isNotEmpty) {
    txs = txs.where((t) => walletFilter.contains(t.walletId)).toList();
  }
  if (minAmount != null) {
    txs = txs.where((t) => t.amount >= minAmount).toList();
  }
  if (maxAmount != null) {
    txs = txs.where((t) => t.amount <= maxAmount).toList();
  }
  if (searchQuery.isNotEmpty) {
    final q = searchQuery.toLowerCase();
    txs = txs.where((t) => t.title.toLowerCase().contains(q)).toList();
  }
  if (tagFilter.isNotEmpty) {
    txs = txs.where((t) => t.tags.any((tag) => tagFilter.contains(tag))).toList();
  }
  return txs;
});

final statementDisplayIncomeProvider = Provider<double>((ref) {
  final dateRange = ref.watch(statementDateRangeProvider);
  if (dateRange != null) {
    final (start, end) = dateRange;
    final endInclusive = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return ref
        .watch(visibleTransactionsProvider)
        .where((t) =>
            t.isIncome &&
            !t.date.isBefore(start) &&
            !t.date.isAfter(endInclusive))
        .fold(0.0, (sum, t) => sum + t.amount);
  }
  final isAnnual = ref.watch(statementIsAnnualProvider);
  return isAnnual
      ? ref.watch(statementAnnualIncomeProvider)
      : ref.watch(statementMonthIncomeProvider);
});

final statementDisplayExpenseProvider = Provider<double>((ref) {
  final dateRange = ref.watch(statementDateRangeProvider);
  if (dateRange != null) {
    final (start, end) = dateRange;
    final endInclusive = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return ref
        .watch(visibleTransactionsProvider)
        .where((t) =>
            t.isExpense &&
            !t.date.isBefore(start) &&
            !t.date.isAfter(endInclusive))
        .fold(0.0, (sum, t) => sum + t.amount);
  }
  final isAnnual = ref.watch(statementIsAnnualProvider);
  return isAnnual
      ? ref.watch(statementAnnualExpenseProvider)
      : ref.watch(statementMonthExpenseProvider);
});

// --- Annual toggle ---

final statementIsAnnualProvider = StateProvider<bool>((ref) => false);

final statementAnnualTransactionsProvider =
    Provider<List<TransactionEntity>>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  final month = ref.watch(transactionsSelectedMonthProvider);
  return transactions
      .where((t) => t.date.year == month.year)
      .toList();
});

final statementAnnualIncomeProvider = Provider<double>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  final month = ref.watch(transactionsSelectedMonthProvider);
  return transactions
      .where((t) => t.isIncome && t.date.year == month.year)
      .fold(0.0, (sum, t) => sum + t.amount);
});

final statementAnnualExpenseProvider = Provider<double>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  final month = ref.watch(transactionsSelectedMonthProvider);
  return transactions
      .where((t) => t.isExpense && t.date.year == month.year)
      .fold(0.0, (sum, t) => sum + t.amount);
});

/// Expenses for the current calendar month (uses DateTime.now(), not the selected statement month).
final currentCalendarMonthExpenseProvider = Provider<double>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  final now = DateTime.now();
  return transactions
      .where((t) =>
          t.isExpense && t.date.year == now.year && t.date.month == now.month)
      .fold(0.0, (sum, t) => sum + t.amount);
});

/// Expenses for the previous calendar month (uses DateTime.now(), not the selected statement month).
final previousCalendarMonthExpenseProvider = Provider<double>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  final now = DateTime.now();
  final prevYear = now.month == 1 ? now.year - 1 : now.year;
  final prevMonth = now.month == 1 ? 12 : now.month - 1;
  return transactions
      .where((t) =>
          t.isExpense && t.date.year == prevYear && t.date.month == prevMonth)
      .fold(0.0, (sum, t) => sum + t.amount);
});

/// All-time balance per wallet ID, ignoring the hidden-wallets filter.
/// Used in the Reservas/Investimentos tabs so each bucket keeps showing its
/// real balance even when the user has hidden the wallet from totals/charts.
final walletAllBalancesProvider = Provider<Map<String, double>>((ref) {
  final transactions = ref.watch(transactionsStreamProvider).value ?? const [];
  final Map<String, double> balances = {};
  for (final t in transactions) {
    if (t.isIncome) {
      balances[t.walletId] = (balances[t.walletId] ?? 0) + t.amount;
    } else if (t.isExpense) {
      balances[t.walletId] = (balances[t.walletId] ?? 0) - t.amount;
    } else if (t.isTransfer) {
      balances[t.walletId] = (balances[t.walletId] ?? 0) + t.amount;
      final src = t.sourceWalletId;
      if (src != null) {
        balances[src] = (balances[src] ?? 0) - t.amount;
      }
    }
  }
  return balances;
});

/// All-time balance per wallet ID (key '' = transactions without wallet / "Geral").
/// Transfers add to the destination [walletId] and subtract from [sourceWalletId]
/// when present.
final walletBalancesProvider = Provider<Map<String, double>>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  final Map<String, double> balances = {};
  for (final t in transactions) {
    if (t.isIncome) {
      balances[t.walletId] = (balances[t.walletId] ?? 0) + t.amount;
    } else if (t.isExpense) {
      balances[t.walletId] = (balances[t.walletId] ?? 0) - t.amount;
    } else if (t.isTransfer) {
      balances[t.walletId] = (balances[t.walletId] ?? 0) + t.amount;
      final src = t.sourceWalletId;
      if (src != null) {
        balances[src] = (balances[src] ?? 0) - t.amount;
      }
    }
  }
  return balances;
});

// --- Notifier for mutations ---

class TransactionsNotifier extends StateNotifier<AsyncValue<void>> {
  final AddTransactionUseCase _addTransaction;
  final DeleteTransactionUseCase _deleteTransaction;
  final UpdateTransactionUseCase _updateTransaction;
  final String _userId;
  final String? _workspaceId;

  TransactionsNotifier(
    this._addTransaction,
    this._deleteTransaction,
    this._updateTransaction,
    this._userId,
    this._workspaceId,
  ) : super(const AsyncValue.data(null));

  Future<bool> add({
    required String title,
    required double amount,
    required TransactionType type,
    required String category,
    required DateTime date,
    String? description,
    String walletId = '',
    String? sourceWalletId,
    String? goalId,
    bool isPending = false,
    List<String> tags = const [],
    List<String> attachmentUrls = const [],
  }) async {
    state = const AsyncValue.loading();
    final transaction = TransactionEntity(
      id: const Uuid().v4(),
      userId: _userId,
      workspaceId: _workspaceId,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
      description: description,
      walletId: walletId,
      sourceWalletId: sourceWalletId,
      goalId: goalId,
      isPending: isPending,
      tags: tags,
      attachmentUrls: attachmentUrls,
    );
    final result = await _addTransaction(
        AddTransactionParams(transaction: transaction));
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

  /// Same as [add] but returns the generated transaction id (or null on failure).
  /// Used by the notification auto-save flow to link the backlog item to the
  /// created transaction.
  Future<String?> addAndReturnId({
    required String title,
    required double amount,
    required TransactionType type,
    required String category,
    required DateTime date,
    String? description,
    String walletId = '',
    String? sourceWalletId,
    String? goalId,
    bool isPending = false,
    List<String> tags = const [],
    /// Background capture (bank notifications) passes the user's DEFAULT
    /// workspace + own uid here so captured entries never land in whatever
    /// (possibly shared) Carteira happened to be active on screen.
    String? workspaceIdOverride,
    String? userIdOverride,
  }) async {
    state = const AsyncValue.loading();
    final id = const Uuid().v4();
    final transaction = TransactionEntity(
      id: id,
      userId: userIdOverride ?? _userId,
      workspaceId: workspaceIdOverride ?? _workspaceId,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
      description: description,
      walletId: walletId,
      sourceWalletId: sourceWalletId,
      goalId: goalId,
      isPending: isPending,
      tags: tags,
    );
    final result = await _addTransaction(
        AddTransactionParams(transaction: transaction));
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return null;
      },
      (_) {
        state = const AsyncValue.data(null);
        return id;
      },
    );
  }

  Future<bool> update(TransactionEntity updated) async {
    state = const AsyncValue.loading();
    final result = await _updateTransaction(
        UpdateTransactionParams(transaction: updated));
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

  Future<bool> delete(String transactionId) async {
    state = const AsyncValue.loading();
    final result = await _deleteTransaction(
        DeleteTransactionParams(transactionId: transactionId));
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
}

final transactionsNotifierProvider =
    StateNotifierProvider<TransactionsNotifier, AsyncValue<void>>((ref) {
  final ledgerOwnerId = ref.watch(ledgerOwnerIdProvider);
  return TransactionsNotifier(
    ref.watch(addTransactionUseCaseProvider),
    ref.watch(deleteTransactionUseCaseProvider),
    ref.watch(updateTransactionUseCaseProvider),
    ledgerOwnerId,
    ref.watch(workspaceStampProvider),
  );
});
