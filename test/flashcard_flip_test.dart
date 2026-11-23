import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mandarin_app/controllers/menu_app_controller.dart';
import 'package:mandarin_app/core/responsive.dart';
import 'package:mandarin_app/models/review_event.dart';
import 'package:mandarin_app/models/vocabulary.dart';
import 'package:mandarin_app/providers/quiz_provider.dart';
import 'package:mandarin_app/providers/settings_provider.dart';
import 'package:mandarin_app/screens/quiz/quiz_session_screen.dart';

const _front = ValueKey('flashcard-front');
const _back = ValueKey('flashcard-back');
const _card = ValueKey('flashcard-card');

const _sizes = <String, Size>{
  '360x640': Size(360, 640),
  '412x915': Size(412, 915),
  '640x360': Size(640, 360),
  '915x412': Size(915, 412),
  '1024x768': Size(1024, 768),
};

List<Vocabulary> _vocabs({int count = 8, bool long = false}) => List.generate(
  count,
  (i) => Vocabulary(
    id: i + 1,
    hanzi: '學習$i',
    pinyin: 'xué xí $i',
    zhuyin: 'ㄒㄩㄝˊ',
    meaning: long
        ? 'to study or learn something over a long period of time, '
              'usually with effort and repetition, again and again ($i)'
        : 'to study $i',
    category: 'test',
  ),
);

class _Harness {
  _Harness(this.quiz, this.events);
  final QuizProvider quiz;
  final List<ReviewEvent> events;
}

_Harness _harness({
  QuizAnswerMode mode = QuizAnswerMode.essay,
  QuizModule module = QuizModule.hanziToMeaning,
  int count = 8,
  int sessionSize = 5,
  bool long = false,
}) {
  final events = <ReviewEvent>[];
  final quiz = QuizProvider(
    recordReview: (e) async => events.add(e),
    random: Random(1),
  );
  quiz.startNewQuiz(
    _vocabs(count: count, long: long),
    module: module,
    answerMode: mode,
    sessionSize: sessionSize,
  );
  return _Harness(quiz, events);
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

// Mirrors the schemes built in lib/main.dart.
ThemeData _theme(Brightness brightness) {
  const crimson = Color(0xFF9D1F3C);
  const jade = Color(0xFF087B68);
  final base = ColorScheme.fromSeed(
    seedColor: crimson,
    tertiary: jade,
    brightness: brightness,
  );
  final scheme = brightness == Brightness.light
      ? base.copyWith(primary: crimson, surface: const Color(0xFFFAF7F4))
      : base.copyWith(
          primary: const Color(0xFFFF7C8D),
          surface: const Color(0xFF1B1817),
        );
  return ThemeData(colorScheme: scheme, useMaterial3: true);
}

Future<void> _pump(
  WidgetTester tester,
  QuizProvider quiz, {
  double textScale = 1,
  bool timer = false,
  bool disableAnimations = false,
  ThemeData? theme,
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
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
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

const _flipTime = Duration(milliseconds: 400);

Future<void> _showAnswer(WidgetTester tester) async {
  await tester.tap(find.text('Show answer'));
  await tester.pump();
  await tester.pump(_flipTime);
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance() + 0.05;
  final lb = b.computeLuminance() + 0.05;
  return la > lb ? la / lb : lb / la;
}

Finder get _gotIt => find.widgetWithText(FilledButton, 'Got It');
Finder get _reviewLater => find.widgetWithText(FilledButton, 'Review Later');

void _clean(WidgetTester tester, String reason) =>
    expect(tester.takeException(), isNull, reason: reason);

void main() {
  group('one card that flips', () {
    testWidgets('one card before and after reveal, front first', (
      tester,
    ) async {
      _setView(tester, const Size(412, 915));
      final h = _harness();
      await _pump(tester, h.quiz);

      expect(find.byKey(_card), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byKey(_front), findsOneWidget);
      expect(find.byKey(_back), findsNothing);

      await _showAnswer(tester);
      expect(find.byKey(_card), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byKey(_front), findsNothing);
      expect(find.byKey(_back), findsOneWidget);
      expect(find.text(h.quiz.answerText), findsOneWidget);
      _clean(tester, 'flip');
    });

    testWidgets('tapping the card shows the back; tapping again does not '
        'flip back', (tester) async {
      _setView(tester, const Size(412, 915));
      final h = _harness();
      await _pump(tester, h.quiz);

      await tester.tap(find.byKey(_front));
      await tester.pump();
      await tester.pump(_flipTime);
      expect(h.quiz.revealed, isTrue);
      expect(find.byKey(_back), findsOneWidget);

      await tester.tap(find.byKey(_back));
      await tester.pump(_flipTime);
      expect(find.byKey(_back), findsOneWidget);
      expect(find.byKey(_front), findsNothing);
      expect(h.quiz.answered, isFalse);
    });

    testWidgets('next card starts on its front', (tester) async {
      _setView(tester, const Size(412, 915));
      final h = _harness();
      await _pump(tester, h.quiz);
      final first = h.quiz.current;

      await _showAnswer(tester);
      await tester.tap(_gotIt);
      await tester.pump();
      await tester.pump(flashcardAdvanceDelay);
      await tester.pump(flashcardEnterDuration);

      expect(h.quiz.current, isNot(same(first)));
      expect(find.byKey(_card), findsOneWidget);
      expect(find.byKey(_front), findsOneWidget);
      expect(find.byKey(_back), findsNothing);
      expect(find.text('Show answer'), findsOneWidget);
    });

    testWidgets('back side is not mirrored', (tester) async {
      _setView(tester, const Size(412, 915));
      final h = _harness();
      await _pump(tester, h.quiz);
      await _showAnswer(tester);
      final m = tester
          .renderObject(find.text(h.quiz.answerText))
          .getTransformTo(null);
      expect(m.storage[0], greaterThan(0.9));
    });

    testWidgets('semantics tell which side is showing', (tester) async {
      _setView(tester, const Size(412, 915));
      final handle = tester.ensureSemantics();
      final h = _harness();
      await _pump(tester, h.quiz);
      await tester.pump(flashcardEnterDuration); // fade-in ends
      expect(find.bySemanticsLabel(RegExp('Question side')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Answer side')), findsNothing);
      await _showAnswer(tester);
      expect(find.bySemanticsLabel(RegExp('Answer side')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Question side')), findsNothing);
      handle.dispose();
    });

    testWidgets('back shows answerText plus only the details it lacks', (
      tester,
    ) async {
      _setView(tester, const Size(412, 915));
      final h = _harness(); // hanziToMeaning: answerText is the meaning.
      await _pump(tester, h.quiz);
      await _showAnswer(tester);
      bool badge(String label) => find
          .byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().startsWith('$label:'),
          )
          .evaluate()
          .isNotEmpty;
      expect(badge('Hanzi'), isTrue);
      expect(badge('Pronunciation'), isTrue);
      expect(badge('Meaning'), isFalse);
    });

    testWidgets('multiple choice has no flashcard', (tester) async {
      _setView(tester, const Size(412, 915));
      final h = _harness(mode: QuizAnswerMode.multipleChoice);
      await _pump(tester, h.quiz);
      expect(find.byKey(_card), findsNothing);
      expect(find.text('A'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('reduced motion', () {
    testWidgets('disableAnimations flips at once', (tester) async {
      _setView(tester, const Size(412, 915));
      final h = _harness();
      await _pump(tester, h.quiz, disableAnimations: true);
      await tester.tap(find.text('Show answer'));
      await tester.pump(); // a single frame, no time passes
      expect(find.byKey(_back), findsOneWidget);
      expect(find.byKey(_front), findsNothing);

      await tester.tap(_gotIt);
      await tester.pump();
      await tester.pump(flashcardAdvanceDelay);
      expect(find.byKey(_front), findsOneWidget);
      expect(
        tester.widget<Opacity>(find.byType(Opacity).first).opacity,
        1,
        reason: 'the next card appears without fading in',
      );
    });

    testWidgets('with animations on, the flip takes time', (tester) async {
      _setView(tester, const Size(412, 915));
      final h = _harness();
      await _pump(tester, h.quiz);
      await tester.tap(find.text('Show answer'));
      await tester.pump();
      expect(find.byKey(_front), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_front), findsOneWidget);
      await tester.pump(_flipTime);
      expect(find.byKey(_back), findsOneWidget);
    });
  });

  group('timer', () {
    testWidgets('running out flips the card', (tester) async {
      _setView(tester, const Size(412, 915));
      final h = _harness();
      await _pump(tester, h.quiz, timer: true);
      expect(find.byKey(_front), findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
      await tester.pump(_flipTime);
      expect(h.quiz.revealed, isTrue);
      expect(h.quiz.answered, isFalse);
      expect(find.byKey(_back), findsOneWidget);
      expect(find.byKey(_front), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('buttons', () {
    testWidgets('Show answer is as wide as the content', (tester) async {
      for (final size in const [Size(360, 640), Size(412, 915)]) {
        _setView(tester, size);
        final h = _harness();
        await _pump(tester, h.quiz);
        final button = tester.getRect(
          find.widgetWithText(FilledButton, 'Show answer'),
        );
        expect(
          button.width,
          size.width - 2 * Responsive.compactCardPadding,
          reason: '$size',
        );
        expect(button.height, greaterThanOrEqualTo(56));
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('Got It and Review Later: tall, equal, side by side', (
      tester,
    ) async {
      for (final size in const [
        Size(360, 640),
        Size(412, 915),
        Size(640, 360),
        Size(915, 412),
        Size(1024, 768),
      ]) {
        _setView(tester, size);
        final h = _harness();
        await _pump(tester, h.quiz);
        await _showAnswer(tester);
        final later = tester.getRect(_reviewLater);
        final got = tester.getRect(_gotIt);
        final minHeight = size.height < 480 ? 56 : 64;
        expect(later.height, greaterThanOrEqualTo(minHeight), reason: '$size');
        expect(got.height, greaterThanOrEqualTo(minHeight), reason: '$size');
        expect(later.width, got.width, reason: '$size');
        expect(later.top, got.top, reason: '$size');
        expect(
          got.left - later.right,
          greaterThanOrEqualTo(Responsive.flashcardActionGap),
          reason: '$size',
        );
        _clean(tester, '$size');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('Review limit reached disables the button', (tester) async {
      _setView(tester, const Size(412, 915));
      final h = _harness(count: 1, sessionSize: 1);
      for (var i = 0; i < QuizProvider.maxReviewLaterPerWord; i++) {
        h.quiz.revealAnswer();
        await h.quiz.reviewLater();
        h.quiz.nextQuestion();
      }
      expect(h.quiz.canReviewLater, isFalse);

      await _pump(tester, h.quiz);
      await _showAnswer(tester);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Review limit reached'),
      );
      expect(button.onPressed, isNull);
      expect(tester.widget<FilledButton>(_gotIt).onPressed, isNotNull);
      _clean(tester, 'limit');
    });

    testWidgets('a fast double tap advances exactly once', (tester) async {
      _setView(tester, const Size(412, 915));
      final h = _harness();
      await _pump(tester, h.quiz);
      final first = h.quiz.current;
      await _showAnswer(tester);

      await tester.tap(_gotIt);
      await tester.tap(_gotIt, warnIfMissed: false);
      await tester.tap(_reviewLater, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(h.quiz.current, same(first), reason: 'delay not over yet');

      await tester.pump(const Duration(milliseconds: 100));
      expect(h.quiz.current, isNot(same(first)));
      expect(h.quiz.completedCount, 1);
      expect(h.events, hasLength(1));
      expect(h.events.single.correct, isTrue);

      await tester.pump(const Duration(seconds: 2));
      expect(h.quiz.completedCount, 1, reason: 'no second advance');
    });
  });

  group('no overflow', () {
    _sizes.forEach((name, size) {
      testWidgets('long content, both sides @ $name', (tester) async {
        _setView(tester, size);
        final h = _harness(
          long: true,
          module: QuizModule.hanziToPinyinAndMeaning,
        );
        await _pump(tester, h.quiz);
        _clean(tester, 'front');
        await _showAnswer(tester);
        _clean(tester, 'back');
        await tester.pumpWidget(const SizedBox());
      });
    });

    for (final size in const [Size(360, 640), Size(640, 360)]) {
      for (final module in QuizModule.values) {
        testWidgets('text scale 1.3, $module @ $size', (tester) async {
          _setView(tester, size);
          final h = _harness(long: true, module: module);
          await _pump(tester, h.quiz, textScale: 1.3);
          _clean(tester, 'front');
          await tester.ensureVisible(find.text('Show answer'));
          await _showAnswer(tester);
          _clean(tester, 'back');
          await tester.ensureVisible(_gotIt);
          expect(tester.getRect(_gotIt).height, greaterThanOrEqualTo(56));
          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    testWidgets('limit text wraps without overflow at 360x640 x1.3', (
      tester,
    ) async {
      _setView(tester, const Size(360, 640));
      final h = _harness(count: 1, sessionSize: 1);
      for (var i = 0; i < QuizProvider.maxReviewLaterPerWord; i++) {
        h.quiz.revealAnswer();
        await h.quiz.reviewLater();
        h.quiz.nextQuestion();
      }
      await _pump(tester, h.quiz, textScale: 1.3);
      await tester.ensureVisible(find.text('Show answer'));
      await _showAnswer(tester);
      expect(find.text('Review limit reached'), findsOneWidget);
      _clean(tester, 'limit x1.3');
    });
  });

  group('bottom inset', () {
    for (final bottom in const [24.0, 48.0]) {
      for (final size in const [Size(360, 640), Size(412, 915)]) {
        testWidgets('buttons clear a ${bottom}px bar @ $size', (tester) async {
          _setView(tester, size, insets: EdgeInsets.only(bottom: bottom));
          final h = _harness();
          await _pump(tester, h.quiz);
          final show = tester.getRect(find.text('Show answer'));
          expect(show.bottom, lessThanOrEqualTo(size.height - bottom));

          await _showAnswer(tester);
          expect(
            tester.getRect(_gotIt).bottom,
            lessThanOrEqualTo(size.height - bottom),
          );
          expect(
            tester.getRect(_reviewLater).bottom,
            lessThanOrEqualTo(size.height - bottom),
          );
          _clean(tester, 'inset');
          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    testWidgets('landscape keeps buttons inside notch and bar', (tester) async {
      const size = Size(915, 412);
      _setView(tester, size, insets: const EdgeInsets.fromLTRB(44, 0, 44, 24));
      final h = _harness();
      await _pump(tester, h.quiz);
      await _showAnswer(tester);
      for (final finder in [_gotIt, _reviewLater]) {
        final r = tester.getRect(finder);
        expect(r.bottom, lessThanOrEqualTo(size.height - 24));
        expect(r.right, lessThanOrEqualTo(size.width - 44));
        expect(r.left, greaterThanOrEqualTo(44));
      }
      _clean(tester, 'landscape');
    });
  });

  group('verdict colours come from the ColorScheme', () {
    for (final brightness in Brightness.values) {
      for (final gotIt in [true, false]) {
        testWidgets(
          '${brightness.name} theme, ${gotIt ? 'Got It' : 'Review Later'}',
          (tester) async {
            _setView(tester, const Size(412, 915));
            final theme = _theme(brightness);
            final scheme = theme.colorScheme;
            final h = _harness();
            await _pump(tester, h.quiz, theme: theme);
            await _showAnswer(tester);

            // Button labels are readable on their backgrounds.
            for (final finder in [_gotIt, _reviewLater]) {
              final style = tester.widget<FilledButton>(finder).style!;
              final fg = style.foregroundColor!.resolve({})!;
              final bg = style.backgroundColor!.resolve({})!;
              expect(_contrast(fg, bg), greaterThanOrEqualTo(3));
            }
            final gotStyle = tester.widget<FilledButton>(_gotIt).style!;
            expect(gotStyle.backgroundColor!.resolve({}), scheme.tertiary);
            final laterStyle = tester.widget<FilledButton>(_reviewLater).style!;
            expect(
              laterStyle.backgroundColor!.resolve({}),
              scheme.errorContainer,
            );

            await tester.tap(gotIt ? _gotIt : _reviewLater);
            await tester.pump(const Duration(milliseconds: 50));
            final card = tester.widget<Card>(
              find.descendant(
                of: find.byKey(_card),
                matching: find.byType(Card),
              ),
            );
            final side = (card.shape! as RoundedRectangleBorder).side;
            expect(side.color, gotIt ? scheme.tertiary : scheme.error);
            expect(
              _contrast(side.color, scheme.surface),
              greaterThanOrEqualTo(3),
            );
            await tester.pump(const Duration(seconds: 1));
          },
        );
      }
    }
  });
}
