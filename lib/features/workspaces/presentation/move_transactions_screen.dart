import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/workspace_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/presentation/providers/transactions_provider.dart';
import '../domain/workspace_entity.dart';
import 'workspace_switcher.dart';

/// Moves lançamentos from one Carteira to another (bulk re-stamp of
/// `workspaceId`). Non-destructive: only the Carteira changes — the userId and
/// wallet refs stay, so a move can be reversed. Owner-only (own Carteiras).
class MoveTransactionsScreen extends ConsumerStatefulWidget {
  final String? initialSourceId;
  final String? initialTargetId;
  const MoveTransactionsScreen({
    super.key,
    this.initialSourceId,
    this.initialTargetId,
  });

  @override
  ConsumerState<MoveTransactionsScreen> createState() =>
      _MoveTransactionsScreenState();
}

class _MoveTransactionsScreenState
    extends ConsumerState<MoveTransactionsScreen> {
  String? _sourceId;
  String? _targetId;
  final _selected = <String>{};
  bool _moving = false;
  bool _initialized = false;

  bool _belongs(TransactionEntity t, String? carteiraId, String? defaultWs) {
    final w = t.workspaceId;
    if (w == null) return carteiraId == defaultWs; // legacy → default
    return w == carteiraId;
  }

  Future<void> _move(List<WorkspaceEntity> own) async {
    final target = own.firstWhere((w) => w.id == _targetId);
    final count = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Mover lançamentos'),
        content: Text(
          'Mover $count lançamento(s) para "${target.name}"?\n\n'
          'As Contas são específicas de cada Carteira; os lançamentos movidos '
          'aparecerão em "${target.name}" e você pode reatribuí-los a uma Conta '
          'de lá depois. A ação pode ser desfeita movendo de volta.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Mover')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _moving = true);
    try {
      await ref
          .read(transactionDataSourceProvider)
          .moveToWorkspace(_selected.toList(), _targetId!);
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _moving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$count lançamento(s) movido(s) para ${target.name} ✓')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _moving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível mover: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(currencyFormatterProvider);
    final own = (ref.watch(ownWorkspacesStreamProvider).value ?? const [])
        .where((w) => !w.archived)
        .toList();
    final defaultWs = ref.watch(defaultWorkspaceIdProvider);

    if (!_initialized && own.isNotEmpty) {
      _initialized = true;
      final activeId = ref.read(activeWorkspaceProvider)?.id;
      _sourceId =
          widget.initialSourceId ?? activeId ?? defaultWs ?? own.first.id;
      final others = own.where((w) => w.id != _sourceId).toList();
      _targetId = widget.initialTargetId ??
          (others.isNotEmpty ? others.first.id : null);
      if (_targetId == _sourceId) _targetId = null;
    }

    if (own.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mover lançamentos')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Você precisa de pelo menos 2 Carteiras para mover lançamentos '
              'entre elas.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final all = ref.watch(allOwnerTransactionsProvider).value ?? const [];
    final srcTxns = [
      ...all.where((t) => _belongs(t, _sourceId, defaultWs))
    ]..sort((a, b) => b.date.compareTo(a.date));

    final allSelected =
        srcTxns.isNotEmpty && _selected.length == srcTxns.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Mover lançamentos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _CarteiraDropdown(
                    label: 'De',
                    value: _sourceId,
                    options: own,
                    onChanged: (v) => setState(() {
                      _sourceId = v;
                      _selected.clear();
                      if (_targetId == v) _targetId = null;
                    }),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded),
                ),
                Expanded(
                  child: _CarteiraDropdown(
                    label: 'Para',
                    value: _targetId,
                    options: own.where((w) => w.id != _sourceId).toList(),
                    onChanged: (v) => setState(() => _targetId = v),
                  ),
                ),
              ],
            ),
          ),
          if (srcTxns.isNotEmpty)
            CheckboxListTile(
              dense: true,
              value: allSelected,
              onChanged: (v) => setState(() {
                _selected.clear();
                if (v == true) {
                  _selected.addAll(srcTxns.map((t) => t.id));
                }
              }),
              title: Text(
                  'Selecionar todos (${srcTxns.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          const Divider(height: 1),
          Expanded(
            child: srcTxns.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Esta Carteira não tem lançamentos para mover.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: srcTxns.length,
                    itemBuilder: (_, i) {
                      final t = srcTxns[i];
                      final selected = _selected.contains(t.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(t.id);
                          } else {
                            _selected.remove(t.id);
                          }
                        }),
                        title: Text(t.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${t.category} · ${DateFormat('dd/MM/yy').format(t.date)}'),
                        secondary: Text(
                          fmt(t.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: t.isIncome
                                ? Colors.green.shade600
                                : (t.isExpense ? cs.error : cs.onSurface),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: (_selected.isEmpty ||
                    _targetId == null ||
                    _targetId == _sourceId ||
                    _moving)
                ? null
                : () => _move(own),
            icon: _moving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.drive_file_move_outline),
            label: Text(_selected.isEmpty
                ? 'Selecione lançamentos'
                : 'Mover ${_selected.length} lançamento(s)'),
          ),
        ),
      ),
    );
  }
}

class _CarteiraDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<WorkspaceEntity> options;
  final ValueChanged<String?> onChanged;
  const _CarteiraDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.any((w) => w.id == value) ? value : null,
          isExpanded: true,
          items: options
              .map((w) => DropdownMenuItem(
                    value: w.id,
                    child: Row(
                      children: [
                        Icon(workspaceIcon(w.type),
                            size: 16,
                            color: w.isBusiness
                                ? const Color(0xFF7B1FA2)
                                : Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(w.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 4),
                        CarteiraTypeBadge(type: w.type),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
