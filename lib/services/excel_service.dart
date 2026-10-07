import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../models/vocabulary.dart';

class VocabularyImportData {
  const VocabularyImportData({
    required this.vocabs,
    required this.skippedCount,
  });

  final List<Vocabulary> vocabs;
  final int skippedCount;
}

class ExcelService {
  static const headers = [
    'hanzi',
    'traditionalHanzi',
    'pinyin',
    'zhuyin',
    'meaning',
    'category',
  ];

  static Uint8List exportXlsx(List<Vocabulary> vocabs) {
    final excel = Excel.createExcel();
    final sheet = excel['Vocabulary'];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final vocab in vocabs) {
      sheet.appendRow(
        [
          vocab.hanzi,
          vocab.traditionalHanzi ?? '',
          vocab.pinyin,
          vocab.zhuyin ?? '',
          vocab.meaning,
          vocab.category,
        ].map(TextCellValue.new).toList(),
      );
    }
    return Uint8List.fromList(excel.encode()!);
  }

  static Uint8List createTemplate() {
    final excel = Excel.createExcel();
    final sheet = excel['Vocabulary'];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    sheet.appendRow(
      [
        '你好',
        '你好',
        'nǐ hǎo',
        'ㄋㄧˇ ㄏㄠˇ',
        'hello',
        'HSK 1',
      ].map(TextCellValue.new).toList(),
    );
    sheet.appendRow(
      [
        '谢谢',
        '謝謝',
        'xiè xie',
        'ㄒㄧㄝˋ ˙ㄒㄧㄝ',
        'thank you',
        'HSK 1',
      ].map(TextCellValue.new).toList(),
    );
    return Uint8List.fromList(excel.encode()!);
  }

  static Uint8List exportCsv(List<Vocabulary> vocabs) => Uint8List.fromList(
    utf8.encode(
      const ListToCsvConverter().convert([
        headers,
        ...vocabs.map(
          (vocab) => [
            vocab.hanzi,
            vocab.traditionalHanzi ?? '',
            vocab.pinyin,
            vocab.zhuyin ?? '',
            vocab.meaning,
            vocab.category,
          ],
        ),
      ]),
    ),
  );

  static VocabularyImportData importXlsx(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw const FormatException('Excel file has no worksheet.');
    }
    final sheet = excel.tables['Vocabulary'] ?? excel.tables.values.first;
    final rows = sheet.rows
        .map(
          (row) => row.map((cell) {
            final value = cell?.value;
            return value is TextCellValue
                ? value.value.text ?? ''
                : value?.toString() ?? '';
          }).toList(),
        )
        .toList();
    return _parseRows(rows);
  }

  static VocabularyImportData importCsv(List<int> bytes) {
    final rows = const CsvToListConverter().convert(utf8.decode(bytes));
    return _parseRows(
      rows.map((row) => row.map((cell) => cell.toString()).toList()).toList(),
    );
  }

  static VocabularyImportData _parseRows(List<List<String>> rows) {
    if (rows.isEmpty) {
      return const VocabularyImportData(vocabs: [], skippedCount: 0);
    }
    final columnIndexes = <String, int>{};
    for (var index = 0; index < rows.first.length; index++) {
      columnIndexes[rows.first[index].trim()] = index;
    }
    if (!['hanzi', 'pinyin', 'meaning'].every(columnIndexes.containsKey)) {
      throw const FormatException('Required headers: hanzi, pinyin, meaning.');
    }

    final vocabs = <Vocabulary>[];
    var skippedCount = 0;
    for (final row in rows.skip(1)) {
      String value(String header) {
        final index = columnIndexes[header];
        return index == null || index >= row.length ? '' : row[index].trim();
      }

      if (row.every((cell) => cell.trim().isEmpty)) continue;
      final hanzi = value('hanzi');
      final pinyin = value('pinyin');
      final meaning = value('meaning');
      if (hanzi.isEmpty || pinyin.isEmpty || meaning.isEmpty) {
        skippedCount++;
        continue;
      }
      final traditionalHanzi = value('traditionalHanzi');
      final zhuyin = value('zhuyin');
      final category = value('category');
      vocabs.add(
        Vocabulary(
          hanzi: hanzi,
          traditionalHanzi: traditionalHanzi.isEmpty ? null : traditionalHanzi,
          pinyin: pinyin,
          zhuyin: zhuyin.isEmpty ? null : zhuyin,
          meaning: meaning,
          category: category.isEmpty ? 'Imported' : category,
        ),
      );
    }
    return VocabularyImportData(vocabs: vocabs, skippedCount: skippedCount);
  }
}
