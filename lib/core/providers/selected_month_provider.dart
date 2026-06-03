import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single source of truth for the currently selected month across all tabs.
/// Changing this provider in any screen (Dashboard, Transactions, Planning,
/// Reports) will automatically reflect in all others.
final selectedMonthProvider = StateProvider<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month, 1),
);
