import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/ui/playback_timeline.dart';
import 'package:paperplay/ui/video_controls_surface.dart';

void main() {
  testWidgets('long drag stays visible; leaving and releasing recovers hover', (
    tester,
  ) async {
    final seeks = <Duration>[];
    var fullscreen = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 500,
              height: 300,
              child: VideoControlsSurface(
                shortcuts: const {},
                onFullscreen: () => fullscreen++,
                onVolumeScroll: (_) {},
                child: PlaybackTimeline(
                  height: 40,
                  positionStream: const Stream.empty(),
                  durationStream: const Stream.empty(),
                  initialPosition: const Duration(seconds: 10),
                  initialDuration: const Duration(seconds: 100),
                  onSeek: seeks.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final surface = find.byType(VideoControlsSurface);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(surface));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(Slider));
    await mouse.moveTo(rect.center);
    await mouse.down(rect.center);
    await mouse.moveTo(Offset(rect.right - 30, rect.center.dy - 10));
    await tester.pump(const Duration(seconds: 5));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('video-controls-opacity')),
          )
          .opacity,
      1,
    );
    expect(seeks, isEmpty);
    await mouse.moveTo(Offset(rect.right + 100, rect.center.dy));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(seeks, hasLength(1));
    expect(fullscreen, 0);
    await mouse.moveTo(tester.getCenter(surface));
    await tester.pump();
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('video-controls-opacity')),
          )
          .opacity,
      1,
    );
    await tester.pump(const Duration(seconds: 4));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('video-controls-opacity')),
          )
          .opacity,
      0,
    );
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
