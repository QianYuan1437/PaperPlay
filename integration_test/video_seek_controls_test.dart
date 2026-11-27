import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:paperplay/models/media_entry.dart';
import 'package:paperplay/services/playback_controller.dart';
import 'package:paperplay/ui/player_view.dart';
import 'package:paperplay/ui/playback_timeline.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('video surface previews a drag without seeking on every move', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    final playback = PlaybackController();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await playback.shutdown();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlayerView(playback: playback)),
      ),
    );
    await (playback.player.platform as NativePlayer).setProperty('ao', 'null');
    await playback.play([
      MediaEntry(
        path: File('docs/media/tide.mp4').absolute.path,
        title: 'Drag regression',
        source: MediaSource.local,
      ),
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await playback.toggle();
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(Video)));
    await tester.pumpAndSettle();
    final stockBar = find.byType(MaterialDesktopSeekBar);
    final slider = stockBar.evaluate().isNotEmpty
        ? stockBar
        : find.descendant(
            of: find.byType(PlaybackTimeline),
            matching: find.byType(Slider),
          );
    final rect = tester.getRect(slider);
    final before = playback.player.state.position;
    await mouse.moveTo(Offset(rect.left + rect.width * 0.2, rect.center.dy));
    await mouse.down(Offset(rect.left + rect.width * 0.2, rect.center.dy));
    for (var move = 0; move < 12; move++) {
      await mouse.moveTo(
        Offset(rect.left + rect.width * (0.25 + move * 0.04), rect.center.dy),
      );
      await tester.pump();
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    expect(
      (playback.player.state.position - before).abs(),
      lessThan(const Duration(milliseconds: 150)),
      reason: 'Pointer movement must not queue expensive precise decoder seeks',
    );
    await mouse.up();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    expect(
      playback.player.state.position,
      greaterThan(const Duration(seconds: 5)),
    );
    expect(
      playback.playing,
      isFalse,
      reason: 'Seeking a paused video must keep it paused',
    );
    await mouse.removePointer();
  });
}
