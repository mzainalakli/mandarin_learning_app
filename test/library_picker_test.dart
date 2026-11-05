import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mandarin_app/services/database_helper.dart';

void main() {
  sqfliteFfiInit();
  final db = DatabaseHelper.instance;
  late int libraryId;

  setUp(() async {
    final raw = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.useDatabaseForTest(raw);
    for (var i = 1; i <= 10; i++) {
      await raw.insert('vocabularies', {
        'hanzi': 'h$i',
        'pinyin': i.isEven ? 'even' : 'odd',
        'meaning': 'm$i',
        'category': 'TOCFL A1',
      });
    }
    libraryId = await db.createLibrary('mine');
    await db.addVocabsToLibrary(libraryId, [1, 2, 3]);
  });

  test('excludeLibraryId hides words already in the library', () async {
    final all = await db.getVocabulariesCount();
    final free = await db.getVocabulariesCount(excludeLibraryId: libraryId);
    expect(all, 10);
    expect(free, 7);
    final page = await db.getVocabulariesPaged(
      limit: 50,
      excludeLibraryId: libraryId,
    );
    expect(page.map((v) => v.id), isNot(containsAll([1, 2, 3])));
  });

  test('filter combines with search and paging', () async {
    final ids = await db.getVocabularyIds(
      searchQuery: 'even',
      excludeLibraryId: libraryId,
    );
    expect(ids.toSet(), {4, 6, 8, 10}); // 2 is already added
    final page2 = await db.getVocabulariesPaged(
      limit: 3,
      offset: 3,
      excludeLibraryId: libraryId,
    );
    expect(page2.length, 3);
  });

  test('getVocabularyIds returns every match without a limit', () async {
    expect((await db.getVocabularyIds()).length, 10);
    expect((await db.getLibraryVocabIds(libraryId)), {1, 2, 3});
  });

  test('addVocabsToLibrary returns only newly inserted rows', () async {
    expect(await db.addVocabsToLibrary(libraryId, [2, 3, 4, 5, 5]), 2);
    expect(await db.addVocabsToLibrary(libraryId, [4, 5]), 0);
    expect(await db.addVocabsToLibrary(libraryId, []), 0);
    expect(await db.getLibraryVocabulariesCount(libraryId), 5);
  });
}
