import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:paperplay/app_state.dart';
import 'package:paperplay/models/media_entry.dart';
import 'package:paperplay/models/video_loading.dart';
import 'package:paperplay/services/library_store.dart';
import 'package:paperplay/services/playback_controller.dart';
import 'package:paperplay/ui/player_view.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bounded loading, seeks, audio recovery and translucent bar', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('paperplay-loading-');
    final store = LibraryStore(File('${dir.path}/library.json'));
    await store.save({
      'performanceEnabled': false,
      'videoLoading': 'disk',
      'videoCacheMiB': 128,
    });
    final playback = PlaybackController();
    final app = AppState(store, playback);
    await app.initialize();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await playback.shutdown();
      await store.flush();
      app.dispose();
      await dir.delete(recursive: true);
    });
    expect(playback.loadingMode, VideoLoading.disk);
    expect(playback.videoCacheMiB, 128);
    app.translucentWindow = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(child: PlayerView(playback: playback)),
              PlaybackBar(app: app, openPlayer: () {}),
            ],
          ),
        ),
      ),
    );
    final bar = tester.widget<Container>(
      find.byKey(const ValueKey('playback-bar-surface')),
    );
    expect((bar.decoration as BoxDecoration).color, Colors.transparent);
    final native = playback.player.platform as NativePlayer;
    await native.setProperty('ao', 'null');
    final file = File(
      const String.fromEnvironment(
        'LARGE_MEDIA',
        defaultValue: 'docs/media/tide.mp4',
      ),
    ).absolute;
    final media = MediaEntry(
      path: file.path,
      title: 'Large media regression',
      source: MediaSource.local,
    );
    final baselineRss = ProcessInfo.currentRss;
    final timings = <String, List<int>>{};
    for (final mode in VideoLoading.values) {
      await playback.setLoading(mode, cacheMiB: 128);
      await playback.play([media]);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 700)),
      );
      expect(await native.getProperty('cache-on-disk'), 'no');
      expect(
        await native.getProperty('demuxer-max-bytes'),
        '${(mode == VideoLoading.memory ? 96 : 8) * 1048576}',
      );
      final duration = playback.player.state.duration;
      expect(duration, greaterThan(Duration.zero));
      final times = <int>[];
      for (final ratio in [0.8, 0.1, 0.6, 0.2]) {
        final target = duration * ratio;
        final watch = Stopwatch()..start();
        // A burst must finish at the latest requested target.
        await Future.wait([
          playback.seek(duration * 0.3),
          playback.seek(duration * 0.5),
          playback.seek(target),
        ]);
        await tester.runAsync(() async {
          while (watch.elapsed < const Duration(seconds: 5)) {
            final p = playback.player.state.position;
            if ((p - target).abs() < const Duration(milliseconds: 900) &&
                await native.getProperty('seeking') == 'no') {
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 25));
          }
        });
        times.add(watch.elapsedMilliseconds);
        expect(
          (playback.player.state.position - target).abs(),
          lessThan(const Duration(seconds: 2)),
        );
        expect(
          await native.getProperty('video-out-params/pixelformat'),
          isNotEmpty,
        );
        await tester.pump();
      }
      timings[mode.name] = times;
      await playback.setAudioOnly(true);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      final watch = Stopwatch()..start();
      await playback.setAudioOnly(false);
      await tester.runAsync(() async {
        while (watch.elapsed < const Duration(seconds: 5) &&
            (await native.getProperty(
              'video-out-params/pixelformat',
            )).isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      timings['${mode.name}-audio-to-video'] = [watch.elapsedMilliseconds];
      expect(
        await native.getProperty('video-out-params/pixelformat'),
        isNotEmpty,
      );
      expect(playback.playing, isTrue);
      final cache =
          jsonDecode(await native.getProperty('demuxer-cache-state')) as Map;
      final packets =
          (cache['fw-bytes'] as num? ?? 0) + (cache['bw-bytes'] as num? ?? 0);
      expect(packets, lessThan(160 * 1048576));
    }
    await app.save();
    final saved = await store.load();
    expect(saved['videoLoading'], 'memory');
    expect(saved['videoCacheMiB'], 128);
    final rssGrowth = ProcessInfo.currentRss - baselineRss;
    final peakGrowth = ProcessInfo.maxRss - baselineRss;
    if (await file.length() > 500 * 1000 * 1000) {
      expect(
        peakGrowth,
        lessThan(500 * 1048576),
        reason: 'Loading must not allocate the whole large file',
      );
    }
    // ignore: avoid_print
    print(
      'File bytes: ${await file.length()}; seek/restore ms: $timings; RSS growth MiB: ${rssGrowth ~/ 1048576}',
    );
    expect(tester.takeException(), isNull);
  });
}
