import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/ui/widgets.dart';

void main() {
  testWidgets(
    'privacy updates existing previews without replacing their media',
    (tester) async {
      Widget page(bool enabled) => MaterialApp(
        home: PreviewPrivacy(
          enabled: enabled,
          child: const Center(
            child: MediaArt(entry: null, width: 160, height: 90),
          ),
        ),
      );
      await tester.pumpWidget(page(false));
      expect(
        tester.widget<ImageFiltered>(find.byType(ImageFiltered)).enabled,
        isFalse,
      );
      await tester.pumpWidget(page(true));
      expect(
        tester.widget<ImageFiltered>(find.byType(ImageFiltered)).enabled,
        isTrue,
      );
      await tester.pumpWidget(page(false));
      expect(
        tester.widget<ImageFiltered>(find.byType(ImageFiltered)).enabled,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
