import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mandarin_app/controllers/menu_app_controller.dart';
import 'package:mandarin_app/models/library_list.dart';
import 'package:mandarin_app/providers/quiz_provider.dart';
import 'package:mandarin_app/providers/settings_provider.dart';
import 'package:mandarin_app/screens/main/components/header.dart';
import 'package:mandarin_app/screens/main/components/side_menu.dart';
import 'package:mandarin_app/widgets/custom_app_bar.dart';

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('choosing a drawer item closes the drawer without popping the page', (
    tester,
  ) async {
    _phoneSize(tester);
    final menu = MenuAppController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: menu,
        child: MaterialApp(
          home: Scaffold(
            key: menu.scaffoldKey,
            drawer: const SideMenu(),
            body: const Text('home body'),
          ),
        ),
      ),
    );

    menu.openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Practice Quiz'), findsOneWidget);

    await tester.tap(find.text('Practice Quiz'));
    await tester.pumpAndSettle();

    expect(find.text('home body'), findsOneWidget, reason: 'page must remain');
    expect(menu.selectedIndex, MenuAppController.quizIndex);
    expect(menu.scaffoldKey.currentState!.isDrawerOpen, isFalse);
  });

  testWidgets('choosing the already selected drawer item just closes the drawer', (
    tester,
  ) async {
    _phoneSize(tester);
    final menu = MenuAppController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: menu,
        child: MaterialApp(
          home: Scaffold(
            key: menu.scaffoldKey,
            drawer: const SideMenu(),
            body: const Text('home body'),
          ),
        ),
      ),
    );

    menu.openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('home body'), findsOneWidget);
    expect(menu.scaffoldKey.currentState!.isDrawerOpen, isFalse);
  });

  testWidgets('header menu button opens the drawer', (tester) async {
    _phoneSize(tester);
    final menu = MenuAppController();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: menu),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            key: menu.scaffoldKey,
            drawer: const Drawer(child: Text('drawer content')),
            body: Header(title: 'Title', onMenuTap: menu.openDrawer),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();

    expect(find.text('drawer content'), findsOneWidget);
  });

  testWidgets(
    'a section app bar rebuilt under another page does not offer a popping Back',
    (tester) async {
      final menu = MenuAppController();
      late VoidCallback rebuildRoot;
      late BuildContext rootContext;
      var builds = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: menu,
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                rootContext = context;
                rebuildRoot = () => setState(() {});
                builds++;
                return Scaffold(appBar: CustomAppBar(title: 'Section $builds'));
              },
            ),
          ),
        ),
      );
      menu.setSelectedIndex(MenuAppController.quizIndex);
      await tester.pump();
      rebuildRoot();
      await tester.pump();
      expect(find.byTooltip('Back to Dashboard'), findsOneWidget);

      Navigator.of(rootContext).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('pushed page')),
        ),
      );
      await tester.pumpAndSettle();
      rebuildRoot(); // e.g. a provider change while the page is covered
      await tester.pump();
      Navigator.of(rootContext).pop();
      await tester.pumpAndSettle();

      expect(find.byTooltip('Back'), findsNothing);
      expect(find.byTooltip('Back to Dashboard'), findsOneWidget);
    },
  );

  testWidgets('a pushed page shows a Back button that leaves the page', (
    tester,
  ) async {
    final menu = MenuAppController();
    late BuildContext rootContext;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: menu,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              rootContext = context;
              return const Scaffold(body: Text('root'));
            },
          ),
        ),
      ),
    );
    Navigator.of(rootContext).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(appBar: CustomAppBar(title: 'Pushed')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('openQuiz selects the quiz section with the chosen module/library', (
    tester,
  ) async {
    final menu = MenuAppController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: menu,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    final library = LibraryList(
      id: 3,
      name: 'Hard words',
      createdAt: DateTime(2026),
      itemCount: 5,
    );

    menu.openQuiz(module: QuizModule.hanziToMeaning, library: library);
    await tester.pump();

    expect(menu.selectedIndex, MenuAppController.quizIndex);
    expect(menu.quizModule, QuizModule.hanziToMeaning);
    expect(menu.quizLibrary, same(library));

    menu.openQuiz();
    await tester.pump();
    expect(menu.quizModule, QuizModule.pinyinToHanziAndMeaning);
    expect(menu.quizLibrary, isNull);
  });
}
