import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:paperplay/models/media_entry.dart';
import 'package:paperplay/models/queue_order.dart';
import 'package:paperplay/services/playback_controller.dart';
import 'package:paperplay/ui/player_view.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'audio-to-video keeps the video surface mounted and the clock running',
    (tester) async {
      MediaKit.ensureInitialized();
      final playback = PlaybackController();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await playback.shutdown();
      });
      final media = File(
        const String.fromEnvironment(
          'TEST_MEDIA',
          defaultValue: 'test/fixtures/sample.mp4',
        ),
      ).absolute;
      playback.queue.add(
        MediaEntry(
          path: media.path,
          title: 'Switch regression',
          source: MediaSource.local,
        ),
      );
      playback.setMode(PlayMode.repeatOne);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PlayerView(playback: playback)),
        ),
      );
      await tester.pumpAndSettle();
      await (playback.player.platform as NativePlayer).setProperty(
        'ao',
        'null',
      );
      await playback.toggle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pumpAndSettle();
      final surface = tester.state(find.byType(Video));
      final durations = <int>[];
      final engineDurations = <int>[];
      var reused = true;
      for (var i = 0; i < 3; i++) {
        await playback.setAudioOnly(true);
        await tester.pumpAndSettle();
        expect(playback.player.state.track.video.id, 'no');
        expect(
          tester
              .widget<AnimatedOpacity>(
                find.byKey(const ValueKey('audio-mode-cover')),
              )
              .opacity,
          1,
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        final watch = Stopwatch()..start();
        await playback.setAudioOnly(false);
        engineDurations.add(watch.elapsedMilliseconds);
        await tester.pumpAndSettle();
        durations.add(watch.elapsedMilliseconds);
        reused &= identical(tester.state(find.byType(Video)), surface);
        expect(playback.playing, isTrue);
        expect(
          tester
              .widget<AnimatedOpacity>(
                find.byKey(const ValueKey('audio-mode-cover')),
              )
              .opacity,
          0,
        );
      }
      // A diagnostic metric, not a machine-speed-dependent pass threshold.
      // ignore: avoid_print
      print(
        'Audio-to-video engine ms: $engineDurations; settled ms: $durations; reused surface: $reused',
      );
      expect(
        reused,
        isTrue,
        reason:
            'Recreating Video on every audio-to-video switch reinitializes its rendering and controls',
      );
    },
  );
}
