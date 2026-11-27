import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:paperplay/models/media_entry.dart';
import 'package:paperplay/services/playback_controller.dart';
import 'package:paperplay/ui/player_view.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('unblurred texture resize, next and rapid seeks remain live', (
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
    final paths = [
      'test/fixtures/sample.mp4',
      const String.fromEnvironment(
        'STRESS_MEDIA',
        defaultValue: 'docs/media/tide.mp4',
      ),
    ];
    await playback.play(
      paths
          .map(
            (path) => MediaEntry(
              path: File(path).absolute.path,
              title: path,
              source: MediaSource.local,
            ),
          )
          .toList(),
    );
    for (var round = 0; round < 60; round++) {
      await playback.next();
      await tester.pump();
      // Give Flutter's raster thread time to read the changing DXGI surface.
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 16)),
        );
      }
      final pending = <Future<void>>[];
      for (var seek = 0; seek < 12; seek++) {
        pending.add(
          playback.seek(Duration(milliseconds: 500 + (seek % 3) * 500)),
        );
      }
      await Future.wait(pending);
      await tester.pump();
      expect(playback.playing, isTrue, reason: 'stopped in round $round');
      expect(playback.player.state.videoParams.w, greaterThan(0));
    }
    // A drag issued for the outgoing file must not seek the next file.
    await Future.wait([
      playback.jump(0),
      playback.seek(const Duration(seconds: 3)),
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    expect(
      playback.player.state.position,
      lessThan(const Duration(seconds: 2)),
    );
    final before = playback.player.state.position;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 700)),
    );
    expect(playback.player.state.position, greaterThan(before));
    expect(tester.takeException(), isNull);
  });
}
