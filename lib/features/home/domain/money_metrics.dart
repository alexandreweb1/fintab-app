import '../../transactions/domain/entities/transaction_entity.dart';

/// One point of the net-worth-over-time series.
typedef NetWorthPoint = ({DateTime month, double value});

/// Cumulative net worth at the end of each of the last [months] months
/// (oldest → newest). Net worth = income − expense + external aportes, matching
/// the app's balance definition.
List<NetWorthPoint> computeNetWorthHistory(
  Iterable<TransactionEntity> txs, {
  DateTime? now,
  int months = 6,
}) {
  final ref = now ?? DateTime.now();
  final out = <NetWorthPoint>[];
  for (var i = months - 1; i >= 0; i--) {
    final m = DateTime(ref.year, ref.month - i, 1);
    final end = DateTime(m.year, m.month + 1, 1); // exclusive
    var v = 0.0;
    for (final t in txs) {
      if (!t.date.isBefore(end)) continue;
      if (t.isIncome) {
        v += t.amount;
      } else if (t.isExpense) {
        v -= t.amount;
      } else if (t.isTransfer && t.sourceWalletId == null) {
        v += t.amount;
      }
    }
    out.add((month: m, value: v));
  }
  return out;
}

/// Age of Money (YNAB-style): the average age, in days, of the money being
/// spent — computed by consuming income lots FIFO for each expense within the
/// last [windowDays]. Returns null when there isn't enough data.
int? computeAgeOfMoney(
  Iterable<TransactionEntity> txs, {
  DateTime? now,
  int windowDays = 120,
}) {
  final ref = now ?? DateTime.now();
  final start = ref.subtract(Duration(days: windowDays));
  final events = txs
      .where((t) =>
          (t.isIncome || t.isExpense) && !t.date.isBefore(start))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  // FIFO queue of income lots: each is [date, remaining amount].
  final lots = <List<Object>>[];
  var weightedAgeSum = 0.0;
  var spentTotal = 0.0;

  for (final t in events) {
    if (t.isIncome) {
      lots.add([t.date, t.amount]);
    } else {
      var need = t.amount;
      while (need > 1e-9 && lots.isNotEmpty) {
        final lot = lots.first;
        final lotDate = lot[0] as DateTime;
        final avail = lot[1] as double;
        final use = need < avail ? need : avail;
        final ageDays = t.date.difference(lotDate).inDays.toDouble();
        weightedAgeSum += ageDays * use;
        spentTotal += use;
        need -= use;
        final left = avail - use;
        if (left <= 1e-9) {
          lots.removeAt(0);
        } else {
          lot[1] = left;
        }
      }
    }
  }

  if (spentTotal <= 0) return null;
  return (weightedAgeSum / spentTotal).round();
}
