import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../data/csv_parser.dart';
import '../../data/ofx_parser.dart';
import '../../domain/parsed_transaction.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  List<ParsedTransaction>? _parsed;
  final Set<int> _selected = <int>{};
  String? _fileName;
  String? _errorMessage;
  bool _busy = false;

  String _targetWalletId = '';
  String _defaultIncomeCategory = 'Outros';
  String _defaultExpenseCategory = 'Outros';

  Future<void> _pickFile() async {
    setState(() {
      _errorMessage = null;
      _busy = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ofx', 'csv', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() {
          _busy = false;
          _errorMessage = 'Não foi possível ler o arquivo.';
        });
        return;
      }
      final content = _decode(bytes);
      final ext = (file.extension ?? '').toLowerCase();
      final parsed = ext == 'ofx'
          ? OfxParser().parse(content)
          : CsvParser().parse(content);
      if (parsed.isEmpty) {
        setState(() {
          _busy = false;
          _parsed = [];
          _selected.clear();
          _fileName = file.name;
          _errorMessage =
              'Nenhuma transação reconhecida no arquivo. Verifique o formato.';
        });
        return;
      }
      setState(() {
        _busy = false;
        _parsed = parsed;
        _fileName = file.name;
        _selected
          ..clear()
          ..addAll(List.generate(parsed.length, (i) => i));
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = 'Falha ao processar arquivo: $e';
      });
    }
  }

  String _decode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  Future<void> _confirmImport() async {
    final parsed = _parsed;
    if (parsed == null || _selected.isEmpty) return;
    setState(() => _busy = true);

    final notifier = ref.read(transactionsNotifierProvider.notifier);
    int ok = 0;
    int fail = 0;
    for (final i in _selected) {
      final tx = parsed[i];
      final category = tx.type == TransactionType.income
          ? _defaultIncomeCategory
          : _defaultExpenseCategory;
      final success = await notifier.add(
        title: tx.title,
        amount: tx.amount,
        type: tx.type,
        category: category,
        date: tx.date,
        description: tx.rawDescription,
        walletId: _targetWalletId,
      );
      if (success) {
        ok++;
      } else {
        fail++;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(fail == 0
            ? '$ok transações importadas com sucesso.'
            : '$ok importadas, $fail falharam.'),
        backgroundColor: fail == 0 ? Colors.green.shade700 : Colors.orange.shade700,
      ),
    );
    if (fail == 0 && ok > 0) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wallets = ref.watch(walletsStreamProvider).value ?? <WalletEntity>[];
    final incomeCats = ref.watch(incomeCategoriesProvider);
    final expenseCats = ref.watch(expenseCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.importTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilePickerCard(
                fileName: _fileName,
                busy: _busy,
                onPick: _pickFile,
                error: _errorMessage,
              ),
              if (_parsed != null && _parsed!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _DefaultsCard(
                  wallets: wallets,
                  targetWalletId: _targetWalletId,
                  incomeCategory: _defaultIncomeCategory,
                  expenseCategory: _defaultExpenseCategory,
                  incomeCategoryNames:
                      incomeCats.map((c) => c.name).toList(),
                  expenseCategoryNames:
                      expenseCats.map((c) => c.name).toList(),
                  onWalletChanged: (v) =>
                      setState(() => _targetWalletId = v ?? ''),
                  onIncomeCategoryChanged: (v) => setState(
                      () => _defaultIncomeCategory = v ?? 'Outros'),
                  onExpenseCategoryChanged: (v) => setState(
                      () => _defaultExpenseCategory = v ?? 'Outros'),
                ),
                const SizedBox(height: 16),
                _PreviewList(
                  transactions: _parsed!,
                  selected: _selected,
                  onToggle: (i) {
                    setState(() {
                      if (_selected.contains(i)) {
                        _selected.remove(i);
                      } else {
                        _selected.add(i);
                      }
                    });
                  },
                  onToggleAll: () {
                    setState(() {
                      if (_selected.length == _parsed!.length) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(List.generate(_parsed!.length, (i) => i));
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      _busy || _selected.isEmpty ? null : _confirmImport,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    l10n.importConfirm(_selected.length),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilePickerCard extends StatelessWidget {
  final String? fileName;
  final bool busy;
  final VoidCallback onPick;
  final String? error;

  const _FilePickerCard({
    required this.fileName,
    required this.busy,
    required this.onPick,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.importPickFileTitle,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(l10n.importPickFileDesc,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : onPick,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(fileName ?? l10n.importSelectFile),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!,
                  style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DefaultsCard extends StatelessWidget {
  final List<WalletEntity> wallets;
  final String targetWalletId;
  final String incomeCategory;
  final String expenseCategory;
  final List<String> incomeCategoryNames;
  final List<String> expenseCategoryNames;
  final ValueChanged<String?> onWalletChanged;
  final ValueChanged<String?> onIncomeCategoryChanged;
  final ValueChanged<String?> onExpenseCategoryChanged;

  const _DefaultsCard({
    required this.wallets,
    required this.targetWalletId,
    required this.incomeCategory,
    required this.expenseCategory,
    required this.incomeCategoryNames,
    required this.expenseCategoryNames,
    required this.onWalletChanged,
    required this.onIncomeCategoryChanged,
    required this.onExpenseCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final walletItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('Geral')),
      ...wallets.map((w) =>
          DropdownMenuItem(value: w.id, child: Text(w.name))),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.importDefaults,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: targetWalletId,
              items: walletItems,
              decoration: InputDecoration(
                labelText: l10n.importTargetWallet,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: onWalletChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: incomeCategoryNames.contains(incomeCategory)
                  ? incomeCategory
                  : (incomeCategoryNames.isNotEmpty
                      ? incomeCategoryNames.first
                      : 'Outros'),
              items: (incomeCategoryNames.isEmpty
                      ? ['Outros']
                      : incomeCategoryNames)
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              decoration: InputDecoration(
                labelText: l10n.importIncomeCategory,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: onIncomeCategoryChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: expenseCategoryNames.contains(expenseCategory)
                  ? expenseCategory
                  : (expenseCategoryNames.isNotEmpty
                      ? expenseCategoryNames.first
                      : 'Outros'),
              items: (expenseCategoryNames.isEmpty
                      ? ['Outros']
                      : expenseCategoryNames)
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              decoration: InputDecoration(
                labelText: l10n.importExpenseCategory,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: onExpenseCategoryChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewList extends StatelessWidget {
  final List<ParsedTransaction> transactions;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final VoidCallback onToggleAll;

  const _PreviewList({
    required this.transactions,
    required this.selected,
    required this.onToggle,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final df = DateFormat('dd/MM/yyyy');
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final allSelected = selected.length == transactions.length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.importPreviewTitle(transactions.length),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: onToggleAll,
                  child: Text(allSelected
                      ? l10n.importDeselectAll
                      : l10n.importSelectAll),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
            itemBuilder: (_, i) {
              final tx = transactions[i];
              final isSel = selected.contains(i);
              return CheckboxListTile(
                dense: true,
                value: isSel,
                onChanged: (_) => onToggle(i),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(tx.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(df.format(tx.date)),
                secondary: Text(
                  (tx.type == TransactionType.income ? '+ ' : '- ') +
                      fmt.format(tx.amount),
                  style: TextStyle(
                    color: tx.type == TransactionType.income
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
