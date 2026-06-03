import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../transactions/domain/entities/transaction_entity.dart';

/// Produces a printable PDF summarising a set of transactions.
/// The bytes are returned so the caller can hand them to `printing`
/// or `share_plus` without the exporter knowing about UI concerns.
class PdfExporter {
  Future<Uint8List> build({
    required List<TransactionEntity> transactions,
    required String title,
    required DateTime? rangeStart,
    required DateTime? rangeEnd,
  }) async {
    final doc = pw.Document();
    final df = DateFormat('dd/MM/yyyy');
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    double income = 0;
    double expense = 0;
    for (final tx in transactions) {
      if (tx.isIncome) {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
    }
    final balance = income - expense;

    final rangeLabel = rangeStart != null && rangeEnd != null
        ? '${df.format(rangeStart)} — ${df.format(rangeEnd)}'
        : 'Todos os lançamentos';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(rangeLabel,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Divider(),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          _summaryCard(income, expense, balance, currency),
          pw.SizedBox(height: 12),
          _transactionsTable(transactions, df, currency),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _summaryCard(
    double income,
    double expense,
    double balance,
    NumberFormat fmt,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryCell('Receitas', fmt.format(income), PdfColors.green700),
          _summaryCell('Despesas', fmt.format(expense), PdfColors.red700),
          _summaryCell('Saldo', fmt.format(balance),
              balance >= 0 ? PdfColors.blue700 : PdfColors.red700),
        ],
      ),
    );
  }

  pw.Widget _summaryCell(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
              fontSize: 14, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }

  pw.Widget _transactionsTable(
    List<TransactionEntity> txs,
    DateFormat df,
    NumberFormat fmt,
  ) {
    final headers = ['Data', 'Título', 'Categoria', 'Tipo', 'Valor'];
    final data = txs.map((tx) {
      final signed = tx.isIncome ? tx.amount : -tx.amount;
      return [
        df.format(tx.date),
        tx.title,
        tx.category,
        tx.isIncome ? 'Receita' : 'Despesa',
        fmt.format(signed),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(1.6),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1.4),
      },
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.3),
        ),
      ),
    );
  }
}
