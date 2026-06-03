import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../data/excel_exporter.dart';
import '../../data/pdf_exporter.dart';

import 'dart:io' show File;

enum _ExportPeriod { currentMonth, previousMonth, currentYear, all, custom }

enum _ExportFormat { pdf, excel }

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  _ExportPeriod _period = _ExportPeriod.currentMonth;
  _ExportFormat _format = _ExportFormat.pdf;
  DateTimeRange? _customRange;
  bool _busy = false;

  (DateTime?, DateTime?) _resolveRange() {
    final now = DateTime.now();
    switch (_period) {
      case _ExportPeriod.currentMonth:
        return (DateTime(now.year, now.month, 1),
            DateTime(now.year, now.month + 1, 0, 23, 59, 59));
      case _ExportPeriod.previousMonth:
        return (DateTime(now.year, now.month - 1, 1),
            DateTime(now.year, now.month, 0, 23, 59, 59));
      case _ExportPeriod.currentYear:
        return (DateTime(now.year, 1, 1),
            DateTime(now.year, 12, 31, 23, 59, 59));
      case _ExportPeriod.all:
        return (null, null);
      case _ExportPeriod.custom:
        final r = _customRange;
        if (r == null) return (null, null);
        return (r.start,
            DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59));
    }
  }

  List<TransactionEntity> _filterTransactions() {
    final all = ref.read(visibleTransactionsProvider);
    final (start, end) = _resolveRange();
    if (start == null || end == null) {
      final sorted = [...all]..sort((a, b) => a.date.compareTo(b.date));
      return sorted;
    }
    return all
        .where((t) =>
            !t.date.isBefore(start) && !t.date.isAfter(end))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 0),
          ),
    );
    if (picked != null) {
      setState(() => _customRange = picked);
    }
  }

  Future<void> _export() async {
    final transactions = _filterTransactions();
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).exportNoTransactions),
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      final (start, end) = _resolveRange();
      final df = DateFormat('yyyyMMdd');
      final rangeLabel = start != null && end != null
          ? '${df.format(start)}_${df.format(end)}'
          : 'todos';

      if (_format == _ExportFormat.pdf) {
        final bytes = await PdfExporter().build(
          transactions: transactions,
          title: 'Extrato financeiro',
          rangeStart: start,
          rangeEnd: end,
        );
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'fintab_extrato_$rangeLabel.pdf',
        );
      } else {
        final raw = ExcelExporter().build(
          transactions: transactions,
          sheetName: 'Transações',
        );
        final bytes = Uint8List.fromList(raw);
        await _shareExcel(bytes, 'fintab_extrato_$rangeLabel.xlsx');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro ao gerar arquivo: $e'),
        backgroundColor: Colors.red.shade700,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareExcel(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: filename,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (start, end) = _resolveRange();
    final txs = _filterTransactions();
    final df = DateFormat('dd/MM/yyyy');
    final rangeLabel = start != null && end != null
        ? '${df.format(start)} — ${df.format(end)}'
        : l10n.exportAllTime;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                title: l10n.exportPeriod,
                child: Column(
                  children: [
                    _PeriodRadio(
                      value: _ExportPeriod.currentMonth,
                      group: _period,
                      title: l10n.exportCurrentMonth,
                      onChanged: (v) => setState(() => _period = v!),
                    ),
                    _PeriodRadio(
                      value: _ExportPeriod.previousMonth,
                      group: _period,
                      title: l10n.exportPreviousMonth,
                      onChanged: (v) => setState(() => _period = v!),
                    ),
                    _PeriodRadio(
                      value: _ExportPeriod.currentYear,
                      group: _period,
                      title: l10n.exportCurrentYear,
                      onChanged: (v) => setState(() => _period = v!),
                    ),
                    _PeriodRadio(
                      value: _ExportPeriod.all,
                      group: _period,
                      title: l10n.exportAllTime,
                      onChanged: (v) => setState(() => _period = v!),
                    ),
                    _PeriodRadio(
                      value: _ExportPeriod.custom,
                      group: _period,
                      title: _customRange == null
                          ? l10n.exportCustomRange
                          : '${df.format(_customRange!.start)} — ${df.format(_customRange!.end)}',
                      trailing: TextButton(
                        onPressed: _pickCustomRange,
                        child: Text(l10n.exportPickRange),
                      ),
                      onChanged: (v) => setState(() => _period = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: l10n.exportFormat,
                child: Column(
                  children: [
                    RadioListTile<_ExportFormat>(
                      value: _ExportFormat.pdf,
                      groupValue: _format,
                      onChanged: (v) => setState(() => _format = v!),
                      title: const Text('PDF'),
                      subtitle: Text(l10n.exportPdfDesc),
                      secondary: const Icon(Icons.picture_as_pdf_rounded,
                          color: Colors.red),
                    ),
                    RadioListTile<_ExportFormat>(
                      value: _ExportFormat.excel,
                      groupValue: _format,
                      onChanged: (v) => setState(() => _format = v!),
                      title: const Text('Excel (.xlsx)'),
                      subtitle: Text(l10n.exportExcelDesc),
                      secondary: const Icon(Icons.table_chart_rounded,
                          color: Colors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: l10n.exportSummary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rangeLabel,
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(l10n.exportTransactionsCount(txs.length)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy || txs.isEmpty ? null : _export,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.ios_share_rounded),
                label: Text(l10n.exportGenerate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _PeriodRadio extends StatelessWidget {
  final _ExportPeriod value;
  final _ExportPeriod group;
  final String title;
  final Widget? trailing;
  final ValueChanged<_ExportPeriod?> onChanged;

  const _PeriodRadio({
    required this.value,
    required this.group,
    required this.title,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: RadioListTile<_ExportPeriod>(
            value: value,
            groupValue: group,
            onChanged: onChanged,
            title: Text(title),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
