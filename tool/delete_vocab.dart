import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = await databaseFactory.getDatabasesPath();
  final path = p.join(dbPath, 'mandarin.db');
  final db = await databaseFactory.openDatabase(path);

  await db.execute('DELETE FROM vocabularies');
  print('All vocabulary data deleted.');

  await db.close();
}