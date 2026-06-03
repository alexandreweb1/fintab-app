import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../transactions/domain/entities/transaction_entity.dart';

/// Generates an .xlsx workbook from a list of transactions.
/// Returns the raw bytes so the caller can save/share them without
/// worrying about file I/O here.
class ExcelExporter {
  List<int> build({
    required List<TransactionEntity> transactions,
    required String sheetName,
  }) {
    final excel = Excel.createExcel();
    // Rename the default sheet so the workbook doesn't ship with "Sheet1".
    excel.rename(excel.getDefaultSheet()!, sheetName);
    final sheet = excel[sheetName];

    final headers = <CellValue>[
      TextCellValue('Data'),
      TextCellValue('Título'),
      TextCellValue('Categoria'),
      TextCellValue('Tipo'),
      TextCellValue('Valor'),
      TextCellValue('Carteira'),
      TextCellValue('Tags'),
      TextCellValue('Descrição'),
    ];
    sheet.appendRow(headers);

    final df = DateFormat('dd/MM/yyyy');
    double income = 0;
    double expense = 0;

    for (final tx in transactions) {
      final signed = tx.isIncome ? tx.amount : -tx.amount;
      if (tx.isIncome) {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
      sheet.appendRow(<CellValue>[
        TextCellValue(df.format(tx.date)),
        TextCellValue(tx.title),
        TextCellValue(tx.category),
        TextCellValue(tx.isIncome ? 'Receita' : 'Despesa'),
        DoubleCellValue(signed),
        TextCellValue(tx.walletId.isEmpty ? 'Geral' : tx.walletId),
        TextCellValue(tx.tags.join(', ')),
        TextCellValue(tx.description ?? ''),
      ]);
    }

    // Totals row (blank separator + summary).
    sheet.appendRow(<CellValue>[]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Total receitas'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(income),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Total despesas'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(expense),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Saldo'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(income - expense),
    ]);

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Falha ao gerar arquivo Excel.');
    }
    return bytes;
  }
}
