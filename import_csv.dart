import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final csvPath = '/media/emza/01DCB9AB54DCB9902/project/mandarin_app/cccc.csv';
  final dbPath = p.join(await databaseFactory.getDatabasesPath(), 'mandarin.db');

  final db = await databaseFactory.openDatabase(dbPath);

  final csvContent = await File(csvPath).readAsString();
  final lines = csvContent.split('\n');
  if (lines.isEmpty) return;

  final dataLines = lines.skip(1).where((l) => l.trim().isNotEmpty).toList();

  final batch = db.batch();
  int count = 0;

  for (final line in dataLines) {
    final fields = _parseCsvLine(line);
    if (fields.length < 8) continue;

    final traditional = fields[1];
    final simplified = fields[2];
    final pinyin = fields[3];
    final meaning = fields[5];
    final category = fields[6];
    final subcategory = fields[7];

    final displayCategory = '$category / $subcategory'.trim();

    batch.insert('vocabularies', {
      'hanzi': simplified,
      'traditionalHanzi': traditional,
      'pinyin': pinyin,
      'zhuyin': null,
      'meaning': meaning,
      'category': displayCategory,
      'reviewCount': 0,
      'correctCount': 0,
      'lastReviewed': '',
    });

    count++;
    if (count % 100 == 0) {
      await batch.commit(noResult: true);
      stdout.writeln('Inserted $count rows...');
    }
  }

  await batch.commit(noResult: true);
  stdout.writeln('Import complete. Total rows: $count');
  await db.close();
}

List<String> _parseCsvLine(String line) {
  final result = <String>[];
  final buffer = StringBuffer();
  bool inQuotes = false;

  for (int i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      result.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  result.add(buffer.toString());
  return result;
}