import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mandarin_app/models/deck_filter.dart';
import 'package:mandarin_app/services/database_helper.dart';
import 'package:mandarin_app/services/deck_builder.dart';

void main() {
  sqfliteFfiInit();
  final db = DatabaseHelper.instance;
  final now = DateTime(2026, 3, 10, 12);
  final nowMs = now.toUtc().millisecondsSinceEpoch;
  const day = 86400000;
  late Database raw;

  Future<void> addWords(int count, {String Function(int)? category}) async {
    final batch = raw.batch();
    for (var i = 1; i <= count; i++) {
      batch.insert('vocabularies', {
        'hanzi': 'h$i',
        'pinyin': 'p$i',
        'meaning': 'm$i',
        'category': category?.call(i) ?? 'TOCFL A1',
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> progress(
    Iterable<int> ids, {
    int box = 0,
    int wrongStreak = 0,
    int due = 0, // ms relative to now
    int attempts = 1,
    int correct = 0,
  }) async {
    final batch = raw.batch();
    for (final id in ids) {
      batch.insert('vocab_progress', {
        'vocab_id': id,
        'box': box,
        'next_due': nowMs + due,
        'first_attempts': attempts,
        'first_correct': correct,
        'wrong_streak': wrongStreak,
      });
    }
    await batch.commit(noResult: true);
  }

  DeckBuilder builder([int seed = 1]) =>
      DeckBuilder(db: db, random: Random(seed), now: () => now);

  Future<List<int>> ids(
    DeckBuilder b, {
    DeckFilter? filter,
    int size = 20,
  }) async => (await b.build(
    filter: filter ?? const DeckFilter.all(),
    size: size,
  )).map((v) => v.id!).toList();

  setUp(() async {
    raw = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.useDatabaseForTest(raw);
  });

  test('new user: full random deck without duplicates', () async {
    await addWords(100);
    final deck = await ids(builder());
    expect(deck, hasLength(20));
    expect(deck.toSet(), hasLength(20));
  });

  test('weak words fill their quota and beat merely-due words', () async {
    await addWords(100);
    await progress(List.generate(10, (i) => i + 1), wrongStreak: 2); // weak
    await progress(
      List.generate(10, (i) => i + 11),
      box: 3,
      attempts: 4,
      correct: 4,
      due: -day,
    ); // due, not weak
    for (var seed = 0; seed < 20; seed++) {
      final deck = await ids(builder(seed));
      expect(deck, hasLength(20));
      expect(deck.toSet(), hasLength(20));
      final weak = deck.where((id) => id <= 10).length;
      expect(weak, 10, reason: 'quota = 50% of 20, all weak, seed $seed');
      expect(deck.where((id) => id > 10 && id <= 20), isEmpty);
    }
  });

  test(
    'quota larger than the weak pool is topped up with other words',
    () async {
      await addWords(100);
      await progress([1, 2, 3], wrongStreak: 1);
      await progress([4, 5], box: 3, attempts: 3, correct: 3, due: -day);
      final deck = await ids(builder());
      expect(deck, hasLength(20));
      expect(deck.toSet(), hasLength(20));
      expect(deck, containsAll([1, 2, 3, 4, 5]));
      expect(deck.where((id) => id > 5), hasLength(15));
    },
  );

  test('words not yet due are not chosen while unseen words remain', () async {
    await addWords(100);
    await progress(
      List.generate(30, (i) => i + 1),
      box: 4,
      attempts: 5,
      correct: 5,
      due: 10 * day,
    );
    for (var seed = 0; seed < 10; seed++) {
      expect((await ids(builder(seed))).where((id) => id <= 30), isEmpty);
    }
  });

  test('deck smaller than requested size when words are scarce', () async {
    await addWords(6);
    await progress([1], wrongStreak: 1);
    final deck = await ids(builder());
    expect(deck.toSet(), {1, 2, 3, 4, 5, 6});
  });

  test('respects category and library filters', () async {
    await addWords(60, category: (i) => i <= 30 ? 'TOCFL A1' : 'TOCFL B1');
    await progress([40, 41], wrongStreak: 3); // weak but outside A1
    await progress([1], wrongStreak: 3);
    final a1 = DeckBuilder.categoryFilter('TOCFL A1');
    final deck = await ids(builder(), filter: a1);
    expect(deck.every((id) => id <= 30), isTrue);
    expect(deck, contains(1));

    final lib = await db.createLibrary('l');
    await db.addVocabsToLibrary(lib, [40, 41, 42, 43, 44, 45]);
    final fromLib = await ids(builder(), filter: DeckFilter(libraryId: lib));
    expect(fromLib.toSet(), {40, 41, 42, 43, 44, 45});
    expect(fromLib.take(2).toSet(), {40, 41}, reason: 'weak ones included');
  });

  test('a filter with fewer than 4 words falls back to all words', () async {
    await addWords(40, category: (i) => i <= 2 ? 'TOCFL A1' : 'TOCFL C2');
    final deck = await ids(
      builder(),
      filter: DeckBuilder.categoryFilter('TOCFL A1'),
    );
    expect(deck.length, greaterThanOrEqualTo(4));
  });

  test('weak definition', () async {
    await addWords(10);
    await progress([1], box: 1, attempts: 1, correct: 1); // new, right once
    await progress([2], wrongStreak: 1); // missed once
    await progress([3], box: 1, attempts: 2, correct: 1); // 50% of 2
    await progress([4], box: 3, attempts: 5, correct: 4); // 80%
    await progress([5], box: 2, attempts: 3, correct: 2); // 67%
    await progress([6], attempts: 0, correct: 0); // no real attempt
    await progress([7], box: 1, attempts: 10, correct: 5, wrongStreak: 0);
    expect(await db.getWeakWordCount(), 3);
    final weak = await db.getWeakestIds(limit: 10);
    expect(weak.toSet(), {2, 3, 7});
  });

  test('new or just-upgraded user has no weak words', () async {
    await addWords(20);
    expect(await db.getWeakWordCount(), 0);
    expect(await db.getWeakestIds(limit: 10), isEmpty);
  });

  test('same seed and clock give the same deck', () async {
    await addWords(100);
    await progress(List.generate(40, (i) => i + 1), wrongStreak: 1);
    expect(await ids(builder(7)), await ids(builder(7)));
    expect(await ids(builder(7)), isNot(await ids(builder(8))));
  });

  test('weak words deck: worst first, padded when too few', () async {
    await addWords(50);
    await progress([5], wrongStreak: 4);
    await progress([6], wrongStreak: 1);
    await progress([7], box: 4, attempts: 9, correct: 9, due: day);
    final weak = await builder().buildWeak(size: 20);
    expect(weak.length, DeckBuilder.weakWordsMinDeck, reason: 'padded');
    expect(weak.take(2).map((v) => v.id), [5, 6]);
    expect(await db.getWeakWordCount(), 2);
  });

  test('15k words: endless pool builds quickly with unique words', () async {
    await addWords(15000, category: (i) => i <= 9000 ? 'TOCFL B2' : 'TOCFL C2');
    await progress(List.generate(2000, (i) => i + 1), wrongStreak: 1);
    await progress(
      List.generate(3000, (i) => i + 2001),
      box: 2,
      attempts: 3,
      correct: 3,
      due: -day,
    );
    final watch = Stopwatch()..start();
    final deck = await ids(builder(), size: 1000);
    watch.stop();
    expect(deck, hasLength(1000));
    expect(deck.toSet(), hasLength(1000));
    expect(deck.where((id) => id <= 2000).length, 500);
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
  });
}
