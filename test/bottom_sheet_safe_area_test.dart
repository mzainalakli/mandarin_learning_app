import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mandarin_app/models/vocabulary.dart';
import 'package:mandarin_app/screens/dictionary/vocab_detail_modal.dart';

void _setView(WidgetTester tester, Size size, double bottomInset) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(bottom: bottomInset);
  tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
  addTearDown(tester.view.reset);
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => VocabDetailModal.show(
                context,
                vocab: Vocabulary(
                  id: 1,
                  hanzi: '學習',
                  pinyin: 'xué xí',
                  meaning: 'to study',
                  category: 'TOCFL A1',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, size, inset) in const [
    ('portrait, 3-button bar', Size(412, 915), 48.0),
    ('portrait, gesture bar', Size(360, 640), 24.0),
    ('landscape', Size(640, 360), 40.0),
  ]) {
    testWidgets('detail sheet content clears the navigation bar: $name', (
      tester,
    ) async {
      _setView(tester, size, inset);
      await _openSheet(tester);

      // Scroll the sheet's list to its end, then the last control must sit
      // above the system bar.
      await tester.dragUntilVisible(
        find.text('Create Library & Add'),
        find.byType(ListView).first,
        const Offset(0, -100),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();

      final last = tester.getRect(find.text('Create Library & Add'));
      expect(last.bottom, lessThanOrEqualTo(size.height - inset));
      expect(tester.takeException(), isNull);
    });
  }
}
