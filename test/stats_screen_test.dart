import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mandarin_app/controllers/menu_app_controller.dart';
import 'package:mandarin_app/models/stats_snapshot.dart';
import 'package:mandarin_app/models/vocabulary.dart';
import 'package:mandarin_app/providers/stats_provider.dart';
import 'package:mandarin_app/screens/stats/stats_screen.dart';

const _sizes = <String, Size>{
  '360x640': Size(360, 640),
  '412x915': Size(412, 915),
  '640x360': Size(640, 360),
  '915x412': Size(915, 412),
  '1024x768': Size(1024, 768),
};

StatsSnapshot _snapshot(StatsRange range, {int buckets = 30, int missed = 20}) {
  final start = DateTime(2026, 2, 1);
  return StatsSnapshot(
    range: range,
    totalEvents: 480,
    learnedWords: 1234,
    masteredWords: 321,
    accuracyLast7: 0.82,
    accuracyPrevious7: 0.74,
    streakDays: 12,
    answersToday: 37,
    trend: [
      for (var i = 0; i < buckets; i++)
        TrendBucket(
          start: DateTime(start.year, start.month, start.day + i),
          answers: i % 5 == 0 ? 0 : 10 + i,
          firstAttempts: i % 5 == 0 ? 0 : 8,
          firstCorrect: i % 5 == 0 ? 0 : 4 + i % 4,
        ),
    ],
    modules: const [
      ModuleStat(
        module: 'pinyinToHanziAndMeaning',
        answers: 200,
        firstAttempts: 150,
        firstCorrect: 100,
      ),
      ModuleStat(
        module: 'hanziToPinyinAndMeaning',
        answers: 180,
        firstAttempts: 150,
        firstCorrect: 120,
      ),
      ModuleStat(
        module: 'hanziToMeaning',
        answers: 100,
        firstAttempts: 80,
        firstCorrect: 60,
      ),
    ],
    levels: [
      for (final c in Vocabulary.tocflCategories)
        LevelStat(
          category: c,
          totalWords: 1500,
          masteredWords: 300,
          firstAttempts: 100,
          firstCorrect: 77,
        ),
    ],
    mostMissed: [
      for (var i = 0; i < missed; i++)
        MissedWord(
          vocab: Vocabulary(
            id: i + 1,
            hanzi: i.isEven ? '電腦' : '不好意思，請問一下',
            pinyin: 'diànnǎo $i',
            meaning:
                'a rather long English explanation of the word number $i '
                'that needs to wrap over a couple of lines',
            category: 'TOCFL A1',
          ),
          firstAttempts: 6,
          firstCorrect: 6 - (1 + i % 4),
        ),
    ],
  );
}

Future<MenuAppController> _pump(
  WidgetTester tester,
  Size size,
  StatsProvider stats, {
  double textScale = 1,
  EdgeInsets insets = EdgeInsets.zero,
}) async {
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
  final menu = MenuAppController();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: stats),
        ChangeNotifierProvider.value(value: menu),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: SafeArea(child: StatsScreen())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return menu;
}

void main() {
  group('statistics screen has no overflow', () {
    _sizes.forEach((name, size) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('with data @ $name x$scale', (tester) async {
          final stats = StatsProvider(
            loader: (r) async => _snapshot(r, buckets: r.days),
          );
          await _pump(
            tester,
            size,
            stats,
            textScale: scale,
            insets: const EdgeInsets.only(bottom: 24),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Words learned'), findsOneWidget);
          // Scroll to the bottom: nothing may overflow on the way.
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -5000),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        });

        testWidgets('empty state @ $name x$scale', (tester) async {
          final stats = StatsProvider(
            loader: (r) async => StatsSnapshot.empty(r),
          );
          await _pump(tester, size, stats, textScale: scale);
          expect(tester.takeException(), isNull);
          expect(find.text('No data yet'), findsOneWidget);
          expect(find.text('Start a quiz'), findsOneWidget);
        });
      }
    });
  });

  testWidgets('sparse data explains that a trend needs 2 days', (tester) async {
    final stats = StatsProvider(
      loader: (r) async => _snapshot(r, buckets: 1, missed: 0),
    );
    await _pump(tester, const Size(412, 915), stats);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('at least 2 days'), findsOneWidget);
    expect(find.text('No missed words yet.'), findsOneWidget);
  });

  testWidgets('shows the first-attempt accuracy note and delta', (
    tester,
  ) async {
    final stats = StatsProvider(loader: (r) async => _snapshot(r));
    await _pump(tester, const Size(412, 915), stats);
    expect(find.textContaining('first answer to each word'), findsOneWidget);
    expect(find.text('82%'), findsOneWidget);
    expect(find.textContaining('+8 pts'), findsOneWidget);
  });

  testWidgets('range buttons reload; weak words opens the quiz preset', (
    tester,
  ) async {
    final asked = <StatsRange>[];
    final stats = StatsProvider(
      loader: (r) async {
        asked.add(r);
        return _snapshot(r, buckets: r.days);
      },
    );
    final menu = await _pump(tester, const Size(412, 915), stats);
    await tester.tap(find.text('30d'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(asked, [StatsRange.week, StatsRange.month]);

    await tester.ensureVisible(find.text('Practice weak words'));
    await tester.tap(find.text('Practice weak words'));
    expect(menu.quizWeakWords, isTrue);
  });

  testWidgets('a failing load shows a retry button', (tester) async {
    var fail = true;
    final stats = StatsProvider(
      loader: (r) async {
        if (fail) throw StateError('boom');
        return _snapshot(r);
      },
    );
    await _pump(tester, const Size(412, 915), stats);
    expect(find.text('Retry'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Words learned'), findsOneWidget);
  });
}
