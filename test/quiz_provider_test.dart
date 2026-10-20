import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mandarin_app/models/vocabulary.dart';
import 'package:mandarin_app/providers/quiz_provider.dart';
import 'package:mandarin_app/providers/settings_provider.dart';

List<Vocabulary> _vocabs(int count) => List.generate(
  count,
  (index) => Vocabulary(
    id: index + 1,
    hanzi: 'h$index',
    pinyin: 'p$index',
    zhuyin: 'z$index',
    meaning: 'm$index',
    category: 'test',
  ),
);

class _Recorder {
  final calls = <(int, bool)>[];
  Future<void> call(int id, bool correct) async => calls.add((id, correct));
}

QuizProvider _quiz(_Recorder recorder, {int seed = 1}) =>
    QuizProvider(recordReview: recorder.call, random: Random(seed));

Future<void> _gotIt(QuizProvider quiz) async {
  quiz.revealAnswer();
  await quiz.selfEvaluate(true);
  quiz.nextQuestion();
}

Future<void> _reviewLater(QuizProvider quiz) async {
  quiz.revealAnswer();
  await quiz.reviewLater();
  quiz.nextQuestion();
}

void main() {
  group('Review Later (flashcards)', () {
    test('keeps the word in the session instead of completing it', () async {
      final recorder = _Recorder();
      final quiz = _quiz(recorder);
      quiz.startNewQuiz(
        _vocabs(5),
        module: QuizModule.hanziToMeaning,
        answerMode: QuizAnswerMode.essay,
      );
      final first = quiz.current!;

      await _reviewLater(quiz);

      expect(quiz.completedCount, 0);
      expect(quiz.current, isNot(same(first)));
      expect(quiz.remainingCount, 4, reason: 'deck size is unchanged');
      expect(recorder.calls, [(first.id!, false)]);
    });

    test('word is asked again, then the session ends only after it is passed', () async {
      final recorder = _Recorder();
      final quiz = _quiz(recorder);
      quiz.startNewQuiz(
        _vocabs(5),
        module: QuizModule.hanziToMeaning,
        answerMode: QuizAnswerMode.essay,
      );
      final first = quiz.current!;
      var timesFirstAsked = 1;

      await _reviewLater(quiz);
      while (!quiz.quizFinished) {
        if (identical(quiz.current, first)) timesFirstAsked++;
        await _gotIt(quiz);
      }

      expect(timesFirstAsked, 2);
      expect(quiz.completedCount, 5);
      expect(quiz.score, 4, reason: 'first-try score excludes the missed word');
      expect(
        recorder.calls.where((c) => c.$1 == first.id).map((c) => c.$2),
        [false, true],
      );
    });

    test('is reinserted at varying positions among unasked words, never next', () async {
      final positions = <int>{};
      for (var seed = 0; seed < 120; seed++) {
        final quiz = _quiz(_Recorder(), seed: seed);
        quiz.startNewQuiz(
          _vocabs(8),
          module: QuizModule.hanziToMeaning,
          answerMode: QuizAnswerMode.essay,
        );
        final first = quiz.current!;
        await _reviewLater(quiz);

        var asked = 0;
        while (!identical(quiz.current, first)) {
          asked++;
          await _gotIt(quiz);
        }
        expect(asked, greaterThanOrEqualTo(1), reason: 'seed $seed');
        positions.add(asked);
      }
      expect(positions.length, greaterThan(3), reason: 'position is random');
      expect(positions.reduce(max), lessThanOrEqualTo(7));
    });

    test('a single remaining word simply comes back', () async {
      final quiz = _quiz(_Recorder());
      quiz.startNewQuiz(
        _vocabs(1),
        module: QuizModule.hanziToMeaning,
        answerMode: QuizAnswerMode.essay,
      );
      final only = quiz.current!;

      await _reviewLater(quiz);

      expect(quiz.quizFinished, isFalse);
      expect(quiz.current, same(only));
    });

    test('only works after the answer is revealed', () async {
      final recorder = _Recorder();
      final quiz = _quiz(recorder);
      quiz.startNewQuiz(
        _vocabs(3),
        module: QuizModule.hanziToMeaning,
        answerMode: QuizAnswerMode.essay,
      );

      await quiz.reviewLater();

      expect(quiz.answered, isFalse);
      expect(recorder.calls, isEmpty);
    });
  });

  group('no-limit sessions', () {
    test('never finish on their own and replay the pool in rounds', () async {
      final quiz = _quiz(_Recorder());
      quiz.startNewQuiz(
        _vocabs(3),
        module: QuizModule.hanziToMeaning,
        answerMode: QuizAnswerMode.essay,
        sessionSize: null,
      );
      expect(quiz.isEndless, isTrue);

      Vocabulary? previous;
      for (var i = 0; i < 20; i++) {
        expect(quiz.quizFinished, isFalse, reason: 'question $i');
        expect(quiz.hasCurrent, isTrue);
        if (previous != null) {
          expect(quiz.current, isNot(same(previous)), reason: 'no repeat at $i');
        }
        previous = quiz.current;
        await _gotIt(quiz);
      }

      expect(quiz.completedCount, 20);
      expect(quiz.round, greaterThan(5));
      expect(quiz.progressFraction, inInclusiveRange(0.0, 1.0));
    });

    test('work in multiple choice mode', () async {
      final quiz = _quiz(_Recorder());
      quiz.startNewQuiz(
        _vocabs(6),
        module: QuizModule.hanziToMeaning,
        answerMode: QuizAnswerMode.multipleChoice,
        sessionSize: null,
      );
      for (var i = 0; i < 15; i++) {
        expect(quiz.options, hasLength(4));
        await quiz.checkAnswer(quiz.correctIndex());
        quiz.nextQuestion();
      }
      expect(quiz.quizFinished, isFalse);
      expect(quiz.score, 15);
    });

    test('finishSession ends the session and keeps the totals', () async {
      final quiz = _quiz(_Recorder());
      quiz.startNewQuiz(
        _vocabs(3),
        module: QuizModule.hanziToMeaning,
        answerMode: QuizAnswerMode.essay,
        sessionSize: null,
      );
      await _gotIt(quiz);
      await _gotIt(quiz);

      quiz.finishSession();

      expect(quiz.quizFinished, isTrue);
      expect(quiz.hasCurrent, isFalse);
      expect(quiz.completedCount, 2);
      expect(quiz.score, 2);
    });

    test('a fixed size trims the deck and finishes at the end', () async {
      final quiz = _quiz(_Recorder());
      quiz.startNewQuiz(
        _vocabs(10),
        module: QuizModule.hanziToMeaning,
        answerMode: QuizAnswerMode.essay,
        sessionSize: 3,
      );
      expect(quiz.isEndless, isFalse);
      expect(quiz.totalCount, 3);

      while (!quiz.quizFinished) {
        await _gotIt(quiz);
      }
      expect(quiz.completedCount, 3);
    });
  });

  group('scoring', () {
    test('multiple choice records correct and wrong answers', () async {
      final recorder = _Recorder();
      final quiz = _quiz(recorder);
      quiz.startNewQuiz(
        _vocabs(4),
        module: QuizModule.hanziToMeaning,
        answerMode: QuizAnswerMode.multipleChoice,
      );
      final right = quiz.correctIndex();
      final wrong = (right + 1) % quiz.options.length;

      expect(await quiz.checkAnswer(wrong), isFalse);
      expect(quiz.score, 0);
      quiz.nextQuestion();
      expect(await quiz.checkAnswer(quiz.correctIndex()), isTrue);

      expect(quiz.score, 1);
      expect(recorder.calls.map((c) => c.$2), [false, true]);
    });

    test('Zhuyin to Hanzi prompts with the Zhuyin', () {
      final quiz = _quiz(_Recorder());
      quiz.startNewQuiz(
        _vocabs(4),
        module: QuizModule.hanziByZhuyin,
        answerMode: QuizAnswerMode.essay,
      );
      expect(quiz.questionText, quiz.current!.zhuyin);
    });
  });

  group('SettingsProvider session size', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to 20 words', () async {
      final settings = SettingsProvider();
      await settings.load();
      expect(settings.sessionSize, 20);
    });

    test('persists a custom size and "no limit"', () async {
      final settings = SettingsProvider();
      await settings.setSessionSize(37);
      var reloaded = SettingsProvider();
      await reloaded.load();
      expect(reloaded.sessionSize, 37);

      await settings.setSessionSize(null);
      reloaded = SettingsProvider();
      await reloaded.load();
      expect(reloaded.sessionSize, isNull);
    });

    test('clamps out-of-range values', () async {
      final settings = SettingsProvider();
      await settings.setSessionSize(5000);
      expect(settings.sessionSize, SettingsProvider.maxSessionSize);
      await settings.setSessionSize(0);
      expect(settings.sessionSize, SettingsProvider.minSessionSize);
    });
  });
}
