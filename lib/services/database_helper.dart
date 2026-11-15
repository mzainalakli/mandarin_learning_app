import 'dart:math';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/vocab_stats.dart';
import '../models/vocabulary.dart';
import '../models/deck_filter.dart';
import '../models/library_list.dart';
import '../models/review_event.dart';
import '../utils/pinyin_zhuyin.dart';
import 'leitner.dart';

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

  /// Uses [db] (e.g. in-memory) instead of the on-disk database and creates
  /// the empty schema on it. Tests only.
  @visibleForTesting
  Future<void> useDatabaseForTest(Database db) async {
    _db = db;
    await _createTables(db);
  }

  /// Opens (and migrates) the database file at [path]. Tests only.
  @visibleForTesting
  Future<Database> openAtPathForTest(String path) async {
    _db = await _openAt(path);
    return _db!;
  }

  /// Forgets the open database so the next access reopens it. Tests only.
  @visibleForTesting
  void resetForTest() => _db = null;

  Future<Database> _initDb() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    return _openAt(p.join(dbPath, 'mandarin.db'));
  }

  Future<Database> _openAt(String path) {
    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) async {
          await _createTables(db);
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
          if (oldVersion < 7) {
            await _createLibraryTables(db);
          }
          if (oldVersion < 8) {
            // Additive only: new tables plus a backfill from the old totals.
            await _createStatsTables(db);
            await _backfillProgress(db);
          }
        },
      ),
    );
  }

  Future<void> _createTables(Database db) async {
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
    await _createLibraryTables(db);
    await _createStatsTables(db);
  }

  /// Answer history and per-word schedule. Foreign keys are declared for
  /// documentation only: `PRAGMA foreign_keys` is off in this app, so
  /// [deleteVocab] and [resetAndReloadEnglishVocabulary] clean up explicitly.
  Future<void> _createStatsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS review_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vocab_id INTEGER NOT NULL,
        ts INTEGER NOT NULL,
        day INTEGER NOT NULL,
        module TEXT NOT NULL,
        mode TEXT NOT NULL,
        correct INTEGER NOT NULL,
        is_first_attempt INTEGER NOT NULL,
        session_id INTEGER NOT NULL,
        response_ms INTEGER,
        outcome TEXT NOT NULL,
        FOREIGN KEY (vocab_id) REFERENCES vocabularies(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_vocab_ts ON review_events(vocab_id, ts)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_ts ON review_events(ts)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_day ON review_events(day)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vocab_progress (
        vocab_id INTEGER PRIMARY KEY,
        box INTEGER NOT NULL DEFAULT 0,
        next_due INTEGER NOT NULL,
        first_attempts INTEGER NOT NULL DEFAULT 0,
        first_correct INTEGER NOT NULL DEFAULT 0,
        wrong_streak INTEGER NOT NULL DEFAULT 0,
        last_first_ts INTEGER,
        FOREIGN KEY (vocab_id) REFERENCES vocabularies(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_progress_due ON vocab_progress(next_due)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_progress_box ON vocab_progress(box)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_vocab_category ON vocabularies(category)',
    );
  }

  /// Accuracy at or above which a word with old totals starts in
  /// [legacyBackfillGoodBox]; below it the word starts in box 0.
  static const legacyBackfillMinAccuracy = 0.8;
  static const legacyBackfillGoodBox = 2;

  /// Gives words that already have review totals a starting schedule so they
  /// are not treated as unseen. Insert-only; never touches existing data.
  Future<void> _backfillProgress(Database db) async {
    await db.rawInsert(
      '''
      INSERT OR IGNORE INTO vocab_progress (vocab_id, box, next_due)
      SELECT id,
             CASE WHEN correctCount * 1.0 / reviewCount >= ? THEN ? ELSE 0 END,
             ?
      FROM vocabularies WHERE reviewCount > 0
    ''',
      [
        legacyBackfillMinAccuracy,
        legacyBackfillGoodBox,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      ],
    );
  }

  Future<void> _createLibraryTables(Database db) async {
    await db.execute('''
      CREATE TABLE user_libraries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE library_vocab_items (
        library_id INTEGER NOT NULL,
        vocab_id INTEGER NOT NULL,
        PRIMARY KEY (library_id, vocab_id),
        FOREIGN KEY (library_id) REFERENCES user_libraries(id) ON DELETE CASCADE,
        FOREIGN KEY (vocab_id) REFERENCES vocabularies(id) ON DELETE CASCADE
      )
    ''');
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
    await db.execute('DELETE FROM review_events');
    await db.execute('DELETE FROM vocab_progress');
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

  /// Builds the shared WHERE clause. [excludeLibraryId] hides words already
  /// in that library.
  (String, List<Object>) _vocabFilter({
    String? category,
    String? searchQuery,
    int? excludeLibraryId,
  }) {
    final clauses = <String>[];
    final args = <Object>[];
    if (category != null && category != 'All') {
      clauses.add('category = ?');
      args.add(category);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      clauses.add(
        '(hanzi LIKE ? OR traditionalHanzi LIKE ? OR pinyin LIKE ? OR meaning LIKE ? OR zhuyin LIKE ?)',
      );
      final term = '%$searchQuery%';
      args.addAll([term, term, term, term, term]);
    }
    if (excludeLibraryId != null) {
      clauses.add(
        'NOT EXISTS (SELECT 1 FROM library_vocab_items lvi '
        'WHERE lvi.library_id = ? AND lvi.vocab_id = vocabularies.id)',
      );
      args.add(excludeLibraryId);
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    return (where, args);
  }

  Future<List<Vocabulary>> getVocabulariesPaged({
    int limit = 50,
    int offset = 0,
    String? category,
    String? searchQuery,
    int? excludeLibraryId,
  }) async {
    final db = await database;
    final (where, args) = _vocabFilter(
      category: category,
      searchQuery: searchQuery,
      excludeLibraryId: excludeLibraryId,
    );
    final maps = await db.rawQuery(
      'SELECT * FROM vocabularies $where ORDER BY category, hanzi LIMIT ? OFFSET ?',
      [...args, limit, offset],
    );
    return maps.map(Vocabulary.fromMap).toList();
  }

  Future<int> getVocabulariesCount({
    String? category,
    String? searchQuery,
    int? excludeLibraryId,
  }) async {
    final db = await database;
    final (where, args) = _vocabFilter(
      category: category,
      searchQuery: searchQuery,
      excludeLibraryId: excludeLibraryId,
    );
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM vocabularies $where',
      args,
    );
    return result.first['count'] as int;
  }

  /// Ids of every word matching the filter (no limit), in list order.
  Future<List<int>> getVocabularyIds({
    String? category,
    String? searchQuery,
    int? excludeLibraryId,
  }) async {
    final db = await database;
    final (where, args) = _vocabFilter(
      category: category,
      searchQuery: searchQuery,
      excludeLibraryId: excludeLibraryId,
    );
    final rows = await db.rawQuery(
      'SELECT id FROM vocabularies $where ORDER BY category, hanzi',
      args,
    );
    return rows.map((r) => r['id'] as int).toList();
  }

  Future<Set<int>> getLibraryVocabIds(int libraryId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT vocab_id FROM library_vocab_items WHERE library_id = ?',
      [libraryId],
    );
    return rows.map((r) => r['vocab_id'] as int).toSet();
  }

  /// Deletes the word together with its answer history, schedule and
  /// library entries (foreign keys are not enforced, so this is explicit).
  Future<int> deleteVocab(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      for (final table in const [
        'review_events',
        'vocab_progress',
        'library_vocab_items',
      ]) {
        await txn.delete(table, where: 'vocab_id = ?', whereArgs: [id]);
      }
      return txn.delete('vocabularies', where: 'id = ?', whereArgs: [id]);
    });
  }

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

  /// Saves one answer atomically: the legacy totals on the word (every
  /// answer, as before), the event row, and - for a first attempt only - the
  /// Leitner state in `vocab_progress`.
  Future<void> recordReview(ReviewEvent event) async {
    final db = await database;
    final nowMs = event.timestamp.toUtc().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        '''
        UPDATE vocabularies
        SET reviewCount = reviewCount + 1,
            correctCount = correctCount + ?,
            lastReviewed = ?
        WHERE id = ?
      ''',
        [
          event.correct ? 1 : 0,
          event.timestamp.toIso8601String(),
          event.vocabId,
        ],
      );
      await txn.insert('review_events', event.toMap());
      if (!event.isFirstAttempt) return;

      final rows = await txn.query(
        'vocab_progress',
        where: 'vocab_id = ?',
        whereArgs: [event.vocabId],
      );
      final old = rows.isEmpty ? null : rows.first;
      final state = Leitner.next(
        box: old?['box'] as int?,
        nextDue: old?['next_due'] as int?,
        wrongStreak: (old?['wrong_streak'] as int?) ?? 0,
        correct: event.correct,
        nowMs: nowMs,
      );
      await txn.insert('vocab_progress', {
        'vocab_id': event.vocabId,
        'box': state.box,
        'next_due': state.nextDue,
        'first_attempts': ((old?['first_attempts'] as int?) ?? 0) + 1,
        'first_correct':
            ((old?['first_correct'] as int?) ?? 0) + (event.correct ? 1 : 0),
        'wrong_streak': state.wrongStreak,
        'last_first_ts': nowMs,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
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

  Future<VocabStats> getVocabStats() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT category,
             COUNT(*) AS words,
             COALESCE(SUM(reviewCount), 0) AS reviews,
             COALESCE(SUM(correctCount), 0) AS correct
      FROM vocabularies
      GROUP BY category
    ''');
    final counts = <String, int>{};
    var reviews = 0;
    var correct = 0;
    for (final row in rows) {
      counts[row['category'] as String] = row['words'] as int;
      reviews += row['reviews'] as int;
      correct += row['correct'] as int;
    }
    return VocabStats(
      countsByCategory: counts,
      totalReviews: reviews,
      totalCorrect: correct,
    );
  }

  Future<List<String>> getDistinctCategories() async {
    final maps = await (await database).rawQuery(
      'SELECT DISTINCT category FROM vocabularies ORDER BY category',
    );
    return maps.map((m) => m['category'] as String).toList();
  }

  /// Public view of the cumulative TOCFL bands (A2 = A1 + A2, ...).
  static List<String> cumulativeCategoriesFor(String category) =>
      _cumulativeCategoriesFor(category);

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

  // ===== DECK CANDIDATES (weak / due selection) =====

  /// Weak = recently missed, or still in the lowest box after a miss, or a
  /// word that only has old totals and started in box 0 (see migration).
  static String get _weakPredicate =>
      '(p.wrong_streak > 0 OR '
      '(p.first_attempts > p.first_correct AND p.box <= ${Leitner.weakMaxBox}) OR '
      '(p.first_attempts = 0 AND p.box = 0))';

  /// Lower ratio = weaker. Words without first attempts count as neutral.
  static const _ratioExpr =
      '(CASE WHEN p.first_attempts = 0 THEN 0.5 '
      'ELSE p.first_correct * 1.0 / p.first_attempts END)';

  /// FROM/WHERE pieces shared by the candidate queries. The word table is
  /// aliased `v`; `extraWhere` is ANDed in.
  (String, List<Object>) _deckFilter(DeckFilter filter, String extraWhere) {
    final clauses = <String>[if (extraWhere.isNotEmpty) extraWhere];
    final args = <Object>[];
    final categories = filter.categories;
    if (categories != null) {
      clauses.add('v.category IN (${categories.map((_) => '?').join(',')})');
      args.addAll(categories);
    }
    final libraryId = filter.libraryId;
    if (libraryId != null) {
      clauses.add(
        'EXISTS (SELECT 1 FROM library_vocab_items lvi '
        'WHERE lvi.library_id = ? AND lvi.vocab_id = v.id)',
      );
      args.add(libraryId);
    }
    return (clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}', args);
  }

  /// Due words, weakest first (index on `next_due`), each flagged weak or
  /// not. Returns at most [limit] rows; the caller samples from them.
  Future<List<({int id, bool weak})>> getDueCandidates(
    DeckFilter filter, {
    required int nowMs,
    required int limit,
  }) async {
    if (limit <= 0) return [];
    final db = await database;
    final (where, args) = _deckFilter(filter, 'p.next_due <= ?');
    final rows = await db.rawQuery(
      '''
      SELECT v.id, (CASE WHEN $_weakPredicate THEN 1 ELSE 0 END) AS weak
      FROM vocab_progress p
      JOIN vocabularies v ON v.id = p.vocab_id
      $where
      ORDER BY (CASE WHEN $_weakPredicate THEN 0 ELSE 1 END),
               p.wrong_streak DESC, $_ratioExpr ASC, p.next_due ASC
      LIMIT ?
    ''',
      [nowMs, ...args, limit],
    );
    return [
      for (final r in rows) (id: r['id'] as int, weak: (r['weak'] as int) == 1),
    ];
  }

  /// Ids matching [filter]. With [unseenOnly], only words that were never
  /// answered (no progress row and no old totals).
  Future<List<int>> getDeckIds(
    DeckFilter filter, {
    bool unseenOnly = false,
  }) async {
    final db = await database;
    final (where, args) = _deckFilter(
      filter,
      unseenOnly
          ? 'v.reviewCount = 0 AND NOT EXISTS '
                '(SELECT 1 FROM vocab_progress p WHERE p.vocab_id = v.id)'
          : '',
    );
    final rows = await db.rawQuery(
      'SELECT v.id FROM vocabularies v $where',
      args,
    );
    return rows.map((r) => r['id'] as int).toList();
  }

  /// Weakest words overall (ignores category/library), worst first.
  Future<List<int>> getWeakestIds({required int limit}) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT p.vocab_id AS id FROM vocab_progress p
      JOIN vocabularies v ON v.id = p.vocab_id
      WHERE $_weakPredicate
      ORDER BY p.wrong_streak DESC, $_ratioExpr ASC,
               (p.first_attempts - p.first_correct) DESC, p.next_due ASC
      LIMIT ?
    ''',
      [limit],
    );
    return rows.map((r) => r['id'] as int).toList();
  }

  Future<int> getWeakWordCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM vocab_progress p '
            'JOIN vocabularies v ON v.id = p.vocab_id WHERE $_weakPredicate',
          ),
        ) ??
        0;
  }

  /// Full rows for [ids], in the order of [ids]. Missing ids are skipped.
  Future<List<Vocabulary>> getVocabulariesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await database;
    final byId = <int, Vocabulary>{};
    for (var i = 0; i < ids.length; i += _idChunk) {
      final chunk = ids.sublist(i, min(i + _idChunk, ids.length));
      final rows = await db.rawQuery(
        'SELECT * FROM vocabularies WHERE id IN (${chunk.map((_) => '?').join(',')})',
        chunk,
      );
      for (final row in rows) {
        final vocab = Vocabulary.fromMap(row);
        byId[vocab.id!] = vocab;
      }
    }
    return [for (final id in ids) ?byId[id]];
  }

  /// Ids per `IN (...)` query, below SQLite's variable limit.
  static const _idChunk = 500;

  // ===== LIBRARY METHODS =====

  Future<int> createLibrary(String name) async {
    final db = await database;
    return db.insert('user_libraries', {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<LibraryList>> getAllLibraries() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT l.id, l.name, l.created_at,
             COUNT(lvi.vocab_id) as item_count
      FROM user_libraries l
      LEFT JOIN library_vocab_items lvi ON l.id = lvi.library_id
      GROUP BY l.id, l.name, l.created_at
      ORDER BY l.created_at DESC
    ''');
    return maps.map(_libraryListFromMap).toList();
  }

  Future<int> renameLibrary(int id, String newName) async {
    final db = await database;
    return db.update(
      'user_libraries',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteLibrary(int id) async {
    final db = await database;
    return db.delete('user_libraries', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addVocabToLibrary(int libraryId, int vocabId) async {
    final db = await database;
    return db.insert('library_vocab_items', {
      'library_id': libraryId,
      'vocab_id': vocabId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Adds the words in one transaction and returns how many were actually
  /// new (ids already in the library are ignored).
  Future<int> addVocabsToLibrary(int libraryId, List<int> vocabIds) async {
    if (vocabIds.isEmpty) return 0;
    final db = await database;
    return db.transaction((txn) async {
      Future<int> count() async =>
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM library_vocab_items WHERE library_id = ?',
              [libraryId],
            ),
          ) ??
          0;
      final before = await count();
      final batch = txn.batch();
      for (final vocabId in vocabIds) {
        batch.insert('library_vocab_items', {
          'library_id': libraryId,
          'vocab_id': vocabId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
      return await count() - before;
    });
  }

  Future<int> removeVocabFromLibrary(int libraryId, int vocabId) async {
    final db = await database;
    return db.delete(
      'library_vocab_items',
      where: 'library_id = ? AND vocab_id = ?',
      whereArgs: [libraryId, vocabId],
    );
  }

  Future<int> removeVocabsFromLibrary(int libraryId, List<int> vocabIds) async {
    if (vocabIds.isEmpty) return 0;
    final db = await database;
    final batch = db.batch();
    for (final vocabId in vocabIds) {
      batch.delete(
        'library_vocab_items',
        where: 'library_id = ? AND vocab_id = ?',
        whereArgs: [libraryId, vocabId],
      );
    }
    await batch.commit(noResult: true);
    return vocabIds.length;
  }

  Future<List<Vocabulary>> getLibraryVocabularies(
    int libraryId, {
    int limit = 10000,
  }) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT v.* FROM vocabularies v
      JOIN library_vocab_items lvi ON v.id = lvi.vocab_id
      WHERE lvi.library_id = ?
      ORDER BY v.category, v.hanzi
      LIMIT ?
    ''',
      [libraryId, limit],
    );
    return maps.map(Vocabulary.fromMap).toList();
  }

  Future<int> getLibraryVocabulariesCount(int libraryId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM library_vocab_items WHERE library_id = ?
    ''',
      [libraryId],
    );
    return result.first['count'] as int;
  }

  Future<bool> isVocabInLibrary(int libraryId, int vocabId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT 1 FROM library_vocab_items WHERE library_id = ? AND vocab_id = ?
    ''',
      [libraryId, vocabId],
    );
    return result.isNotEmpty;
  }

  Future<List<Vocabulary>> getQuizVocabularyFromLibrary({
    required int libraryId,
    required int limit,
  }) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT v.* FROM vocabularies v
      JOIN library_vocab_items lvi ON v.id = lvi.vocab_id
      WHERE lvi.library_id = ?
      ORDER BY RANDOM()
      LIMIT ?
    ''',
      [libraryId, limit],
    );
    return maps.map(Vocabulary.fromMap).toList();
  }

  LibraryList _libraryListFromMap(Map<String, dynamic> map) => LibraryList(
    id: map['id'] as int,
    name: map['name'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    itemCount: map['item_count'] as int,
  );
}
