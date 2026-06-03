import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/animated_dialog.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transactions_provider.dart';
import 'add_transaction_dialog.dart';

const _kGreen = Color(0xFF00D887);
const _kRed = Color(0xFFE05252);

class TransactionListTile extends ConsumerWidget {
  final TransactionEntity transaction;

  const TransactionListTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = transaction.isIncome;
    final isPending = transaction.isPending;
    final color = isIncome ? _kGreen : _kRed;
    final sign = isIncome ? '+' : '-';
    final fmt = ref.watch(currencyFormatterProvider);
    final dateLoc = ref.watch(dateLocaleProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Get category icon
    final categories = ref.watch(categoriesStreamProvider).value ?? [];
    IconData categoryIconData = Icons.category;
    try {
      final matchedCategory = categories.firstWhere(
        (c) => c.name == transaction.category,
      );
      categoryIconData = categoryIcon(matchedCategory.iconCodePoint);
    } catch (_) {
      // Category not found, use default
    }

    // Theme-aware icon background: tinted surface in both light and dark mode
    final iconBg = isIncome
        ? _kGreen.withValues(alpha: 0.15)
        : _kRed.withValues(alpha: 0.15);

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 390;
    final hMargin = isCompact ? 12.0 : 20.0;

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.fromLTRB(hMargin, 0, hMargin, 10),
        decoration: BoxDecoration(
          color: Colors.red.shade700.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline_rounded,
            color: Colors.red.shade400, size: 22),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir transação'),
            content: Text(
              'Deseja excluir "${transaction.title.isNotEmpty ? transaction.title : transaction.category}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref
            .read(transactionsNotifierProvider.notifier)
            .delete(transaction.id);
      },
      child: GestureDetector(
        onTap: () => showAnimatedDialog(
          context: context,
          builder: (_) => AddTransactionDialog(transaction: transaction),
        ),
        child: Container(
          margin: EdgeInsets.fromLTRB(hMargin, 0, hMargin, 10),
          padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10.0 : 14.0, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: isCompact ? 36.0 : 44.0,
                height: isCompact ? 36.0 : 44.0,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  categoryIconData,
                  color: color,
                  size: isCompact ? 17.0 : 20.0,
                ),
              ),
              SizedBox(width: isCompact ? 8.0 : 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.title.isNotEmpty
                                ? transaction.title
                                : transaction.category,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPending)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade700.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Categorizar',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${transaction.category} · '
                      '${CurrencyFormatter.formatDate(transaction.date, dateLoc)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (transaction.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: transaction.tags.map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isCompact ? 90.0 : 110.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$sign${fmt(transaction.amount)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: isCompact ? 13.0 : 14.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
