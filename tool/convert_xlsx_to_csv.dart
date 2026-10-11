import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:csv/csv.dart';

void main() async {
  final xlsxPath = 'assets/data/mandarin_vocabulary.xlsx';
  final csvPath = 'assets/data/mandarin_vocabulary.csv';

  final file = File(xlsxPath);
  final bytes = await file.readAsBytes();
  final excel = Excel.decodeBytes(bytes);

  if (excel.tables.isEmpty) {
    print('No worksheets found');
    return;
  }

  final sheet = excel.tables['Vocabulary'] ?? excel.tables.values.first;
  print('Sheet: ${sheet.maxColumns} cols x ${sheet.maxRows} rows');

  final rows = <List<String>>[];
  for (var row in sheet.rows) {
    final cells = row.map((cell) {
      final value = cell?.value;
      if (value == null) return '';
      if (value is TextCellValue) return value.value.text ?? '';
      return value.toString();
    }).toList();
    rows.add(cells);
  }

  print('Total rows: ${rows.length}');

  final csvString = const ListToCsvConverter().convert(rows);
  await File(csvPath).writeAsString(csvString, flush: true);
  print('CSV written to $csvPath (${csvString.length} chars)');
}