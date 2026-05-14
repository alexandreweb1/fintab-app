import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/providers/effective_user_provider.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../domain/entities/wallet_entity.dart';
import '../providers/wallets_provider.dart';

// ─── Color palette + small pickers (private to this file) ────────────────────

const _kColorPalette = [
  0xFF1976D2, // blue
  0xFF303F9F, // indigo
  0xFF00796B, // teal
  0xFF388E3C, // green
  0xFF558B2F, // light green
  0xFFE64A19, // deep orange
  0xFFC62828, // red
  0xFFAD1457, // pink
  0xFF6A1B9A, // purple
  0xFF5D4037, // brown
  0xFF0288D1, // light blue
  0xFF616161, // grey
];

class _ColorDots extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;
  const _ColorDots({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _kColorPalette.map((c) {
        final isSelected = c == selected;
        return GestureDetector(
          onTap: () => onSelected(c),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(c),
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 2.5)
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _IconPickerGrid extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;
  const _IconPickerGrid({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final entries = kCategoryIconMap.entries.toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final codePoint = entries[i].key;
        final iconData = entries[i].value;
        final isSelected = codePoint == selected;
        return GestureDetector(
          onTap: () => onSelected(codePoint),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary, width: 2)
                  : null,
            ),
            child: Icon(iconData,
                size: 22,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        );
      },
    );
  }
}

// ─── Tab content shared by Reservas and Investimentos ────────────────────────

class TypedWalletsTab extends ConsumerWidget {
  final WalletType type;
  const TypedWalletsTab({super.key, required this.type});

  String get _typeTitle => switch (type) {
        WalletType.reserve => 'Reservas',
        WalletType.investment => 'Investimentos',
        WalletType.regular => 'Carteiras',
      };

  String get _typeSingular => switch (type) {
        WalletType.reserve => 'Reserva',
        WalletType.investment => 'Investimento',
        WalletType.regular => 'Carteira',
      };

  String get _emptyHint => switch (type) {
        WalletType.reserve =>
          'Crie reservas para guardar dinheiro com objetivo (emergência, viagem, etc.).',
        WalletType.investment =>
          'Cadastre suas aplicações para acompanhar aportes e patrimônio.',
        WalletType.regular => '',
      };

  IconData get _typeIcon => switch (type) {
        WalletType.reserve => Icons.shield_outlined,
        WalletType.investment => Icons.trending_up_rounded,
        WalletType.regular => Icons.account_balance_wallet_outlined,
      };

  Color _accent(BuildContext context) => switch (type) {
        WalletType.reserve => const Color(0xFF00796B),
        WalletType.investment => const Color(0xFF6A1B9A),
        WalletType.regular => Theme.of(context).colorScheme.primary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = type == WalletType.reserve
        ? ref.watch(reserveWalletsProvider)
        : ref.watch(investmentWalletsProvider);
    // Saldos reais (sem filtro de oculto): cards continuam mostrando o valor
    // verdadeiro mesmo quando a carteira está oculta dos totais do app.
    final balances = ref.watch(walletAllBalancesProvider);
    final hiddenIds = ref.watch(appSettingsProvider).hiddenWalletIds;
    final fmt = ref.watch(currencyFormatterProvider);
    final cs = Theme.of(context).colorScheme;
    final accent = _accent(context);

    final total =
        wallets.fold<double>(0, (sum, w) => sum + (balances[w.id] ?? 0));
    final visibleTotal = wallets
        .where((w) => !hiddenIds.contains(w.id))
        .fold<double>(0, (sum, w) => sum + (balances[w.id] ?? 0));
    final hiddenCount = wallets.where((w) => hiddenIds.contains(w.id)).length;
    final aggregateTarget =
        wallets.fold<double>(0, (sum, w) => sum + w.targetAmount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Header card ────────────────────────────────────────────────────
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accent.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_typeIcon, color: accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total em $_typeTitle',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fmt(total),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: total >= 0 ? accent : Colors.red.shade700,
                            ),
                          ),
                          if (hiddenCount > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.visibility_off_outlined,
                                    size: 13, color: cs.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Computando no patrimônio: ${fmt(visibleTotal)} '
                                    '($hiddenCount ocult${hiddenCount == 1 ? "a" : "as"})',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (aggregateTarget > 0) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (total / aggregateTarget).clamp(0.0, 1.0),
                      backgroundColor: cs.surfaceContainerHighest,
                      color: accent,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Meta agregada: ${fmt(aggregateTarget)}',
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${wallets.length} ${wallets.length == 1 ? _typeSingular.toLowerCase() : _typeTitle.toLowerCase()} cadastrad${wallets.length == 1 ? "a" : "as"}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Empty state ────────────────────────────────────────────────────
        if (wallets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(_typeIcon,
                    size: 56,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text(
                  'Nenhuma ${_typeSingular.toLowerCase()} cadastrada',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _emptyHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          )
        else
          ...wallets.map((w) => _BucketCard(
                wallet: w,
                balance: balances[w.id] ?? 0,
                fmt: fmt,
                accent: accent,
                isHidden: hiddenIds.contains(w.id),
                onTap: () => _openActions(context, w),
                onAporte: () => _openTransfer(context, wallet: w, isAporte: true),
                onToggleHidden: () => ref
                    .read(appSettingsProvider.notifier)
                    .toggleWalletVisibility(w.id),
              )),

        const SizedBox(height: 12),

        // ── Add new bucket ─────────────────────────────────────────────────
        OutlinedButton.icon(
          onPressed: () => _openCreateWallet(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent.withValues(alpha: 0.6)),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.add_rounded),
          label: Text('Nova $_typeSingular'),
        ),
      ],
    );
  }

  void _openCreateWallet(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => TypedWalletDialog(type: type),
    );
  }

  void _openTransfer(
    BuildContext context, {
    required WalletEntity wallet,
    required bool isAporte,
  }) {
    showDialog(
      context: context,
      builder: (_) => TransferDialog(bucket: wallet, isAporte: isAporte),
    );
  }

  void _openActions(BuildContext context, WalletEntity wallet) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline,
                  color: Color(0xFF388E3C)),
              title: const Text('Aporte'),
              subtitle: const Text('Adicionar dinheiro a esta carteira'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openTransfer(context, wallet: wallet, isAporte: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline,
                  color: Color(0xFFE05252)),
              title: const Text('Resgate'),
              subtitle: const Text('Retirar dinheiro desta carteira'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openTransfer(context, wallet: wallet, isAporte: false);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(sheetContext);
                showDialog(
                  context: context,
                  builder: (_) =>
                      TypedWalletDialog(type: wallet.type, existing: wallet),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Excluir'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final ok = await _confirmDelete(context, wallet);
                if (!ok) return;
                if (!context.mounted) return;
                final container = ProviderScope.containerOf(context);
                await container
                    .read(walletsNotifierProvider.notifier)
                    .delete(wallet.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(
      BuildContext context, WalletEntity wallet) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir carteira?'),
        content: Text(
          'A carteira "${wallet.name}" será removida. As transações associadas '
          'continuarão existindo, mas perderão a referência a esta carteira.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return res ?? false;
  }
}

// ─── Per-bucket card ─────────────────────────────────────────────────────────

class _BucketCard extends StatelessWidget {
  final WalletEntity wallet;
  final double balance;
  final String Function(double) fmt;
  final Color accent;
  final bool isHidden;
  final VoidCallback onTap;
  final VoidCallback onAporte;
  final VoidCallback onToggleHidden;

  const _BucketCard({
    required this.wallet,
    required this.balance,
    required this.fmt,
    required this.accent,
    required this.isHidden,
    required this.onTap,
    required this.onAporte,
    required this.onToggleHidden,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = Color(wallet.colorValue);
    final hasTarget = wallet.targetAmount > 0;
    final progress =
        hasTarget ? (balance / wallet.targetAmount).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: isHidden ? 0.65 : 1.0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: isHidden
                  ? Border.all(
                      color: cs.outlineVariant,
                      style: BorderStyle.solid,
                      width: 1,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(categoryIcon(wallet.iconCodePoint),
                          color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  wallet.name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isHidden) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.visibility_off_outlined,
                                    size: 14, color: cs.onSurfaceVariant),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fmt(balance),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: balance >= 0
                                  ? accent
                                  : Colors.red.shade700,
                            ),
                          ),
                          if (isHidden)
                            Text(
                              'Oculta dos totais e gráficos',
                              style: TextStyle(
                                  fontSize: 11, color: cs.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isHidden
                          ? 'Incluir no patrimônio total'
                          : 'Ocultar do patrimônio total',
                      icon: Icon(
                        isHidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: cs.onSurfaceVariant,
                        size: 22,
                      ),
                      onPressed: onToggleHidden,
                    ),
                    IconButton(
                      tooltip: 'Aporte',
                      icon: Icon(Icons.add_circle, color: accent, size: 28),
                      onPressed: onAporte,
                    ),
                  ],
                ),
              if (hasTarget) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: cs.surfaceContainerHighest,
                      color: accent,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% da meta',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                      Text(
                        'Meta: ${fmt(wallet.targetAmount)}',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// ─── Add/Edit Typed Wallet Dialog ────────────────────────────────────────────

class TypedWalletDialog extends ConsumerStatefulWidget {
  final WalletType type;
  final WalletEntity? existing;
  const TypedWalletDialog({super.key, required this.type, this.existing});

  @override
  ConsumerState<TypedWalletDialog> createState() => _TypedWalletDialogState();
}

class _TypedWalletDialogState extends ConsumerState<TypedWalletDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;
  late int _iconCodePoint;
  late int _colorValue;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _targetCtrl = TextEditingController(
        text: e == null || e.targetAmount == 0
            ? ''
            : e.targetAmount.toStringAsFixed(2));
    _iconCodePoint =
        e?.iconCodePoint ?? (widget.type == WalletType.investment ? 0xe8e5 : 0xe4c9);
    _colorValue = e?.colorValue ??
        (widget.type == WalletType.investment ? 0xFF6A1B9A : 0xFF00796B);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  String get _title => widget.existing == null
      ? (widget.type == WalletType.investment
          ? 'Novo Investimento'
          : 'Nova Reserva')
      : 'Editar';

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final targetText = _targetCtrl.text.replaceAll(',', '.').trim();
    final target = double.tryParse(targetText) ?? 0;
    setState(() => _loading = true);
    final notifier = ref.read(walletsNotifierProvider.notifier);
    final existing = widget.existing;

    bool success;
    if (existing == null) {
      final userId = ref.read(effectiveUserIdProvider);
      if (userId.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      success = await notifier.add(
        userId: userId,
        name: name,
        iconCodePoint: _iconCodePoint,
        colorValue: _colorValue,
        type: widget.type,
        targetAmount: target,
      );
    } else {
      success = await notifier.update(existing.copyWith(
        name: name,
        iconCodePoint: _iconCodePoint,
        colorValue: _colorValue,
        targetAmount: target,
      ));
    }

    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      Navigator.of(context).pop();
    } else {
      final err = ref.read(walletsNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err?.toString() ?? 'Erro ao salvar'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Nome', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _targetCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Meta (opcional)',
                  hintText: '0,00',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
              ),
              const SizedBox(height: 16),
              Text('Ícone',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              _IconPickerGrid(
                  selected: _iconCodePoint,
                  onSelected: (v) => setState(() => _iconCodePoint = v)),
              const SizedBox(height: 16),
              Text('Cor', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              _ColorDots(
                  selected: _colorValue,
                  onSelected: (v) => setState(() => _colorValue = v)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

// ─── Transfer (Aporte/Resgate) Dialog ────────────────────────────────────────

class TransferDialog extends ConsumerStatefulWidget {
  /// The reserve/investment wallet that is the focus of this transfer.
  /// For aporte: this is the destination.
  /// For resgate: this is the source.
  final WalletEntity bucket;
  final bool isAporte;
  const TransferDialog({
    super.key,
    required this.bucket,
    required this.isAporte,
  });

  @override
  ConsumerState<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends ConsumerState<TransferDialog> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _titleCtrl;
  String? _counterpartWalletId; // null means "externa"
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _titleCtrl = TextEditingController(
        text: widget.isAporte
            ? 'Aporte em ${widget.bucket.name}'
            : 'Resgate de ${widget.bucket.name}');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final amountText = _amountCtrl.text.replaceAll(',', '.').trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor válido.')),
      );
      return;
    }

    // Aporte: destination = bucket, source = counterpart (or null)
    // Resgate: destination = counterpart (or null), source = bucket
    final String destinationId;
    final String? sourceId;
    if (widget.isAporte) {
      destinationId = widget.bucket.id;
      sourceId = _counterpartWalletId;
    } else {
      destinationId = _counterpartWalletId ?? '';
      sourceId = widget.bucket.id;
    }

    setState(() => _loading = true);
    final notifier = ref.read(transactionsNotifierProvider.notifier);
    final success = await notifier.add(
      title: _titleCtrl.text.trim().isEmpty
          ? (widget.isAporte ? 'Aporte' : 'Resgate')
          : _titleCtrl.text.trim(),
      amount: amount,
      type: TransactionType.transfer,
      category: widget.isAporte ? 'Aporte' : 'Resgate',
      date: _date,
      walletId: destinationId,
      sourceWalletId: sourceId,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      Navigator.of(context).pop();
    } else {
      final err = ref.read(transactionsNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err?.toString() ?? 'Erro ao registrar'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLoc = ref.watch(dateLocaleProvider);
    final regularWallets = ref.watch(regularWalletsProvider);
    final cs = Theme.of(context).colorScheme;
    final accent = widget.isAporte
        ? const Color(0xFF388E3C)
        : const Color(0xFFE05252);
    final counterpartLabel =
        widget.isAporte ? 'Origem do aporte' : 'Destino do resgate';

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.isAporte
                ? Icons.add_circle_outline
                : Icons.remove_circle_outline,
            color: accent,
          ),
          const SizedBox(width: 10),
          Text(widget.isAporte ? 'Novo Aporte' : 'Novo Resgate'),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(categoryIcon(widget.bucket.iconCodePoint),
                        color: Color(widget.bucket.colorValue), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.bucket.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      widget.isAporte ? 'destino' : 'origem',
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  hintText: '0,00',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _counterpartWalletId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: counterpartLabel,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Externa (sem origem/destino)'),
                  ),
                  ...regularWallets.map(
                    (w) => DropdownMenuItem<String?>(
                      value: w.id,
                      child: Row(
                        children: [
                          Icon(categoryIcon(w.iconCodePoint),
                              color: Color(w.colorValue), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(w.name,
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _counterpartWalletId = v),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(DateFormat('dd/MM/yyyy', dateLoc).format(_date)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: accent),
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.isAporte ? 'Aportar' : 'Resgatar'),
        ),
      ],
    );
  }
}
