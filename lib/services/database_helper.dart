import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/vocabulary.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

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
        version: 3,
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
          final batch = db.batch()
            ..insert('vocabularies', {
              'hanzi': '你好',
              'traditionalHanzi': '你好',
              'pinyin': 'nǐ hǎo',
              'zhuyin': 'ㄋㄧˇ ㄏㄠˇ',
              'meaning': 'hello',
              'category': 'HSK 1',
            })
            ..insert('vocabularies', {
              'hanzi': '谢谢',
              'traditionalHanzi': '謝謝',
              'pinyin': 'xiè xie',
              'zhuyin': 'ㄒㄧㄝˋ ˙ㄒㄧㄝ',
              'meaning': 'thank you',
              'category': 'HSK 1',
            })
            ..insert('vocabularies', {
              'hanzi': '再见',
              'traditionalHanzi': '再見',
              'pinyin': 'zài jiàn',
              'zhuyin': 'ㄗㄞˋ ㄐㄧㄢˋ',
              'meaning': 'goodbye',
              'category': 'HSK 1',
            })
            ..insert('vocabularies', {
              'hanzi': '不',
              'traditionalHanzi': '不',
              'pinyin': 'bù',
              'zhuyin': 'ㄅㄨˋ',
              'meaning': 'no; not',
              'category': 'HSK 1',
            })
            ..insert('vocabularies', {
              'hanzi': '人',
              'traditionalHanzi': '人',
              'pinyin': 'rén',
              'zhuyin': 'ㄖㄣˊ',
              'meaning': 'person',
              'category': 'HSK 1',
            });
          await batch.commit(noResult: true);
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
        },
      ),
    );
  }

  Future<int> insertVocab(Vocabulary vocab) async {
    final db = await database;
    final map = vocab.toMap()..remove('id');
    return db.insert('vocabularies', map);
  }

  Future<List<Vocabulary>> getAllVocabularies() async {
    final db = await database;
    final maps = await db.query('vocabularies');
    return maps.map(Vocabulary.fromMap).toList();
  }

  Future<int> deleteVocab(int id) async {
    final db = await database;
    return db.delete('vocabularies', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertBatch(List<Vocabulary> vocabs) async {
    if (vocabs.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final v in vocabs) {
      batch.insert('vocabularies', v.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateReviewStats(int id, bool correct) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE vocabularies
      SET reviewCount = reviewCount + 1,
          correctCount = correctCount + ${correct ? 1 : 0},
          lastReviewed = ?
      WHERE id = ?
    ''',
      [now, id],
    );
  }
}
