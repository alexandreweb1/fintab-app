import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/animated_dialog.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../transactions/presentation/widgets/add_transaction_dialog.dart';
import '../../domain/entities/notification_backlog_item_entity.dart';
import '../providers/backlog_provider.dart';

class BacklogScreen extends ConsumerWidget {
  const BacklogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(backlogItemsStreamProvider);
    final pendingCount = ref.watch(unimportedBacklogCountProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações Bancárias'),
        actions: [
          if (pendingCount > 0)
            TextButton(
              onPressed: () => _confirmDismissAll(context, ref),
              child: const Text('Limpar pendentes'),
            ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (items) {
          if (items.isEmpty) return _EmptyState();

          final pending = items
              .where((i) => i.status == BacklogItemStatus.pending)
              .toList();
          final autoImported = items
              .where((i) => i.status == BacklogItemStatus.autoImported)
              .toList();
          final manuallyImported = items
              .where((i) => i.status == BacklogItemStatus.manuallyImported)
              .toList();

          final children = <Widget>[];
          if (pending.isNotEmpty) {
            children.add(_SectionHeader(label: 'Pendentes', cs: cs));
            children.addAll(pending.map(
                (i) => _BacklogItemCard(item: i, key: ValueKey(i.id))));
          }
          if (autoImported.isNotEmpty) {
            children.add(_SectionHeader(label: 'Lançadas automaticamente', cs: cs));
            children.addAll(autoImported.map(
                (i) => _BacklogItemCard(item: i, key: ValueKey(i.id))));
          }
          if (manuallyImported.isNotEmpty) {
            children.add(
                _SectionHeader(label: 'Importadas manualmente', cs: cs));
            children.addAll(manuallyImported.map(
                (i) => _BacklogItemCard(item: i, key: ValueKey(i.id))));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: children,
          );
        },
      ),
    );
  }

  Future<void> _confirmDismissAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAnimatedDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar pendentes'),
        content: const Text(
          'Remove todas as notificações não importadas. '
          'Itens já importados não serão afetados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(backlogNotifierProvider.notifier).dismissAllPending();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  const _SectionHeader({required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual item card
// ─────────────────────────────────────────────────────────────────────────────

class _BacklogItemCard extends ConsumerWidget {
  final NotificationBacklogItemEntity item;

  const _BacklogItemCard({required this.item, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(currencyFormatterProvider);

    final isExpense = item.type == TransactionType.expense;
    final isIncome = item.type == TransactionType.income;
    final amountColor = isExpense
        ? const Color(0xFFE05252)
        : isIncome
            ? const Color(0xFF00D887)
            : cs.onSurface;

    final bankName = _bankDisplayName(item.sourceApp);
    final preview = item.rawText.trim();
    final isImported = item.imported;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isImported
              ? cs.outlineVariant.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      color: isImported ? cs.surfaceContainerLow : cs.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: bank chip + type badge + sync chip + timestamp ──
            Row(
              children: [
                _Chip(
                  label: bankName,
                  color: cs.primaryContainer,
                  textColor: cs.onPrimaryContainer,
                ),
                const SizedBox(width: 6),
                if (item.type != null)
                  _Chip(
                    label: isIncome ? '↓ Receita' : '↑ Despesa',
                    color: isIncome
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.red.withValues(alpha: 0.12),
                    textColor: isIncome
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                if (item.pendingSync) ...[
                  const SizedBox(width: 6),
                  _Chip(
                    label: '↻ Sincronizando',
                    color: cs.surfaceContainerHighest,
                    textColor: cs.onSurfaceVariant,
                  ),
                ],
                const Spacer(),
                Text(
                  _timeAgo(item.receivedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Row 2: amount ──
            Text(
              fmt(item.amount),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),

            // ── Row 3: raw text preview ──
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Row 4: actions (varies by status) ──
            _ActionsRow(item: item),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Actions row — branches by status
// ─────────────────────────────────────────────────────────────────────────────

class _ActionsRow extends ConsumerWidget {
  final NotificationBacklogItemEntity item;
  const _ActionsRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    switch (item.status) {
      case BacklogItemStatus.pending:
        return Row(
          children: [
            OutlinedButton(
              onPressed: () => _confirmDismiss(context, ref),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Ignorar'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _importManually(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Importar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        );

      case BacklogItemStatus.autoImported:
        return Row(
          children: [
            Icon(Icons.bolt_rounded,
                size: 16, color: Colors.green.shade600),
            const SizedBox(width: 6),
            Text(
              'Lançada automaticamente',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _editTransaction(context, ref),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        );

      case BacklogItemStatus.manuallyImported:
        return Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 16, color: Colors.green.shade600),
            const SizedBox(width: 6),
            Text(
              'Importada',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _confirmDismiss(context, ref),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                foregroundColor: cs.onSurfaceVariant,
              ),
              child: const Text('Remover'),
            ),
          ],
        );

      case BacklogItemStatus.ignored:
        return const SizedBox.shrink();
    }
  }

  Future<void> _confirmDismiss(BuildContext context, WidgetRef ref) async {
    final isPending = item.status == BacklogItemStatus.pending;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPending ? 'Ignorar notificação' : 'Remover notificação'),
        content: Text(isPending
            ? 'Deseja ignorar e remover esta notificação?'
            : 'Deseja remover esta notificação do histórico?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isPending ? 'Ignorar' : 'Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(backlogNotifierProvider.notifier).dismiss(item.id);
    }
  }

  Future<void> _importManually(BuildContext context, WidgetRef ref) async {
    // Open the transaction dialog first, then flag the item as imported only if
    // the user actually saves (via onSaved). Cancelling leaves it in "Pendentes"
    // instead of stranding it as "Importada" with no transaction behind it.
    final notifier = ref.read(backlogNotifierProvider.notifier);
    await showAnimatedDialog<void>(
      context: context,
      builder: (_) => AddTransactionDialog(
        initialAmount: item.amount,
        initialType: item.type,
        onSaved: () => notifier.markManuallyImported(item.id),
      ),
    );
  }

  Future<void> _editTransaction(BuildContext context, WidgetRef ref) async {
    final txId = item.transactionId;
    if (txId == null) {
      // No link — open a fresh dialog pre-filled (best effort).
      await showAnimatedDialog<void>(
        context: context,
        builder: (_) => AddTransactionDialog(
          initialAmount: item.amount,
          initialType: item.type,
        ),
      );
      return;
    }
    final tx = ref
        .read(transactionsStreamProvider)
        .value
        ?.where((t) => t.id == txId)
        .cast<TransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);

    if (!context.mounted) return;
    if (tx == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Transação vinculada não encontrada.'),
      ));
      return;
    }
    await showAnimatedDialog<void>(
      context: context,
      builder: (_) => AddTransactionDialog(transaction: tx),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: cs.outlineVariant),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma notificação bancária',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'As notificações dos bancos monitorados\naparecerão aqui para você revisar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Utilities ─────────────────────────────────────────────────────────────────

/// Returns a user-friendly display name for a package name.
String _bankDisplayName(String packageName) {
  final parts = packageName.split('.');
  return parts.isNotEmpty ? parts.last : packageName;
}

/// Returns a compact human-readable relative timestamp.
String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
  if (diff.inHours < 24) return 'há ${diff.inHours}h';
  if (diff.inDays == 1) return 'ontem';
  if (diff.inDays < 7) return 'há ${diff.inDays} dias';
  final d = dt;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
