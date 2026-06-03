import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/animated_dialog.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transactions_provider.dart';
import 'add_transaction_dialog.dart';

const _kGreen = Color(0xFF00D887);
const _kRed = Color(0xFFE05252);

/// Table view for transactions — shown on wide screens (web / tablet).
class TransactionTable extends ConsumerStatefulWidget {
  final List<TransactionEntity> transactions;

  const TransactionTable({super.key, required this.transactions});

  @override
  ConsumerState<TransactionTable> createState() => _TransactionTableState();
}

class _TransactionTableState extends ConsumerState<TransactionTable> {
  String? _hoveredId;

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(currencyFormatterProvider);
    final dateLoc = ref.watch(dateLocaleProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final headerBg = isDark ? cs.surfaceContainerHigh : const Color(0xFFF8FAFC);
    final rowBg = cs.surface;
    final rowHover = isDark
        ? cs.surfaceContainerHighest
        : const Color(0xFFF1F5F9);
    final borderColor = isDark
        ? cs.outlineVariant.withValues(alpha: 0.3)
        : const Color(0xFFE2E8F0);

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: headerBg,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            child: Row(
              children: [
                _HeaderCell('Tipo', flex: 2),
                const SizedBox(width: 12),
                _HeaderCell('Descrição', flex: 4),
                const SizedBox(width: 12),
                _HeaderCell('Categoria', flex: 3),
                const SizedBox(width: 12),
                _HeaderCell('Carteira', flex: 2),
                const SizedBox(width: 12),
                _HeaderCell('Data', flex: 2),
                const SizedBox(width: 12),
                _HeaderCell('Valor', flex: 2, align: TextAlign.right),
                const SizedBox(width: 40), // actions column
              ],
            ),
          ),
        ),

        // ── Rows ────────────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: widget.transactions.length,
            itemBuilder: (context, i) {
              final tx = widget.transactions[i];
              final isIncome = tx.isIncome;
              final color = isIncome ? _kGreen : _kRed;
              final sign = isIncome ? '+' : '−';
              final isHovered = _hoveredId == tx.id;

              final dateLabel = DateFormat('dd/MM/yyyy', dateLoc).format(tx.date);
              final timeLabel = DateFormat('HH:mm', dateLoc).format(tx.date);

              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredId = tx.id),
                onExit: (_) => setState(() => _hoveredId = null),
                child: GestureDetector(
                  onTap: () => showAnimatedDialog(
                    context: context,
                    builder: (_) => AddTransactionDialog(transaction: tx),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: isHovered ? rowHover : rowBg,
                      border: Border(
                        bottom: BorderSide(color: borderColor, width: 1),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          // Type badge
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isIncome
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    size: 12,
                                    color: color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isIncome ? 'Receita' : 'Despesa',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Description
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        tx.title.isNotEmpty ? tx.title : tx.category,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: cs.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (tx.isPending)
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
                                if (tx.description != null &&
                                    tx.description!.isNotEmpty)
                                  Text(
                                    tx.description!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (tx.tags.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      children: tx.tags.map((tag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: cs.primaryContainer.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          tag,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: cs.onPrimaryContainer,
                                          ),
                                        ),
                                      )).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Category
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tx.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Wallet
                          Expanded(
                            flex: 2,
                            child: _WalletCell(walletId: tx.walletId),
                          ),
                          const SizedBox(width: 12),

                          // Date + time
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                ),
                                Text(
                                  timeLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Amount
                          Expanded(
                            flex: 2,
                            child: Text(
                              '$sign${fmt(tx.amount)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),

                          // Actions
                          SizedBox(
                            width: 40,
                            child: AnimatedOpacity(
                              opacity: isHovered ? 1 : 0,
                              duration: const Duration(milliseconds: 150),
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.more_vert,
                                    size: 18, color: cs.onSurfaceVariant),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    showAnimatedDialog(
                                      context: context,
                                      builder: (_) =>
                                          AddTransactionDialog(transaction: tx),
                                    );
                                  } else if (value == 'delete') {
                                    ref
                                        .read(transactionsNotifierProvider
                                            .notifier)
                                        .delete(tx.id);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 16),
                                        SizedBox(width: 8),
                                        Text('Editar'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline,
                                            size: 16, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Excluir',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Wallet name cell ───────────────────────────────────────────────────────────
class _WalletCell extends ConsumerWidget {
  final String walletId;
  const _WalletCell({required this.walletId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final wallets = ref.watch(walletsStreamProvider).value ?? [];
    final wallet = wallets.where((w) => w.id == walletId).firstOrNull;
    final name = wallet?.name ?? '—';

    return Text(
      name,
      style: TextStyle(
        fontSize: 12,
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Header cell ────────────────────────────────────────────────────────────────
class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final TextAlign align;

  const _HeaderCell(this.label,
      {this.flex = 1, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        textAlign: align,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
