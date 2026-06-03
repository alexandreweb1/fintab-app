import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/animated_dialog.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../providers/recurring_provider.dart';
import '../widgets/add_recurring_dialog.dart';

const _kGreen = Color(0xFF00D887);
const _kRed = Color(0xFFE05252);

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringStreamProvider);

    return Scaffold(
      body: recurringAsync.when(
        data: (list) {
          if (list.isEmpty) return const _EmptyState();

          final active = list.where((r) => r.isActive).toList();
          final inactive = list.where((r) => !r.isActive).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              if (active.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Ativas',
                  count: active.length,
                ),
                ...active.map((r) => _RecurringCard(recurring: r)),
              ],
              if (inactive.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Pausadas',
                  count: inactive.length,
                ),
                ...inactive.map((r) => _RecurringCard(recurring: r)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAnimatedDialog(
          context: context,
          builder: (_) => const AddRecurringDialog(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.repeat_rounded,
              size: 64, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Nenhuma recorrência cadastrada',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Adicione transações que se repetem\nautomaticamente todo mês',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => showAnimatedDialog(
              context: context,
              builder: (_) => const AddRecurringDialog(),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nova recorrência'),
          ),
        ],
      ),
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recurring card ───────────────────────────────────────────────────────────

class _RecurringCard extends ConsumerWidget {
  final RecurringTransactionEntity recurring;

  const _RecurringCard({required this.recurring});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(currencyFormatterProvider);
    final isIncome = recurring.isIncome;
    final color = isIncome ? _kGreen : _kRed;
    final sign = isIncome ? '+' : '−';

    final freqLabel = _frequencyLabel(recurring.frequency);
    final nextDate = recurring.nextOccurrence();
    final nextLabel = nextDate != null
        ? DateFormat('dd/MM/yyyy').format(nextDate)
        : 'Finalizada';

    return Dismissible(
      key: Key(recurring.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
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
        return await showAnimatedDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir recorrência'),
            content: Text('Deseja excluir "${recurring.title}"?\n'
                'Transações já geradas não serão removidas.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(recurringNotifierProvider.notifier).delete(recurring.id);
      },
      child: GestureDetector(
        onTap: () => showAnimatedDialog(
          context: context,
          builder: (_) => AddRecurringDialog(recurring: recurring),
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
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
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.repeat_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recurring.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: recurring.isActive
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!recurring.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Pausada',
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${recurring.category} · $freqLabel · Próx: $nextLabel',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${fmt(recurring.amount)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Toggle active
                  GestureDetector(
                    onTap: () => ref
                        .read(recurringNotifierProvider.notifier)
                        .toggleActive(recurring),
                    child: Icon(
                      recurring.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _frequencyLabel(RecurrenceFrequency freq) {
    switch (freq) {
      case RecurrenceFrequency.daily:
        return 'Diária';
      case RecurrenceFrequency.weekly:
        return 'Semanal';
      case RecurrenceFrequency.monthly:
        return 'Mensal';
      case RecurrenceFrequency.yearly:
        return 'Anual';
    }
  }
}
