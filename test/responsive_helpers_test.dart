import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mandarin_app/core/responsive.dart';

Future<Responsive2> _probe(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late Responsive2 result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          result = Responsive2(
            Responsive.isCompact(context),
            Responsive.useSplitLayout(context),
            Responsive.getBreakpoint(context),
          );
          return const SizedBox();
        },
      ),
    ),
  );
  return result;
}

class Responsive2 {
  Responsive2(this.compact, this.split, this.breakpoint);
  final bool compact, split;
  final AppBreakpoint breakpoint;
}

void main() {
  testWidgets('phones are compact in both orientations', (tester) async {
    for (final size in const [
      Size(360, 640),
      Size(412, 915),
      Size(640, 360),
      Size(800, 360),
      Size(915, 412),
    ]) {
      expect((await _probe(tester, size)).compact, isTrue, reason: '$size');
    }
  });

  testWidgets('landscape phones use the split layout, portrait never', (
    tester,
  ) async {
    for (final size in const [Size(640, 360), Size(800, 360), Size(915, 412)]) {
      expect((await _probe(tester, size)).split, isTrue, reason: '$size');
    }
    for (final size in const [Size(360, 640), Size(412, 915)]) {
      expect((await _probe(tester, size)).split, isFalse, reason: '$size');
    }
  });

  testWidgets('tablets and desktops keep their layout', (tester) async {
    for (final size in const [Size(1024, 768), Size(1280, 800)]) {
      final r = await _probe(tester, size);
      expect(r.compact, isFalse, reason: '$size');
      expect(r.split, isFalse, reason: '$size');
    }
    expect(
      (await _probe(tester, const Size(1024, 768))).breakpoint,
      AppBreakpoint.tablet,
    );
  });
}
