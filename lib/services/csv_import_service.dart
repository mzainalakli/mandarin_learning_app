import 'dart:io';

import 'package:csv/csv.dart';

import '../models/vocabulary.dart';

class ImportParseResult {
  const ImportParseResult({required this.vocabs, required this.skippedCount});

  final List<Vocabulary> vocabs;
  final int skippedCount;
}

class CsvImportService {
  static Future<ImportParseResult> parseFile(String path) async {
    final content = await File(path).readAsString();
    final rows = const CsvToListConverter().convert(content);
    if (rows.isEmpty) {
      return const ImportParseResult(vocabs: [], skippedCount: 0);
    }

    var startRow = 0;
    final firstRow = rows.first
        .map((value) => value.toString().trim().toLowerCase())
        .toList();
    if (firstRow.length >= 3 &&
        firstRow[0] == 'hanzi' &&
        firstRow[1] == 'pinyin' &&
        firstRow[2] == 'meaning') {
      startRow = 1;
    }

    final vocabs = <Vocabulary>[];
    var skippedCount = 0;
    for (var i = startRow; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((value) => value.toString().trim().isEmpty)) continue;
      if (row.length < 3) {
        skippedCount++;
        continue;
      }

      final hanzi = row[0].toString().trim();
      final pinyin = row[1].toString().trim();
      final meaning = row[2].toString().trim();
      if (hanzi.isEmpty || pinyin.isEmpty || meaning.isEmpty) {
        skippedCount++;
        continue;
      }

      final category = row.length >= 4 ? row[3].toString().trim() : '';
      final zhuyin = row.length >= 5 ? row[4].toString().trim() : '';
      final traditionalHanzi = row.length >= 6 ? row[5].toString().trim() : '';
      vocabs.add(
        Vocabulary(
          hanzi: hanzi,
          pinyin: pinyin,
          meaning: meaning,
          category: category.isEmpty ? 'Imported' : category,
          zhuyin: zhuyin.isEmpty ? null : zhuyin,
          traditionalHanzi: traditionalHanzi.isEmpty ? null : traditionalHanzi,
        ),
      );
    }
    return ImportParseResult(vocabs: vocabs, skippedCount: skippedCount);
  }
}
