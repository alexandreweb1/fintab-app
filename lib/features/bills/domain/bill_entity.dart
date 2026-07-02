import 'package:equatable/equatable.dart';

/// A bill to pay (payable) or to receive (receivable) with a due date.
enum BillType {
  payable,
  receivable;

  String get id => name;

  static BillType fromId(String? id) =>
      id == 'receivable' ? BillType.receivable : BillType.payable;
}

class BillEntity extends Equatable {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final DateTime dueDate;
  final BillType type;
  final String category;
  final String walletId;
  final bool isPaid;
  final DateTime? paidDate;

  /// Days before [dueDate] to fire a local reminder. 0 = no reminder.
  final int reminderDaysBefore;

  /// When true, marking it paid auto-creates next month's bill.
  final bool repeatMonthly;

  /// The transaction created when the bill was settled (for unlinking/audit).
  final String? transactionId;

  final DateTime createdAt;

  const BillEntity({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.type = BillType.payable,
    this.category = 'Contas',
    this.walletId = '',
    this.isPaid = false,
    this.paidDate,
    this.reminderDaysBefore = 1,
    this.repeatMonthly = false,
    this.transactionId,
    required this.createdAt,
  });

  bool get isReceivable => type == BillType.receivable;
  bool get isPayable => type == BillType.payable;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Whole days from [now] to the due date (negative when overdue).
  int daysUntilDue([DateTime? now]) =>
      _dateOnly(dueDate).difference(_dateOnly(now ?? DateTime.now())).inDays;

  /// Unpaid and past its due date.
  bool isOverdue([DateTime? now]) => !isPaid && daysUntilDue(now) < 0;

  /// Unpaid and due within [days] days (inclusive), not overdue.
  bool isDueSoon(int days, [DateTime? now]) {
    if (isPaid) return false;
    final d = daysUntilDue(now);
    return d >= 0 && d <= days;
  }

  /// The datetime a reminder should fire (dueDate - reminderDaysBefore at 09:00).
  DateTime? get reminderAt {
    if (reminderDaysBefore < 0 || isPaid) return null;
    final base = _dateOnly(dueDate).subtract(Duration(days: reminderDaysBefore));
    return DateTime(base.year, base.month, base.day, 9);
  }

  BillEntity copyWith({
    String? title,
    double? amount,
    DateTime? dueDate,
    BillType? type,
    String? category,
    String? walletId,
    bool? isPaid,
    DateTime? paidDate,
    int? reminderDaysBefore,
    bool? repeatMonthly,
    String? transactionId,
  }) {
    return BillEntity(
      id: id,
      userId: userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      type: type ?? this.type,
      category: category ?? this.category,
      walletId: walletId ?? this.walletId,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      repeatMonthly: repeatMonthly ?? this.repeatMonthly,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id, userId, title, amount, dueDate, type, category, walletId,
        isPaid, paidDate, reminderDaysBefore, repeatMonthly, transactionId,
        createdAt,
      ];
}
