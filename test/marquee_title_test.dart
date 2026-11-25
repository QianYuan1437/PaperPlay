import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/ui/marquee_title.dart';

void main() {
  testWidgets('overflowing titles scroll, short and hidden titles stay still', (
    tester,
  ) async {
    Widget host(String title, {bool active = true, bool reduce = false}) =>
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 120,
                  child: MarqueeTitle(text: title, active: active),
                ),
              ),
            ),
          ),
        );
    const longTitle = '这是一个长度超过播放条标题区域的完整视频标题';
    await tester.pumpWidget(host(longTitle));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('title-scroll-offset')),
    );
    expect(transform.transform.storage[12], lessThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(host(longTitle, active: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('title-scroll-offset')), findsNothing);
    await tester.pumpWidget(host('短标题'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('title-scroll-offset')), findsNothing);
    await tester.pumpWidget(host(longTitle, reduce: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('title-scroll-offset')), findsNothing);
  });
}
