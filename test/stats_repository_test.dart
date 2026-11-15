import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mandarin_app/models/review_event.dart';
import 'package:mandarin_app/models/stats_snapshot.dart';
import 'package:mandarin_app/services/database_helper.dart';
import 'package:mandarin_app/services/stats_repository.dart';

void main() {
  sqfliteFfiInit();
  final db = DatabaseHelper.instance;
  late Database raw;
  late DateTime now;

  StatsRepository repo() => StatsRepository(db: db, now: () => now);

  Future<void> answer(
    DateTime at, {
    int vocab = 1,
    bool correct = true,
    bool first = true,
    String module = 'hanziToMeaning',
  }) => db.recordReview(
    ReviewEvent(
      vocabId: vocab,
      timestamp: at,
      module: module,
      mode: 'choice',
      correct: correct,
      isFirstAttempt: first,
      sessionId: 1,
    ),
  );

  setUp(() async {
    now = DateTime(2026, 3, 10, 12);
    raw = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.useDatabaseForTest(raw);
    for (var i = 1; i <= 5; i++) {
      await raw.insert('vocabularies', {
        'hanzi': 'h$i',
        'pinyin': 'p$i',
        'meaning': 'm$i',
        'category': i <= 3 ? 'TOCFL A1' : 'TOCFL A2',
      });
    }
  });

  test('no events: empty snapshot, no crash', () async {
    final snap = await repo().load(StatsRange.week);
    expect(snap.hasData, isFalse);
    expect(snap.trend, isEmpty);
    expect((await repo().loadSummary()).streakDays, 0);
  });

  test(
    'daily accuracy uses first attempts; repeats only add to answers',
    () async {
      final day = DateTime(2026, 3, 10, 9);
      await answer(day, vocab: 1, correct: true);
      await answer(day, vocab: 2, correct: false);
      await answer(day, vocab: 2, correct: true, first: false);
      final snap = await repo().load(StatsRange.week);
      final today = snap.trend.last;
      expect(snap.trend, hasLength(7));
      expect(today.answers, 3);
      expect(today.firstAttempts, 2);
      expect(today.accuracy, 0.5);
      expect(snap.trend.first.accuracy, isNull, reason: 'gap, not zero');
      expect(snap.answersToday, 3);
    },
  );

  test('local day boundary: 23:59 and 00:01 land on different days', () async {
    await answer(DateTime(2026, 3, 9, 23, 59), vocab: 1);
    await answer(DateTime(2026, 3, 10, 0, 1), vocab: 2);
    final snap = await repo().load(StatsRange.week);
    expect(snap.trend[5].answers, 1); // 9 March
    expect(snap.trend[6].answers, 1); // 10 March
    expect(snap.answersToday, 1);
    expect(snap.streakDays, 2);
  });

  test('streak: survives a day without answers yet, breaks on a gap', () async {
    await answer(DateTime(2026, 3, 9, 10));
    await answer(DateTime(2026, 3, 8, 10));
    await answer(DateTime(2026, 3, 6, 10)); // gap on the 7th
    expect(
      (await repo().loadSummary()).streakDays,
      2,
      reason: 'none today yet',
    );
    await answer(DateTime(2026, 3, 10, 8));
    expect((await repo().loadSummary()).streakDays, 3);
    now = DateTime(2026, 3, 12, 8); // two empty days: broken
    expect((await repo().loadSummary()).streakDays, 0);
  });

  test('7 days vs previous 7 days', () async {
    // previous window: 3 Mar..9 Mar -> 1 of 2 correct
    await answer(DateTime(2026, 3, 1, 10), vocab: 1, correct: true);
    await answer(DateTime(2026, 3, 2, 10), vocab: 2, correct: false);
    // last 7 days (4 Mar..10 Mar): 3 of 4 correct
    for (var i = 0; i < 3; i++) {
      await answer(
        DateTime(2026, 3, 5 + i, 10),
        vocab: 3 + i % 2,
        correct: true,
      );
    }
    await answer(DateTime(2026, 3, 9, 10), vocab: 5, correct: false);
    final snap = await repo().load(StatsRange.week);
    expect(snap.accuracyLast7, 0.75);
    expect(snap.accuracyPrevious7, 0.5);
    expect(snap.accuracyDelta, closeTo(0.25, 1e-9));
  });

  test('learned, mastered, levels, modules and most missed', () async {
    // word 1 climbs to box 4 over due dates; word 2 is missed twice.
    var t = DateTime(2026, 1, 1, 9);
    for (var i = 0; i < 4; i++) {
      await answer(t, vocab: 1, correct: true);
      t = t.add(Duration(days: 40));
    }
    await answer(DateTime(2026, 3, 10, 9), vocab: 2, correct: false);
    await answer(
      DateTime(2026, 3, 10, 10),
      vocab: 2,
      correct: false,
      module: 'pinyinToHanziAndMeaning',
    );
    await answer(DateTime(2026, 3, 10, 11), vocab: 4, correct: true);
    final snap = await repo().load(StatsRange.month);
    expect(snap.learnedWords, 3);
    expect(snap.masteredWords, 1);
    final a1 = snap.levels.firstWhere((l) => l.category == 'TOCFL A1');
    expect((a1.totalWords, a1.masteredWords), (3, 1));
    expect(snap.levels.map((l) => l.category).toList().first, 'TOCFL A1');
    expect(snap.modules.map((m) => m.module).toSet(), {
      'hanziToMeaning',
      'pinyinToHanziAndMeaning',
    });
    expect(snap.mostMissed.single.vocab.id, 2);
    expect(snap.mostMissed.single.misses, 2);
  });

  test('90 days are grouped by week starting Monday', () async {
    await answer(DateTime(2026, 3, 10, 9)); // Tuesday
    await answer(DateTime(2026, 3, 9, 9), vocab: 2); // Monday, same week
    await answer(DateTime(2026, 3, 8, 9), vocab: 3); // Sunday, week before
    final snap = await repo().load(StatsRange.quarter);
    expect(snap.trend.last.start, DateTime(2026, 3, 9));
    expect(snap.trend.last.answers, 2);
    expect(snap.trend[snap.trend.length - 2].answers, 1);
    expect(snap.trend.every((b) => b.start.weekday == DateTime.monday), isTrue);
  });
}
