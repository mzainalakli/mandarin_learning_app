import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mandarin_app/controllers/menu_app_controller.dart';
import 'package:mandarin_app/models/vocabulary.dart';
import 'package:mandarin_app/providers/quiz_provider.dart';
import 'package:mandarin_app/providers/settings_provider.dart';
import 'package:mandarin_app/screens/quiz/quiz_session_screen.dart';

const _sizes = <String, Size>{
  'portrait 360x640': Size(360, 640),
  'portrait 412x915': Size(412, 915),
  'landscape 640x360': Size(640, 360),
  'landscape 915x412': Size(915, 412),
  'landscape 800x360': Size(800, 360),
  'tablet 1024x768': Size(1024, 768),
};

List<Vocabulary> _vocabs({bool long = false}) => List.generate(
  8,
  (i) => Vocabulary(
    id: i + 1,
    hanzi: '學習$i',
    pinyin: 'xué xí $i',
    zhuyin: 'ㄒㄩㄝˊ',
    meaning: long
        ? 'to study or learn something over a long period of time, '
              'usually with effort and repetition ($i)'
        : 'to study $i',
    category: 'test',
  ),
);

QuizProvider _quiz(
  QuizAnswerMode mode, {
  QuizModule module = QuizModule.hanziToMeaning,
  bool long = false,
}) {
  final quiz = QuizProvider(recordReview: (_, _) async {}, random: Random(1));
  quiz.startNewQuiz(
    _vocabs(long: long),
    module: module,
    answerMode: mode,
    sessionSize: 5,
  );
  return quiz;
}

void _setView(
  WidgetTester tester,
  Size size, {
  EdgeInsets insets = EdgeInsets.zero,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final padding = FakeViewPadding(
    left: insets.left,
    top: insets.top,
    right: insets.right,
    bottom: insets.bottom,
  );
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester,
  QuizProvider quiz, {
  double textScale = 1,
  bool timer = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsProvider();
  if (timer) await settings.setTimerEnabled(true);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: quiz),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => MenuAppController()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: QuizSessionScreen(
          module: quiz.module,
          answerMode: quiz.answerMode,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Taps option A. The screen auto-advances 700 ms after an answer, so only
/// pump a little; [_flush] drains that delayed call before the test ends.
Future<void> _answerFirstOption(WidgetTester tester) async {
  await tester.tap(find.text('A').first, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _flush(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

void _expectClean(WidgetTester tester, String reason) =>
    expect(tester.takeException(), isNull, reason: reason);

void main() {
  group('quiz layout renders without overflow', () {
    _sizes.forEach((name, size) {
      testWidgets('multiple choice, before and after answering @ $name', (
        tester,
      ) async {
        _setView(tester, size);
        final quiz = _quiz(QuizAnswerMode.multipleChoice);
        await _pump(tester, quiz);
        _expectClean(tester, 'unanswered');

        await _answerFirstOption(tester);
        _expectClean(tester, 'answered');
        expect(find.text('Next word'), findsOneWidget);
        await _flush(tester);
      });

      testWidgets('essay, before and after revealing @ $name', (tester) async {
        _setView(tester, size);
        final quiz = _quiz(QuizAnswerMode.essay);
        await _pump(tester, quiz);
        _expectClean(tester, 'hidden');
        expect(find.text('Show answer'), findsOneWidget);

        await tester.ensureVisible(find.text('Show answer'));
        await tester.tap(find.text('Show answer'));
        await tester.pumpAndSettle();
        _expectClean(tester, 'revealed');
        expect(find.text('Got It'), findsOneWidget);
      });
    });

    testWidgets('all modules and long answers @ 360x640 and 640x360', (
      tester,
    ) async {
      for (final size in const [Size(360, 640), Size(640, 360)]) {
        for (final module in QuizModule.values) {
          _setView(tester, size);
          final quiz = _quiz(
            QuizAnswerMode.multipleChoice,
            module: module,
            long: true,
          );
          await _pump(tester, quiz);
          _expectClean(tester, '$module @ $size');
          await _answerFirstOption(tester);
          _expectClean(tester, '$module answered @ $size');
          await _flush(tester);
        }
      }
    });

    testWidgets('timer in the status line @ 640x360', (tester) async {
      _setView(tester, const Size(640, 360));
      await _pump(tester, _quiz(QuizAnswerMode.multipleChoice), timer: true);
      _expectClean(tester, 'timer');
      expect(find.textContaining('Timer'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('text scale 1.3 on the smallest sizes', () {
    for (final size in const [Size(360, 640), Size(640, 360)]) {
      for (final mode in QuizAnswerMode.values) {
        testWidgets('$mode @ $size', (tester) async {
          _setView(tester, size);
          final quiz = _quiz(mode, long: true);
          await _pump(tester, quiz, textScale: 1.3);
          _expectClean(tester, 'before');
          if (mode == QuizAnswerMode.essay) {
            await tester.ensureVisible(find.text('Show answer'));
            await tester.tap(find.text('Show answer'));
          } else {
            await tester.ensureVisible(find.text('A').first);
            await _answerFirstOption(tester);
          }
          await tester.pump(const Duration(milliseconds: 100));
          _expectClean(tester, 'after');
          await _flush(tester);
        });
      }
    }
  });

  group('compact status line', () {
    testWidgets('portrait phone shows one summary line, not the old card', (
      tester,
    ) async {
      _setView(tester, const Size(412, 915));
      await _pump(tester, _quiz(QuizAnswerMode.multipleChoice));
      expect(find.textContaining('0/5 · Remaining'), findsOneWidget);
      expect(find.text('Session progress'), findsNothing);
    });

    testWidgets('landscape phone wider than 850 is compact too', (
      tester,
    ) async {
      _setView(tester, const Size(915, 412));
      await _pump(tester, _quiz(QuizAnswerMode.multipleChoice));
      expect(find.textContaining('0/5 · Remaining'), findsOneWidget);
      expect(find.text('Session progress'), findsNothing);
    });
  });

  group('tablet is unchanged', () {
    testWidgets('1024x768 keeps the progress card and in-card Show answer', (
      tester,
    ) async {
      _setView(tester, const Size(1024, 768));
      await _pump(tester, _quiz(QuizAnswerMode.essay));
      expect(find.text('Session progress'), findsOneWidget);
      expect(find.textContaining('Remaining •'), findsOneWidget);
      expect(find.text('Show answer'), findsOneWidget);
      // Tablet keeps the full text actions in the app bar.
      expect(find.text('Leave'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      _expectClean(tester, 'tablet');
    });
  });

  group('bottom actions stay inside the safe area', () {
    testWidgets('Next word clears a 40 px navigation bar, portrait', (
      tester,
    ) async {
      const size = Size(412, 915);
      _setView(tester, size, insets: const EdgeInsets.only(bottom: 40));
      await _pump(tester, _quiz(QuizAnswerMode.multipleChoice));
      final lastOption = tester.getRect(find.text('D').first);
      await _answerFirstOption(tester);

      final next = tester.getRect(
        find.widgetWithText(FilledButton, 'Next word'),
      );
      expect(next.bottom, lessThanOrEqualTo(size.height - 40));
      expect(next.height, greaterThanOrEqualTo(48));
      expect(next.top, greaterThanOrEqualTo(lastOption.bottom));
      _expectClean(tester, 'insets');
      await _flush(tester);
    });

    testWidgets('Next word clears a 48 px bar and a notch, landscape', (
      tester,
    ) async {
      const size = Size(915, 412);
      _setView(tester, size, insets: const EdgeInsets.fromLTRB(44, 0, 44, 24));
      await _pump(tester, _quiz(QuizAnswerMode.multipleChoice));
      await _answerFirstOption(tester);

      final next = tester.getRect(
        find.widgetWithText(FilledButton, 'Next word'),
      );
      expect(next.bottom, lessThanOrEqualTo(size.height - 24));
      expect(next.left, greaterThanOrEqualTo(44));
      expect(next.right, lessThanOrEqualTo(size.width - 44));
      _expectClean(tester, 'landscape insets');
      await _flush(tester);
    });

    testWidgets('Got It and Review Later clear the bar at 360x640 x1.3', (
      tester,
    ) async {
      const size = Size(360, 640);
      _setView(tester, size, insets: const EdgeInsets.only(bottom: 48));
      await _pump(tester, _quiz(QuizAnswerMode.essay), textScale: 1.3);
      await tester.ensureVisible(find.text('Show answer'));
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();

      // The page may scroll on this small screen; scroll to the bottom.
      await tester.ensureVisible(find.text('Got It'));
      await tester.pumpAndSettle();
      final gotIt = tester.getRect(find.widgetWithText(FilledButton, 'Got It'));
      expect(gotIt.bottom, lessThanOrEqualTo(size.height - 48));
      expect(gotIt.height, greaterThanOrEqualTo(48));
      _expectClean(tester, 'insets x1.3');
    });
  });
}
