import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

String rowsToCsv(List<List<Object?>> rows) {
  return rows
      .map((row) {
        return row
            .map((cell) {
              final text = '${cell ?? ''}'.replaceAll('"', '""');
              return text.contains(',') || text.contains('\n')
                  ? '"$text"'
                  : text;
            })
            .join(',');
      })
      .join('\n');
}

List<int> rowsToExcel(List<List<Object?>> rows, {String sheetName = 'Report'}) {
  final excel = Excel.createExcel();
  final sheet = excel[sheetName];
  for (final row in rows) {
    sheet.appendRow(
      row.map((cell) => TextCellValue(cell?.toString() ?? '')).toList(),
    );
  }
  return excel.encode() ?? <int>[];
}

Future<void> printRowsPdf(String title, List<List<Object?>> rows) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (_) => [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(data: rows),
      ],
    ),
  );
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}
