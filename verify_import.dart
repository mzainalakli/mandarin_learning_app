import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dbPath = p.join(await databaseFactory.getDatabasesPath(), 'mandarin.db');
  final db = await databaseFactory.openDatabase(dbPath);
  final count = await db.rawQuery('SELECT COUNT(*) as c FROM vocabularies');
  print('Total vocabularies: ${count.first['c']}');
  final samples = await db.rawQuery('SELECT hanzi, traditionalHanzi, pinyin, meaning, category FROM vocabularies LIMIT 10');
  for (final row in samples) {
    print(row);
  }
  await db.close();
}