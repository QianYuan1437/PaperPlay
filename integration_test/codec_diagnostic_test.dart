import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:paperplay/models/media_entry.dart';
import 'package:paperplay/models/queue_order.dart';
import 'package:paperplay/services/playback_controller.dart';
import 'package:paperplay/ui/player_view.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('recovered codec diagnostics do not remain in the playback bar', (
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
    final native = playback.player.platform as NativePlayer;
    await native.setProperty('ao', 'null');
    final file = File('test/fixtures/sample.mp4').absolute;
    await playback.play([
      MediaEntry(
        path: file.path,
        title: 'Codec regression',
        source: MediaSource.local,
      ),
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 450)),
    );
    final before = playback.player.state.position;

    // Replay the native diagnostic at the error stream boundary while the
    // real decoder continues. This models a failed hardware probe followed by
    // successful fallback without depending on a specific GPU/driver.
    // Test-only fault injection at the same boundary as mpv's log callback.
    // ignore: invalid_use_of_protected_member
    native.errorController.add('Could not open codec.');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1600)),
    );

    expect(playback.player.state.position, greaterThan(before));
    expect(
      playback.error,
      isNull,
      reason: 'Successful decoding must clear a transient codec diagnostic',
    );
    await playback.player.seek(Duration.zero);
    await playback.player.setVideoTrack(VideoTrack.no());
    // ignore: invalid_use_of_protected_member
    native.errorController.add('Could not open codec.');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1000)),
    );
    expect(
      playback.error,
      isNotNull,
      reason: 'Audio progress without video output must not hide the error',
    );
    await playback.player.setVideoTrack(VideoTrack.auto());
    // The GPU-less Windows runner emits this during software fallback.
    // ignore: invalid_use_of_protected_member
    native.errorController.add('Failed to allocate AVHWDeviceContext.');
    await playback.player.seek(Duration.zero);
    await playback.player.play();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1200)),
    );
    expect(
      playback.error,
      isNull,
      reason: 'Restored video output should clear the error',
    );
    await playback.clear();
    expect(playback.error, isNull);
    final folder = await Directory.systemTemp.createTemp('paperplay-codec-');
    addTearDown(() => folder.delete(recursive: true));
    final broken = File('${folder.path}/broken.mp4');
    await broken.writeAsString('not a playable media file');
    await playback.play([
      MediaEntry(
        path: broken.path,
        title: 'Broken file',
        source: MediaSource.local,
      ),
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1000)),
    );
    expect(
      playback.error,
      isNotNull,
      reason: 'Actual media failures must remain visible',
    );
    await playback.clear();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    expect(
      playback.error,
      isNull,
      reason: 'Clearing the queue must clear obsolete errors',
    );
    await playback.play([
      MediaEntry(
        path: '${folder.path}/missing.mp4',
        title: 'Missing file',
        source: MediaSource.local,
      ),
      MediaEntry(
        path: file.path,
        title: 'Available file',
        source: MediaSource.local,
      ),
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    expect(playback.index, 1);
    expect(
      playback.error,
      isNull,
      reason:
          'Skipping a missing file must not mark the next valid file as failed',
    );
    playback.setMode(PlayMode.sequential);
    await playback.play([
      MediaEntry(path: file.path, title: 'First', source: MediaSource.local),
      MediaEntry(path: file.path, title: 'Second', source: MediaSource.local),
    ]);
    // Native diagnostics must not block normal end-of-file queue progression.
    // ignore: invalid_use_of_protected_member
    native.errorController.add('Video output initialization warning');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 4)),
    );
    expect(playback.index, 1);
    await playback.player.pause();
    final pausedAt = playback.player.state.position;
    // A nonfatal diagnostic must not turn resume into reopening from zero.
    // ignore: invalid_use_of_protected_member
    native.errorController.add('Video output initialization warning');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await playback.toggle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    expect(playback.player.state.position, greaterThanOrEqualTo(pausedAt));
  });
}
