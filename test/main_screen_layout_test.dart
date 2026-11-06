import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mandarin_app/controllers/menu_app_controller.dart';
import 'package:mandarin_app/providers/quiz_provider.dart';
import 'package:mandarin_app/providers/settings_provider.dart';
import 'package:mandarin_app/providers/vocab_provider.dart';
import 'package:mandarin_app/screens/main/components/header.dart';
import 'package:mandarin_app/screens/main/main_screen.dart';

const _sizes = <String, Size>{
  'portrait 360x640': Size(360, 640),
  'portrait 412x915': Size(412, 915),
  'landscape 640x360': Size(640, 360),
  'landscape 915x412': Size(915, 412),
  'landscape 800x360': Size(800, 360),
  'tablet 1024x768': Size(1024, 768),
};

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<MenuAppController> _pump(
  WidgetTester tester, {
  double textScale = 1,
  int section = MenuAppController.dashboardIndex,
}) async {
  SharedPreferences.setMockInitialValues({});
  final menu = MenuAppController()..setSelectedIndex(section);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: menu),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => VocabProvider()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const MainScreen(),
      ),
    ),
  );
  await tester.pump();
  return menu;
}

void main() {
  group('MainScreen header + dashboard render without overflow', () {
    _sizes.forEach((name, size) {
      testWidgets(name, (tester) async {
        _setView(tester, size);
        await _pump(tester);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'scrolled to the end');
      });
    });

    for (final size in const [Size(360, 640), Size(640, 360)]) {
      testWidgets('text scale 1.3 @ $size', (tester) async {
        _setView(tester, size);
        await _pump(tester, textScale: 1.3);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('compact header keeps every function reachable', () {
    for (final size in const [
      Size(360, 640),
      Size(640, 360),
      Size(915, 412),
    ]) {
      testWidgets('$size', (tester) async {
        _setView(tester, size);
        await _pump(tester);
        expect(tester.getSize(find.byType(Header)).height, 56);
        expect(find.byTooltip('Open menu'), findsOneWidget);
        expect(find.byTooltip('Search vocabulary'), findsOneWidget);
        expect(find.byTooltip('Enable timer'), findsOneWidget);
        expect(find.byIcon(Icons.person), findsOneWidget);

        await tester.tap(find.byTooltip('Search vocabulary'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'hello');
        await tester.tap(find.byTooltip('Close search'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.byTooltip('Search vocabulary'), findsOneWidget);

        await tester.tap(find.byTooltip('Enable timer'));
        await tester.pump();
        expect(find.byTooltip('Disable timer'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tablet keeps the full 72 dp header with inline search', (
      tester,
    ) async {
      _setView(tester, const Size(1024, 768));
      await _pump(tester);
      expect(tester.getSize(find.byType(Header)).height, 72);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Search vocabulary'), findsNothing);
    });
  });
}
