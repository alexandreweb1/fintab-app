import 'package:equatable/equatable.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';

enum RecurrenceFrequency { daily, weekly, monthly, yearly }

class RecurringTransactionEntity extends Equatable {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final String? description;
  final String walletId;

  /// How often the transaction repeats.
  final RecurrenceFrequency frequency;

  /// Day of the month (1-31) for monthly recurrences.
  /// Day of the week (1-7, Mon=1) for weekly recurrences.
  final int dayOfRecurrence;

  /// When this recurrence starts generating transactions.
  final DateTime startDate;

  /// Optional end date — null means it repeats indefinitely.
  final DateTime? endDate;

  /// Whether this recurrence is active.
  final bool isActive;

  /// The last date a transaction was automatically generated.
  /// Null if no transaction has been generated yet.
  final DateTime? lastGeneratedDate;

  final DateTime createdAt;

  const RecurringTransactionEntity({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    this.description,
    this.walletId = '',
    required this.frequency,
    required this.dayOfRecurrence,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.lastGeneratedDate,
    required this.createdAt,
  });

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;

  /// Calculates the next occurrence date after [afterDate].
  DateTime? nextOccurrence({DateTime? afterDate}) {
    final after = afterDate ?? lastGeneratedDate ?? startDate.subtract(const Duration(days: 1));

    DateTime next;
    switch (frequency) {
      case RecurrenceFrequency.daily:
        next = DateTime(after.year, after.month, after.day + 1);
      case RecurrenceFrequency.weekly:
        // Find next occurrence of the target weekday
        final daysUntil = (dayOfRecurrence - after.weekday) % 7;
        next = DateTime(after.year, after.month, after.day + (daysUntil == 0 ? 7 : daysUntil));
      case RecurrenceFrequency.monthly:
        // Next month on the specified day
        int nextMonth = after.month + 1;
        int nextYear = after.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        final day = dayOfRecurrence.clamp(1, _daysInMonth(nextYear, nextMonth));
        next = DateTime(nextYear, nextMonth, day);
        // If we're still before the day this month, use this month
        final thisMonthDay = dayOfRecurrence.clamp(1, _daysInMonth(after.year, after.month));
        final thisMonth = DateTime(after.year, after.month, thisMonthDay);
        if (thisMonth.isAfter(after)) next = thisMonth;
      case RecurrenceFrequency.yearly:
        next = DateTime(after.year + 1, startDate.month, startDate.day);
        final thisYear = DateTime(after.year, startDate.month, startDate.day);
        if (thisYear.isAfter(after)) next = thisYear;
    }

    if (next.isBefore(startDate)) next = startDate;
    if (endDate != null && next.isAfter(endDate!)) return null;
    return next;
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  RecurringTransactionEntity copyWith({
    String? title,
    double? amount,
    TransactionType? type,
    String? category,
    String? description,
    String? walletId,
    RecurrenceFrequency? frequency,
    int? dayOfRecurrence,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? lastGeneratedDate,
  }) {
    return RecurringTransactionEntity(
      id: id,
      userId: userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      walletId: walletId ?? this.walletId,
      frequency: frequency ?? this.frequency,
      dayOfRecurrence: dayOfRecurrence ?? this.dayOfRecurrence,
      startDate: startDate ?? this.startDate,
      endDate: endDate,
      isActive: isActive ?? this.isActive,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id, userId, title, amount, type, category, description, walletId,
        frequency, dayOfRecurrence, startDate, endDate, isActive,
        lastGeneratedDate, createdAt,
      ];
}
