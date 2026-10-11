import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/vocabulary.dart';
import '../utils/pinyin_zhuyin.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static const _csvAsset = 'assets/data/mandarin_vocabulary.csv';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = p.join(dbPath, 'mandarin.db');
    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE vocabularies (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              hanzi TEXT NOT NULL,
              pinyin TEXT NOT NULL,
              zhuyin TEXT,
              traditionalHanzi TEXT,
              meaning TEXT NOT NULL,
              category TEXT NOT NULL,
              reviewCount INTEGER NOT NULL DEFAULT 0,
              correctCount INTEGER NOT NULL DEFAULT 0,
              lastReviewed TEXT NOT NULL DEFAULT ''
            )
          ''');
          await _seedDatabase(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE vocabularies ADD COLUMN reviewCount INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              'ALTER TABLE vocabularies ADD COLUMN correctCount INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              "ALTER TABLE vocabularies ADD COLUMN lastReviewed TEXT NOT NULL DEFAULT ''",
            );
          }
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE vocabularies ADD COLUMN zhuyin TEXT');
            await db.execute(
              'ALTER TABLE vocabularies ADD COLUMN traditionalHanzi TEXT',
            );
          }
          if (oldVersion < 4) {
            await _normalizeCategories(db);
          }
          if (oldVersion < 5) {
            await db.execute('DELETE FROM vocabularies');
            await _seedDatabase(db);
          }
          if (oldVersion < 6) {
            await db.execute('DELETE FROM vocabularies');
            await _seedDatabase(db);
          }
        },
      ),
    );
  }

  Future<void> _normalizeCategories(Database db) async {
    final batch = db.batch();

    batch.update(
      'vocabularies',
      {'category': 'TOCFL A1'},
      where: "category LIKE 'HSK 1' OR category LIKE 'HSK 2' OR category LIKE 'HSK 3' OR category = '' OR category IS NULL OR category NOT IN ('TOCFL A1','TOCFL A2','TOCFL B1','TOCFL B2','TOCFL C1','TOCFL C2')",
    );

    batch.update('vocabularies', {
      'category': 'TOCFL A2',
    }, where: "category LIKE 'HSK 4'");

    batch.update('vocabularies', {
      'category': 'TOCFL B1',
    }, where: "category LIKE 'HSK 5'");

    batch.update('vocabularies', {
      'category': 'TOCFL B2',
    }, where: "category LIKE 'HSK 6'");

    await batch.commit(noResult: true);
  }

  Future<void> normalizeAllCategories() async {
    final db = await database;
    await _normalizeCategories(db);
  }

  Future<void> ensureSeeded() async {
    final db = await database;
    await _autoSeedIfEmpty(db);
  }

  Future<void> resetAndReloadEnglishVocabulary() async {
    final db = await database;
    await db.execute('DELETE FROM vocabularies');
    await _seedDatabase(db);
  }

  Future<void> _seedDatabase(Database db) async {
    await _autoSeedIfEmpty(db);
  }

  Future<void> _autoSeedIfEmpty(Database db) async {
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM vocabularies'),
        ) ??
        0;
    if (count > 0) return;

    final csvData = await rootBundle.loadString(_csvAsset);
    final vocabs = _parseCsvToVocabularies(csvData);

    if (vocabs.isEmpty) return;

    final batch = db.batch();
    for (final vocab in vocabs) {
      batch.insert('vocabularies', vocab.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  List<Vocabulary> _parseCsvToVocabularies(String csvData) {
    final rows = const CsvToListConverter().convert(csvData);
    if (rows.isEmpty) return [];

    final headerRow = rows.first
        .map((v) => v.toString().trim().toLowerCase())
        .toList();
    final hanziIdx = headerRow.indexOf('hanzi');
    final pinyinIdx = headerRow.indexOf('pinyin');
    final meaningIdx = headerRow.indexOf('meaning');
    final zhuyinIdx = headerRow.indexOf('zhuyin');
    final traditionalIdx = headerRow.indexOf('traditionalhanzi');
    final categoryIdx = headerRow.indexOf('category');

    if (hanziIdx == -1 || pinyinIdx == -1 || meaningIdx == -1) return [];

    final vocabs = <Vocabulary>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((v) => v.toString().trim().isEmpty)) continue;

      final hanzi = row[hanziIdx].toString().trim();
      final pinyin = row[pinyinIdx].toString().trim();
      final meaning = row[meaningIdx].toString().trim();
      if (hanzi.isEmpty || pinyin.isEmpty) continue;
      final cleanMeaning = meaning.isEmpty ? '-' : meaning;

      final traditionalHanzi =
          traditionalIdx >= 0 && traditionalIdx < row.length
          ? row[traditionalIdx].toString().trim()
          : '';
      final zhuyin = zhuyinIdx >= 0 && zhuyinIdx < row.length
          ? row[zhuyinIdx].toString().trim()
          : '';
      final csvCategory = categoryIdx >= 0 && categoryIdx < row.length
          ? row[categoryIdx].toString().trim()
          : '';

      // Auto-assign TOCFL category based on row index (0-based from data rows)
      final rowIndex = i - 1;
      String inferredCategory;
      if (rowIndex < 446) {
        inferredCategory = 'TOCFL A1';
      } else if (rowIndex < 894) {
        inferredCategory = 'TOCFL A2';
      } else if (rowIndex < 1376) {
        inferredCategory = 'TOCFL B1';
      } else if (rowIndex < 4376) {
        inferredCategory = 'TOCFL B2';
      } else if (rowIndex < 9376) {
        inferredCategory = 'TOCFL C1';
      } else {
        inferredCategory = 'TOCFL C2';
      }

      // Use CSV category if valid TOCFL category, otherwise use inferred
      final category = Vocabulary.tocflCategories.contains(csvCategory)
          ? csvCategory
          : inferredCategory;

      String generatedZhuyin;
      if (zhuyin.isEmpty) {
        try {
          generatedZhuyin = pinyinToZhuyin(pinyin);
        } catch (_) {
          generatedZhuyin = pinyin; // Safe fallback
        }
      } else {
        generatedZhuyin = zhuyin;
      }

      vocabs.add(
        Vocabulary(
          hanzi: hanzi,
          traditionalHanzi: traditionalHanzi.isEmpty ? null : traditionalHanzi,
          pinyin: pinyin,
          zhuyin: generatedZhuyin.isEmpty ? null : generatedZhuyin,
          meaning: cleanMeaning,
          category: category,
        ),
      );
    }
    return vocabs;
  }

  Future<int> insertVocab(Vocabulary vocab) async {
    final map = vocab.toMap()..remove('id');
    return (await database).insert('vocabularies', map);
  }

  Future<List<Vocabulary>> getAllVocabularies() async {
    return getVocabulariesPaged(limit: 10000);
  }

  Future<List<Vocabulary>> getVocabulariesPaged({
    int limit = 50,
    int offset = 0,
    String? category,
    String? searchQuery,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <Object>[];

    if (category != null && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add(
        '(hanzi LIKE ? OR traditionalHanzi LIKE ? OR pinyin LIKE ? OR meaning LIKE ? OR zhuyin LIKE ?)',
      );
      final searchTerm = '%$searchQuery%';
      whereArgs.addAll([
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
      ]);
    }

    final where = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final maps = await db.rawQuery(
      'SELECT * FROM vocabularies $where ORDER BY category, hanzi LIMIT ? OFFSET ?',
      [...whereArgs, limit, offset],
    );
    return maps.map(Vocabulary.fromMap).toList();
  }

  Future<int> getVocabulariesCount({
    String? category,
    String? searchQuery,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <Object>[];

    if (category != null && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add(
        '(hanzi LIKE ? OR traditionalHanzi LIKE ? OR pinyin LIKE ? OR meaning LIKE ? OR zhuyin LIKE ?)',
      );
      final searchTerm = '%$searchQuery%';
      whereArgs.addAll([
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
        searchTerm,
      ]);
    }

    final where = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM vocabularies $where',
      whereArgs,
    );
    return result.first['count'] as int;
  }

  Future<int> deleteVocab(int id) async =>
      (await database).delete('vocabularies', where: 'id = ?', whereArgs: [id]);

  Future<void> insertBatch(List<Vocabulary> vocabs) async {
    if (vocabs.isEmpty) return;
    final batch = (await database).batch();
    for (final vocab in vocabs) {
      batch.insert('vocabularies', vocab.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateReviewStats(int id, bool correct) async {
    await (await database).rawUpdate(
      '''
      UPDATE vocabularies
      SET reviewCount = reviewCount + 1,
          correctCount = correctCount + ${correct ? 1 : 0},
          lastReviewed = ?
      WHERE id = ?
    ''',
      [DateTime.now().toIso8601String(), id],
    );
  }

  Future<List<Vocabulary>> getVocabulariesByCategory(
    String category, {
    int limit = 50,
  }) async {
    final maps = await (await database).query(
      'vocabularies',
      where: 'category = ?',
      whereArgs: [category],
      limit: limit,
      orderBy: 'hanzi',
    );
    return maps.map(Vocabulary.fromMap).toList();
  }

  Future<List<String>> getDistinctCategories() async {
    final maps = await (await database).rawQuery(
      'SELECT DISTINCT category FROM vocabularies ORDER BY category',
    );
    return maps.map((m) => m['category'] as String).toList();
  }

  static List<String> _cumulativeCategoriesFor(String category) {
    const order = [
      'TOCFL A1',
      'TOCFL A2',
      'TOCFL B1',
      'TOCFL B2',
      'TOCFL C1',
      'TOCFL C2',
    ];
    if (category == 'All') return order;
    final idx = order.indexOf(category);
    if (idx < 0) return [category];
    return order.sublist(0, idx + 1);
  }

  Future<List<Vocabulary>> getVocabulariesCumulative(
    String category, {
    int limit = 10000,
  }) async {
    final categories = _cumulativeCategoriesFor(category);
    if (categories.isEmpty) return [];
    final placeholders = categories.map((_) => '?').join(',');
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT * FROM vocabularies WHERE category IN ($placeholders) ORDER BY category, hanzi LIMIT ?',
      [...categories, limit],
    );
    return maps.map(Vocabulary.fromMap).toList();
  }

  Future<int> getVocabulariesCountCumulative(String category) async {
    final categories = _cumulativeCategoriesFor(category);
    if (categories.isEmpty) return 0;
    final placeholders = categories.map((_) => '?').join(',');
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM vocabularies WHERE category IN ($placeholders)',
      categories,
    );
    return result.first['count'] as int;
  }

  Future<List<Vocabulary>> getQuizVocabulary({
    required String category,
    required int limit,
  }) async {
    final db = await database;
    List<Vocabulary> vocabs;
    if (category == 'All') {
      final maps = await db.rawQuery(
        'SELECT * FROM vocabularies ORDER BY RANDOM() LIMIT ?',
        [limit],
      );
      vocabs = maps.map(Vocabulary.fromMap).toList();
    } else {
      final categories = _cumulativeCategoriesFor(category);
      final placeholders = categories.map((_) => '?').join(',');
      final maps = await db.rawQuery(
        'SELECT * FROM vocabularies WHERE category IN ($placeholders) ORDER BY RANDOM() LIMIT ?',
        [...categories, limit],
      );
      vocabs = maps.map(Vocabulary.fromMap).toList();
    }

    if (vocabs.length < 4 && category != 'All') {
      final fallbackMaps = await db.rawQuery(
        'SELECT * FROM vocabularies ORDER BY RANDOM() LIMIT ?',
        [limit],
      );
      final fallbackVocabs = fallbackMaps.map(Vocabulary.fromMap).toList();
      if (fallbackVocabs.length >= 4) {
        return fallbackVocabs;
      }
    }
    return vocabs;
  }
}
