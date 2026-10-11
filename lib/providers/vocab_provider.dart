import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/vocabulary.dart';
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

  int _currentPage = 0;
  int get currentPage => _currentPage;
  static const int pageSize = 50;

  int _totalCount = 0;
  int get totalCount => _totalCount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    await DatabaseHelper.instance.ensureSeeded();
    await loadVocabs();
  }

  Future<void> loadVocabs({
    String? category,
    String? searchQuery,
    int page = 0,
  }) async {
    _isLoading = true;
    _currentPage = page;

    notifyListeners();

    try {
      _vocabs = await DatabaseHelper.instance.getVocabulariesPaged(
        limit: pageSize,
        offset: page * pageSize,
        category: category == 'All' ? null : category,
        searchQuery: searchQuery?.isEmpty ?? true ? null : searchQuery,
      );
      _totalCount = await DatabaseHelper.instance.getVocabulariesCount(
        category: category == 'All' ? null : category,
        searchQuery: searchQuery?.isEmpty ?? true ? null : searchQuery,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNextPage() async {
    if (_isLoading || (_currentPage + 1) * pageSize >= _totalCount) return;
    await loadVocabs(page: _currentPage + 1);
  }

  Future<void> loadPreviousPage() async {
    if (_isLoading || _currentPage == 0) return;
    await loadVocabs(page: _currentPage - 1);
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
          category: Vocabulary.normalizeCategory(
            category is String ? category : null,
          ),
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

  Future<ImportResult> importFromCsvBytes(List<int> bytes) async {
    final result = ExcelService.importCsv(bytes);
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

  Future<List<String>> getDistinctCategories() async {
    return DatabaseHelper.instance.getDistinctCategories();
  }

  Future<List<Vocabulary>> getVocabulariesByCategory(
    String category, {
    int limit = 100,
  }) async {
    return DatabaseHelper.instance.getVocabulariesByCategory(
      category,
      limit: limit,
    );
  }

  Future<List<Vocabulary>> getVocabulariesCumulative(
    String category, {
    int limit = 10000,
  }) async {
    return DatabaseHelper.instance.getVocabulariesCumulative(
      category,
      limit: limit,
    );
  }

  Future<int> getVocabulariesCountCumulative(String category) async {
    return DatabaseHelper.instance.getVocabulariesCountCumulative(category);
  }

  Future<void> normalizeCategories() async {
    await DatabaseHelper.instance.normalizeAllCategories();
    await loadVocabs();
  }
}
