import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mandarin_app/models/review_event.dart';
import 'package:mandarin_app/models/vocabulary.dart';
import 'package:mandarin_app/providers/quiz_provider.dart';
import 'package:mandarin_app/services/database_helper.dart';
import 'package:mandarin_app/services/leitner.dart';

ReviewEvent _event(
  int id,
  DateTime at, {
  bool correct = true,
  bool first = true,
  ReviewOutcome outcome = ReviewOutcome.answer,
}) => ReviewEvent(
  vocabId: id,
  timestamp: at,
  module: 'hanziToMeaning',
  mode: 'choice',
  correct: correct,
  isFirstAttempt: first,
  sessionId: 1,
  outcome: outcome,
);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = DatabaseHelper.instance;

  group('Leitner', () {
    const now = 1000000;
    test('new word answered correctly goes to box 1, due in 1 day', () {
      final s = Leitner.next(
        box: null,
        nextDue: null,
        wrongStreak: 0,
        correct: true,
        nowMs: now,
      );
      expect(s.box, 1);
      expect(s.nextDue, now + const Duration(days: 1).inMilliseconds);
    });

    test('a miss resets to box 0, due now, and counts the streak', () {
      final s = Leitner.next(
        box: 4,
        nextDue: now + 99,
        wrongStreak: 1,
        correct: false,
        nowMs: now,
      );
      expect((s.box, s.nextDue, s.wrongStreak), (0, now, 2));
    });

    test('a correct answer before the due date does not promote', () {
      final s = Leitner.next(
        box: 2,
        nextDue: now + 500,
        wrongStreak: 3,
        correct: true,
        nowMs: now,
      );
      expect((s.box, s.nextDue, s.wrongStreak), (2, now + 500, 0));
    });

    test('box never exceeds the maximum', () {
      final s = Leitner.next(
        box: Leitner.maxBox,
        nextDue: now,
        wrongStreak: 0,
        correct: true,
        nowMs: now,
      );
      expect(s.box, Leitner.maxBox);
    });
  });

  group('recordReview', () {
    late Database raw;
    final t0 = DateTime(2026, 3, 10, 12);

    setUp(() async {
      raw = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db.useDatabaseForTest(raw);
      for (var i = 1; i <= 3; i++) {
        await raw.insert('vocabularies', {
          'hanzi': 'h$i',
          'pinyin': 'p$i',
          'meaning': 'm$i',
          'category': 'TOCFL A1',
        });
      }
    });

    Future<Map<String, Object?>> progress(int id) async => (await raw.query(
      'vocab_progress',
      where: 'vocab_id = ?',
      whereArgs: [id],
    )).first;

    test('first correct answer writes event, totals and progress', () async {
      await db.recordReview(_event(1, t0));
      final vocab = (await raw.query('vocabularies', where: 'id = 1')).first;
      expect(vocab['reviewCount'], 1);
      expect(vocab['correctCount'], 1);
      expect(vocab['lastReviewed'], t0.toIso8601String());
      final ev = (await raw.query('review_events')).single;
      expect(ev['ts'], t0.toUtc().millisecondsSinceEpoch);
      expect(ev['day'], 20260310);
      expect(ev['is_first_attempt'], 1);
      expect(ev['outcome'], 'answer');
      final pr = await progress(1);
      expect(pr['box'], 1);
      expect(pr['first_attempts'], 1);
      expect(pr['first_correct'], 1);
    });

    test('repeat answers are stored but leave progress untouched', () async {
      await db.recordReview(_event(1, t0, correct: false));
      final before = await progress(1);
      await db.recordReview(
        _event(
          1,
          t0.add(const Duration(minutes: 1)),
          correct: true,
          first: false,
        ),
      );
      expect(await progress(1), before);
      final vocab = (await raw.query('vocabularies', where: 'id = 1')).first;
      expect(
        vocab['reviewCount'],
        2,
        reason: 'legacy totals count every answer',
      );
      expect(vocab['correctCount'], 1);
      final events = await raw.query('review_events', orderBy: 'id');
      expect(events.map((e) => e['is_first_attempt']), [1, 0]);
    });

    test('a miss lowers the box and early review does not promote', () async {
      await db.recordReview(_event(1, t0));
      await db.recordReview(_event(1, t0.add(const Duration(days: 2))));
      expect((await progress(1))['box'], 2);
      await db.recordReview(
        _event(1, t0.add(const Duration(days: 2, hours: 1))),
      );
      expect((await progress(1))['box'], 2, reason: 'not due yet');
      await db.recordReview(
        _event(
          1,
          t0.add(const Duration(days: 3)),
          correct: false,
          outcome: ReviewOutcome.timeout,
        ),
      );
      final pr = await progress(1);
      expect(pr['box'], 0);
      expect(pr['wrong_streak'], 1);
    });

    test('deleteVocab removes its stats and library rows only', () async {
      final lib = await db.createLibrary('l');
      await db.addVocabsToLibrary(lib, [1, 2]);
      await db.recordReview(_event(1, t0));
      await db.recordReview(_event(2, t0));
      expect(await db.deleteVocab(1), 1);
      expect(await raw.query('review_events'), hasLength(1));
      expect(await raw.query('vocab_progress'), hasLength(1));
      expect(await db.getLibraryVocabIds(lib), {2});
    });
  });

  group('QuizProvider events', () {
    List<Vocabulary> vocabs(int n) => List.generate(
      n,
      (i) => Vocabulary(
        id: i + 1,
        hanzi: 'h$i',
        pinyin: 'p$i',
        meaning: 'm$i',
        category: 'test',
      ),
    );

    test('first vs repeat answers, and pass is not recorded', () async {
      final events = <ReviewEvent>[];
      var clock = DateTime(2026, 3, 10, 9);
      final quiz = QuizProvider(
        recordReview: (e) async => events.add(e),
        random: Random(1),
        now: () => clock = clock.add(const Duration(seconds: 2)),
      );
      quiz.startNewQuiz(
        vocabs(4),
        module: QuizModule.hanziToMeaning,
        answerMode: QuizAnswerMode.essay,
      );
      final passed = quiz.current!;
      quiz.passQuestion();
      expect(events, isEmpty);
      expect(quiz.current, isNot(same(passed)));

      final word = quiz.current!;
      quiz.revealAnswer();
      await quiz.reviewLater();
      quiz.nextQuestion();
      // Serve words until `word` returns, then answer it correctly.
      while (quiz.current != null && !identical(quiz.current, word)) {
        quiz.revealAnswer();
        await quiz.selfEvaluate(true);
        quiz.nextQuestion();
      }
      quiz.revealAnswer();
      await quiz.selfEvaluate(true);

      final mine = events.where((e) => e.vocabId == word.id).toList();
      expect(mine.map((e) => e.isFirstAttempt), [true, false]);
      expect(mine.map((e) => e.correct), [false, true]);
      expect(mine.first.outcome, ReviewOutcome.reviewLater);
      expect(mine.first.mode, 'essay');
      expect(mine.first.module, 'hanziToMeaning');
      expect(mine.first.responseMs, isNotNull);
      expect(events.map((e) => e.sessionId).toSet(), hasLength(1));
      expect(quiz.score, 2, reason: 'score logic is unchanged');
    });
  });

  group('migration 8 -> 9', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('mandarin_mig9'));
    tearDown(() {
      db.resetForTest();
      dir.deleteSync(recursive: true);
    });

    test('removes only backfilled rows (first_attempts = 0)', () async {
      final path = p.join(dir.path, 'v8.db');
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 8,
          onCreate: (d, _) async {
            await d.execute('''
              CREATE TABLE vocabularies (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                hanzi TEXT NOT NULL, pinyin TEXT NOT NULL, zhuyin TEXT,
                traditionalHanzi TEXT, meaning TEXT NOT NULL,
                category TEXT NOT NULL,
                reviewCount INTEGER NOT NULL DEFAULT 0,
                correctCount INTEGER NOT NULL DEFAULT 0,
                lastReviewed TEXT NOT NULL DEFAULT '')''');
            await d.execute('''
              CREATE TABLE review_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT, vocab_id INTEGER NOT NULL,
                ts INTEGER NOT NULL, day INTEGER NOT NULL, module TEXT NOT NULL,
                mode TEXT NOT NULL, correct INTEGER NOT NULL,
                is_first_attempt INTEGER NOT NULL, session_id INTEGER NOT NULL,
                response_ms INTEGER, outcome TEXT NOT NULL)''');
            await d.execute(
              '''
              CREATE TABLE vocab_progress (
                vocab_id INTEGER PRIMARY KEY, box INTEGER NOT NULL DEFAULT 0,
                next_due INTEGER NOT NULL,
                first_attempts INTEGER NOT NULL DEFAULT 0,
                first_correct INTEGER NOT NULL DEFAULT 0,
                wrong_streak INTEGER NOT NULL DEFAULT 0, last_first_ts INTEGER)''',
            );
          },
        ),
      );
      for (var i = 1; i <= 3; i++) {
        await old.insert('vocabularies', {
          'id': i,
          'hanzi': 'h$i',
          'pinyin': 'p$i',
          'meaning': 'm$i',
          'category': 'TOCFL A1',
          'reviewCount': 4,
          'correctCount': 2,
        });
      }
      Future<void> row(int id, int attempts, int correct, int streak) =>
          old.insert('vocab_progress', {
            'vocab_id': id,
            'box': id == 1 ? 2 : 0,
            'next_due': 1000,
            'first_attempts': attempts,
            'first_correct': correct,
            'wrong_streak': streak,
          });
      await row(1, 0, 0, 0); // backfill leftover
      await row(2, 1, 0, 1); // real, weak
      await row(3, 5, 5, 0); // real, strong
      await old.insert('review_events', {
        'vocab_id': 2,
        'ts': 1,
        'day': 20260101,
        'module': 'm',
        'mode': 'choice',
        'correct': 0,
        'is_first_attempt': 1,
        'session_id': 1,
        'outcome': 'answer',
      });
      await old.close();

      final upgraded = await db.openAtPathForTest(path);
      expect(await upgraded.getVersion(), 9);
      final rows = await upgraded.query('vocab_progress', orderBy: 'vocab_id');
      expect(rows.map((r) => r['vocab_id']), [2, 3]);
      expect(rows[0]['wrong_streak'], 1);
      expect(rows[1]['first_correct'], 5);
      expect(await upgraded.query('review_events'), hasLength(1));
      expect(await upgraded.query('vocabularies'), hasLength(3));
      expect(await db.getWeakWordCount(), 1);
    });
  });

  group('migration 7 -> 8', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('mandarin_mig');
    });
    tearDown(() async {
      db.resetForTest();
      dir.deleteSync(recursive: true);
    });

    test(
      '7 -> 9 keeps words, libraries and old stats; no progress rows',
      () async {
        final path = p.join(dir.path, 'v7.db');
        final old = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 7,
            onCreate: (d, _) async {
              await d.execute('''
              CREATE TABLE vocabularies (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                hanzi TEXT NOT NULL, pinyin TEXT NOT NULL, zhuyin TEXT,
                traditionalHanzi TEXT, meaning TEXT NOT NULL,
                category TEXT NOT NULL,
                reviewCount INTEGER NOT NULL DEFAULT 0,
                correctCount INTEGER NOT NULL DEFAULT 0,
                lastReviewed TEXT NOT NULL DEFAULT '')''');
              await d.execute('''
              CREATE TABLE user_libraries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL, created_at TEXT NOT NULL)''');
              await d.execute('''
              CREATE TABLE library_vocab_items (
                library_id INTEGER NOT NULL, vocab_id INTEGER NOT NULL,
                PRIMARY KEY (library_id, vocab_id))''');
            },
          ),
        );
        Future<void> word(int id, int reviews, int correct) =>
            old.insert('vocabularies', {
              'id': id,
              'hanzi': 'h$id',
              'pinyin': 'p$id',
              'meaning': 'm$id',
              'category': 'TOCFL A1',
              'reviewCount': reviews,
              'correctCount': correct,
              'lastReviewed': reviews > 0 ? '2026-01-01T10:00:00.000' : '',
            });
        await word(1, 10, 9);
        await word(2, 10, 5);
        await word(3, 0, 0); // never reviewed -> no progress row
        await old.insert('user_libraries', {
          'id': 1,
          'name': 'mine',
          'created_at': '2026-01-01T00:00:00.000',
        });
        await old.insert('library_vocab_items', {
          'library_id': 1,
          'vocab_id': 2,
        });
        await old.close();

        final upgraded = await db.openAtPathForTest(path);
        expect(await upgraded.getVersion(), 9);

        final vocab = await upgraded.query('vocabularies', orderBy: 'id');
        expect(vocab, hasLength(3));
        expect(vocab[0]['reviewCount'], 10);
        expect(vocab[0]['correctCount'], 9);
        expect(vocab[0]['lastReviewed'], '2026-01-01T10:00:00.000');
        expect(vocab[1]['correctCount'], 5);
        expect(await db.getLibraryVocabIds(1), {2});
        expect((await db.getAllLibraries()).single.name, 'mine');

        expect(await upgraded.query('review_events'), isEmpty);
        expect(
          await upgraded.query('vocab_progress'),
          isEmpty,
          reason: 'old totals are not used for scheduling',
        );
        expect(await db.getWeakWordCount(), 0);

        final stats = await db.getVocabStats();
        expect(stats.totalReviews, 20);
        expect(stats.totalCorrect, 14);

        // New schema is usable straight after the upgrade.
        await db.recordReview(_event(1, DateTime(2026, 3, 10, 8)));
        expect(await upgraded.query('review_events'), hasLength(1));
      },
    );
  });
}
