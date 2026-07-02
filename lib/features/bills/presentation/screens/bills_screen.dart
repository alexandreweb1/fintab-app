import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/money_input_formatter.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../domain/bill_entity.dart';
import '../providers/bills_provider.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bills = ref.watch(billsStreamProvider).value ?? const [];
    final unpaid = bills.where((b) => !b.isPaid).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final paid = bills.where((b) => b.isPaid).toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bills)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref, null),
        icon: const Icon(Icons.add),
        label: Text(l10n.billAdd),
      ),
      body: bills.isEmpty
          ? _Empty(l10n: l10n)
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                if (unpaid.isNotEmpty) ...[
                  _SectionLabel(l10n.billsUpcoming),
                  ...unpaid.map((b) => _BillTile(bill: b)),
                ],
                if (paid.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionLabel(l10n.billsPaidSection),
                  ...paid.take(20).map((b) => _BillTile(bill: b)),
                ],
              ],
            ),
    );
  }
}

void _openEditor(BuildContext context, WidgetRef ref, BillEntity? bill) {
  showDialog<void>(context: context, builder: (_) => _BillEditor(bill: bill));
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _Empty extends StatelessWidget {
  final AppLocalizations l10n;
  const _Empty({required this.l10n});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_note_outlined,
              size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(l10n.billsEmpty,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l10n.billsEmptyDesc,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _BillTile extends ConsumerWidget {
  final BillEntity bill;
  const _BillTile({required this.bill});

  ({Color color, String label}) _status(AppLocalizations l10n, ColorScheme cs) {
    if (bill.isPaid) {
      return (color: const Color(0xFF00A86B), label: l10n.billPaid);
    }
    final d = bill.daysUntilDue();
    if (d < 0) return (color: cs.error, label: l10n.billOverdue);
    if (d == 0) return (color: const Color(0xFFFF9800), label: l10n.billDueToday);
    return (color: cs.onSurfaceVariant, label: l10n.billDueInDays(d));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(currencyFormatterProvider);
    final dateLoc = ref.watch(dateLocaleProvider);
    final st = _status(l10n, cs);
    final accent = bill.isReceivable ? const Color(0xFF00A86B) : cs.primary;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.12),
          child: Icon(
              bill.isReceivable
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              color: accent,
              size: 20),
        ),
        title: Text(bill.title,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
                decoration: bill.isPaid ? TextDecoration.lineThrough : null)),
        subtitle: Text(
          '${CurrencyFormatter.formatDate(bill.dueDate, dateLoc)} · ${st.label}',
          style: TextStyle(fontSize: 12, color: st.color),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(fmt(bill.amount),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: bill.isReceivable ? const Color(0xFF00A86B) : null)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'paid') {
                final ok =
                    await ref.read(billsNotifierProvider.notifier).markPaid(bill);
                if (ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.billPaidSuccess)),
                  );
                }
              } else if (v == 'edit') {
                if (context.mounted) _openEditor(context, ref, bill);
              } else if (v == 'delete') {
                await ref.read(billsNotifierProvider.notifier).delete(bill.id);
              }
            },
            itemBuilder: (_) => [
              if (!bill.isPaid)
                PopupMenuItem(
                    value: 'paid',
                    child: Text(bill.isReceivable
                        ? l10n.billMarkReceived
                        : l10n.billMarkPaid)),
              PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
              PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
            ],
          ),
        ]),
      ),
    );
  }
}

// ── Editor dialog ─────────────────────────────────────────────────────────

class _BillEditor extends ConsumerStatefulWidget {
  final BillEntity? bill;
  const _BillEditor({this.bill});
  @override
  ConsumerState<_BillEditor> createState() => _BillEditorState();
}

class _BillEditorState extends ConsumerState<_BillEditor> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  late BillType _type;
  late DateTime _dueDate;
  late int _reminder;
  late bool _repeat;
  String _walletId = '';
  bool _loading = false;

  bool get _isEditing => widget.bill != null;

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    _titleCtrl.text = b?.title ?? '';
    if (b != null) _amountCtrl.text = doubleToMoneyText(b.amount);
    _type = b?.type ?? BillType.payable;
    _dueDate = b?.dueDate ?? DateTime.now().add(const Duration(days: 3));
    _reminder = b?.reminderDaysBefore ?? 1;
    _repeat = b?.repeatMonthly ?? false;
    _walletId = b?.walletId ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final title = _titleCtrl.text.trim();
    final amount = moneyTextToDouble(_amountCtrl.text);
    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.invalidAmount)));
      return;
    }
    setState(() => _loading = true);
    final notifier = ref.read(billsNotifierProvider.notifier);
    final bool ok;
    if (_isEditing) {
      ok = await notifier.update(widget.bill!.copyWith(
        title: title,
        amount: amount,
        dueDate: _dueDate,
        type: _type,
        walletId: _walletId,
        reminderDaysBefore: _reminder,
        repeatMonthly: _repeat,
      ));
    } else {
      ok = await notifier.add(
        title: title,
        amount: amount,
        dueDate: _dueDate,
        type: _type,
        walletId: _walletId,
        reminderDaysBefore: _reminder,
        repeatMonthly: _repeat,
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateLoc = ref.watch(dateLocaleProvider);
    final wallets = ref.watch(walletsStreamProvider).value ?? const [];

    return AlertDialog(
      title: Text(_isEditing ? l10n.billEdit : l10n.billAdd),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<BillType>(
              segments: [
                ButtonSegment(
                    value: BillType.payable, label: Text(l10n.billPayable)),
                ButtonSegment(
                    value: BillType.receivable, label: Text(l10n.billReceivable)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                  labelText: l10n.billNameField,
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              decoration: InputDecoration(
                  labelText: l10n.amount, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                    labelText: l10n.billDueDate,
                    border: const OutlineInputBorder()),
                child: Text(CurrencyFormatter.formatDate(_dueDate, dateLoc)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _reminder,
              decoration: InputDecoration(
                  labelText: l10n.billReminder,
                  border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: -1, child: Text(l10n.billReminderNone)),
                DropdownMenuItem(value: 0, child: Text(l10n.billReminderSameDay)),
                DropdownMenuItem(
                    value: 1, child: Text(l10n.billReminderDaysBefore(1))),
                DropdownMenuItem(
                    value: 3, child: Text(l10n.billReminderDaysBefore(3))),
                DropdownMenuItem(
                    value: 7, child: Text(l10n.billReminderDaysBefore(7))),
              ],
              onChanged: (v) => setState(() => _reminder = v ?? 1),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: wallets.any((w) => w.id == _walletId) ? _walletId : '',
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: l10n.walletField,
                  border: const OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: '', child: Text('Geral')),
                ...wallets.map((w) =>
                    DropdownMenuItem(value: w.id, child: Text(w.name))),
              ],
              onChanged: (v) => setState(() => _walletId = v ?? ''),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              value: _repeat,
              onChanged: (v) => setState(() => _repeat = v),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n.billRepeatMonthly),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}
