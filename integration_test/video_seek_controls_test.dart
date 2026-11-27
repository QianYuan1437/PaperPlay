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
    // Real users can hold a drag past the desktop controls' hover timeout.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 3400)),
    );
    await tester.pumpAndSettle();
    expect(
      slider,
      findsOneWidget,
      reason: 'The seek control must stay mounted while dragging',
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('video-controls-opacity')),
          )
          .opacity,
      1,
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
    // Seek backwards while playing, including a vertical deviation of the
    // mouse; a parent volume pan gesture must not steal the timeline drag.
    await playback.toggle();
    await mouse.moveTo(Offset(rect.left + rect.width * 0.7, rect.center.dy));
    await mouse.down(Offset(rect.left + rect.width * 0.7, rect.center.dy));
    await mouse.moveTo(
      Offset(rect.left + rect.width * 0.2, rect.center.dy - 12),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 3400)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('video-controls-opacity')),
          )
          .opacity,
      1,
    );
    await mouse.up();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    expect(
      playback.player.state.position,
      lessThan(const Duration(seconds: 5)),
    );
    expect(playback.playing, isTrue);
    await playback.toggle();
    final videoState = tester.state<VideoState>(find.byType(Video));
    await videoState.enterFullscreen();
    await tester.pumpAndSettle();
    await mouse.moveTo(tester.getCenter(find.byType(Video)));
    await tester.pumpAndSettle();
    final fullscreenSlider = find.descendant(
      of: find.byType(PlaybackTimeline),
      matching: find.byType(Slider),
    );
    expect(fullscreenSlider, findsOneWidget);
    final fullscreenRect = tester.getRect(fullscreenSlider);
    await mouse.moveTo(fullscreenRect.center);
    await mouse.down(fullscreenRect.center);
    await mouse.moveTo(
      Offset(
        fullscreenRect.left + fullscreenRect.width * 0.75,
        fullscreenRect.center.dy,
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 3400)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('video-controls-opacity')),
          )
          .opacity,
      1,
    );
    await mouse.up();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    expect(
      playback.player.state.position,
      greaterThan(const Duration(seconds: 7)),
    );
    await videoState.exitFullscreen();
    await tester.pumpAndSettle();
    await mouse.removePointer();
  });
}
