import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/vocabulary.dart';
import '../services/csv_import_service.dart';
import '../services/database_helper.dart';
import '../services/excel_service.dart';

class ImportResult {
  const ImportResult({required this.importedCount, required this.skippedCount});

  final int importedCount;
  final int skippedCount;
}

class VocabProvider extends ChangeNotifier {
  List<Vocabulary> _vocabs = [];
  List<Vocabulary> get vocabs => _vocabs;

  Future<void> loadVocabs() async {
    _vocabs = await DatabaseHelper.instance.getAllVocabularies();
    notifyListeners();
  }

  Future<void> addVocab(Vocabulary vocab) async {
    await DatabaseHelper.instance.insertVocab(vocab);
    await loadVocabs();
  }

  Future<void> deleteVocab(int id) async {
    await DatabaseHelper.instance.deleteVocab(id);
    await loadVocabs();
  }

  Future<ImportResult> importFromJsonFile(String path) async {
    final content = await File(path).readAsString();
    final decoded = json.decode(content);
    if (decoded is! List) {
      throw const FormatException(
        'JSON must contain a list of vocabulary rows.',
      );
    }

    final vocabs = <Vocabulary>[];
    var skippedCount = 0;
    for (final row in decoded) {
      if (row is! Map) {
        skippedCount++;
        continue;
      }

      final hanzi = row['hanzi'];
      final pinyin = row['pinyin'];
      final meaning = row['meaning'];
      if (hanzi is! String ||
          pinyin is! String ||
          meaning is! String ||
          hanzi.trim().isEmpty ||
          pinyin.trim().isEmpty ||
          meaning.trim().isEmpty) {
        skippedCount++;
        continue;
      }

      final category = row['category'];
      final zhuyin = row['zhuyin'];
      final traditionalHanzi = row['traditionalHanzi'];
      vocabs.add(
        Vocabulary(
          hanzi: hanzi.trim(),
          pinyin: pinyin.trim(),
          zhuyin: zhuyin is String && zhuyin.trim().isNotEmpty
              ? zhuyin.trim()
              : null,
          traditionalHanzi:
              traditionalHanzi is String && traditionalHanzi.trim().isNotEmpty
              ? traditionalHanzi.trim()
              : null,
          meaning: meaning.trim(),
          category: category is String && category.trim().isNotEmpty
              ? category.trim()
              : 'Imported',
        ),
      );
    }

    await DatabaseHelper.instance.insertBatch(vocabs);
    await loadVocabs();
    return ImportResult(
      importedCount: vocabs.length,
      skippedCount: skippedCount,
    );
  }

  Future<ImportResult> importFromCsvFile(String path) async {
    final result = await CsvImportService.parseFile(path);
    await DatabaseHelper.instance.insertBatch(result.vocabs);
    await loadVocabs();
    return ImportResult(
      importedCount: result.vocabs.length,
      skippedCount: result.skippedCount,
    );
  }

  Future<ImportResult> importFromExcelBytes(List<int> bytes) async {
    final result = ExcelService.importXlsx(bytes);
    await DatabaseHelper.instance.insertBatch(result.vocabs);
    await loadVocabs();
    return ImportResult(
      importedCount: result.vocabs.length,
      skippedCount: result.skippedCount,
    );
  }
}
