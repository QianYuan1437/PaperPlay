import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:paperplay/models/media_entry.dart';
import 'package:paperplay/models/queue_order.dart';
import 'package:paperplay/services/playback_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'silent wallpaper pauses in background and resumes without losing its place',
    (tester) async {
      MediaKit.ensureInitialized();
      final playback = PlaybackController();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final media = File(
        const String.fromEnvironment(
          'SILENT_MEDIA',
          defaultValue: 'test/fixtures/silent.mp4',
        ),
      ).absolute;
      expect(await media.exists(), isTrue);
      final item = MediaEntry(
        path: media.path,
        title: 'Silent',
        source: MediaSource.local,
      );
      playback.setMode(PlayMode.sequential);
      await playback.play([item, item]);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      final position = playback.player.state.position;
      await playback.setBackgroundVideoSuppressed(true);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      expect(
        playback.index,
        0,
        reason: 'No audio must not make mpv skip the current video',
      );
      expect(playback.playing, isFalse);
      await playback.setBackgroundVideoSuppressed(false);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      expect(playback.playing, isTrue);
      expect(playback.player.state.position, greaterThanOrEqualTo(position));
      await playback.player.pause();
      await playback.setBackgroundVideoSuppressed(true);
      await playback.setBackgroundVideoSuppressed(false);
      expect(
        playback.playing,
        isFalse,
        reason: 'An explicit pause must remain paused',
      );
      await playback.setBackgroundVideoSuppressed(true);
      await playback.play([item]);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      expect(
        playback.playing,
        isFalse,
        reason: 'Opening a silent file while hidden must also pause',
      );
      await playback.setBackgroundVideoSuppressed(false);
      expect(playback.playing, isTrue);
      await playback.setAudioOnly(true);
      expect(playback.playing, isFalse);
      await playback.setAudioOnly(false);
      expect(playback.playing, isTrue);
      await playback.shutdown();
    },
  );
}
