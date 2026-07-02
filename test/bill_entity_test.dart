import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/features/bills/domain/bill_entity.dart';

BillEntity _bill({
  required DateTime due,
  bool paid = false,
  int reminder = 1,
}) =>
    BillEntity(
      id: 'b',
      userId: 'u',
      title: 'Aluguel',
      amount: 1000,
      dueDate: due,
      isPaid: paid,
      reminderDaysBefore: reminder,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  final now = DateTime(2026, 3, 10, 15); // mid-afternoon

  test('daysUntilDue ignores time-of-day', () {
    expect(_bill(due: DateTime(2026, 3, 13)).daysUntilDue(now), 3);
    expect(_bill(due: DateTime(2026, 3, 10)).daysUntilDue(now), 0);
    expect(_bill(due: DateTime(2026, 3, 7)).daysUntilDue(now), -3);
  });

  test('isOverdue only when unpaid and past due', () {
    expect(_bill(due: DateTime(2026, 3, 7)).isOverdue(now), true);
    expect(_bill(due: DateTime(2026, 3, 7), paid: true).isOverdue(now), false);
    expect(_bill(due: DateTime(2026, 3, 20)).isOverdue(now), false);
  });

  test('isDueSoon within window, excludes overdue and paid', () {
    expect(_bill(due: DateTime(2026, 3, 12)).isDueSoon(3, now), true);
    expect(_bill(due: DateTime(2026, 3, 20)).isDueSoon(3, now), false);
    expect(_bill(due: DateTime(2026, 3, 7)).isDueSoon(3, now), false); // overdue
  });

  test('reminderAt is dueDate minus reminderDays at 09:00; null when off/paid',
      () {
    final b = _bill(due: DateTime(2026, 3, 13), reminder: 2);
    expect(b.reminderAt, DateTime(2026, 3, 11, 9));
    expect(_bill(due: DateTime(2026, 3, 13), reminder: -1).reminderAt, isNull);
    expect(_bill(due: DateTime(2026, 3, 13), paid: true).reminderAt, isNull);
  });
}
