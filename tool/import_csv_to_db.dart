import 'dart:io';

import 'package:mandarin_app/services/excel_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    exitCode = 64;
    return;
  }

  final csvArg = _readOption(args, '--csv') ?? args.firstWhere(
    (arg) => !arg.startsWith('--'),
    orElse: () => '',
  );
  if (csvArg.isEmpty) {
    stderr.writeln('CSV path is required.');
    _printUsage();
    exitCode = 64;
    return;
  }

  final csvFile = File(csvArg);
  if (!csvFile.existsSync()) {
    stderr.writeln('CSV file not found: $csvArg');
    exitCode = 66;
    return;
  }

  sqfliteFfiInit();
  final defaultDbDir = await databaseFactoryFfi.getDatabasesPath();
  final dbPath = _readOption(args, '--db') ?? p.join(defaultDbDir, 'mandarin.db');
  final dbFile = File(dbPath);
  dbFile.parent.createSync(recursive: true);

  final importData = ExcelService.importCsv(await csvFile.readAsBytes());
  if (importData.vocabs.isEmpty) {
    stdout.writeln('No valid rows to import. Skipped: ${importData.skippedCount}.');
    return;
  }

  final db = sqlite3.open(dbPath);
  try {
    db.execute('''
      CREATE TABLE IF NOT EXISTS vocabularies (
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

    db.execute('BEGIN TRANSACTION');
    final stmt = db.prepare('''
      INSERT INTO vocabularies (
        hanzi,
        pinyin,
        zhuyin,
        traditionalHanzi,
        meaning,
        category,
        reviewCount,
        correctCount,
        lastReviewed
      ) VALUES (?, ?, ?, ?, ?, ?, 0, 0, '')
    ''');

    for (final vocab in importData.vocabs) {
      stmt.execute([
        vocab.hanzi,
        vocab.pinyin,
        vocab.zhuyin,
        vocab.traditionalHanzi,
        vocab.meaning,
        vocab.category,
      ]);
    }

    stmt.dispose();
    db.execute('COMMIT');

    final count = db.select('SELECT COUNT(*) AS total FROM vocabularies').first['total'];
    stdout.writeln('Imported rows: ${importData.vocabs.length}');
    stdout.writeln('Skipped rows: ${importData.skippedCount}');
    stdout.writeln('Database path: $dbPath');
    stdout.writeln('Total rows in vocabularies: $count');
  } catch (error) {
    try {
      db.execute('ROLLBACK');
    } catch (_) {}
    stderr.writeln('Import failed: $error');
    exitCode = 1;
  } finally {
    db.dispose();
  }
}

String? _readOption(List<String> args, String option) {
  final index = args.indexOf(option);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

void _printUsage() {
  stdout.writeln('Usage:');
  stdout.writeln('  dart run tool/import_csv_to_db.dart --csv /path/to/cccc.csv [--db /path/to/mandarin.db]');
}
