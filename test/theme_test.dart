import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/ui/theme.dart';
import 'package:paperplay/ui/widgets.dart';

void main() {
  testWidgets('rounded menu opens and selects in both themes', (tester) async {
    for (final brightness in Brightness.values) {
      var chosen = '';
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness),
          home: Scaffold(
            body: Center(
              child: RoundedSelect(
                value: 'one',
                options: const {'one': '顺序播放', 'two': '随机播放'},
                onSelected: (v) => chosen = v,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('顺序播放'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('随机播放'));
      await tester.pumpAndSettle();
      expect(chosen, 'two');
      expect(tester.takeException(), isNull);
    }
  });
}
