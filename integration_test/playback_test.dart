import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';
import 'package:paperplay/app_state.dart';
import 'package:paperplay/main.dart';
import 'package:paperplay/models/media_entry.dart';
import 'package:paperplay/models/queue_order.dart';
import 'package:paperplay/services/desktop_service.dart';
import 'package:paperplay/services/library_store.dart';
import 'package:paperplay/services/playback_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'Windows native playback, audio-only, queue, tray and responsive shell',
    (tester) async {
      MediaKit.ensureInitialized();
      await windowManager.ensureInitialized();
      final temporary = await Directory.systemTemp.createTemp(
        'paperplay-native-',
      );
      final media = File(
        const String.fromEnvironment(
          'TEST_MEDIA',
          defaultValue: 'test/fixtures/sample.mp4',
        ),
      ).absolute;
      expect(
        await media.exists(),
        isTrue,
        reason: 'Pass --dart-define=TEST_MEDIA=<absolute path>',
      );
      final playback = PlaybackController();
      final app = AppState(
        LibraryStore(File(p.join(temporary.path, 'library.json'))),
        playback,
      );
      await app.initialize();
      app.autoScan = false;
      final desktop = DesktopService(app);
      await desktop.initialize();
      await windowManager.setSize(const Size(1280, 900));
      await windowManager.show();
      await tester.pumpWidget(PaperPlayApp(app: app, desktop: desktop));
      await tester.pumpAndSettle();
      await app.initializePlayback();
      // Hosted Windows runners have no physical audio device. Decode audio into
      // mpv's clocked null sink; keep real audio output for local desktop checks.
      if (const bool.fromEnvironment('HEADLESS_AUDIO')) {
        await (playback.player.platform as NativePlayer).setProperty(
          'ao',
          'null',
        );
      }
      await playback.player.setVolume(0);
      expect(tester.takeException(), isNull);
      final first = MediaEntry(
        path: media.path,
        title: '测试视频 A',
        source: MediaSource.local,
      );
      final second = MediaEntry(
        path: media.path,
        title: '测试视频 B',
        source: MediaSource.local,
      );
      app.local = [first];
      app.blurPreviews = true;
      app.changed();
      playback.setMode(PlayMode.sequential);
      await playback.play([first, second]);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      });
      expect(playback.player.state.duration, greaterThan(Duration.zero));
      expect(playback.player.state.position, greaterThan(Duration.zero));
      await playback.player.pause();
      await playback.setAudioOnly(true);
      expect(playback.player.state.track.video.id, 'no');
      await playback.setAudioOnly(false);
      expect(playback.player.state.track.video.id, isNot('no'));
      await playback.jump(1);
      await playback.player.pause();
      await playback.reorder(1, 0);
      expect(playback.index, 0);
      expect(playback.current!.title, '测试视频 B');
      // Completion advances, and sequential playback stops at the final item.
      await playback.jump(0);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 4));
      });
      expect(playback.index, 1);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 4));
      });
      expect(playback.playing, isFalse);
      await playback.setAudioOnly(true);
      playback.setMode(PlayMode.repeatOne);
      await playback.jump(0);
      expect(desktop.trayReady, isTrue);
      await desktop.syncPlaybackIndicator();
      expect(desktop.displayedPlaying, isTrue);
      await desktop.hide();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      });
      expect(await windowManager.isVisible(), isFalse);
      expect(playback.playing, isTrue);
      await desktop.show();
      expect(await windowManager.isVisible(), isTrue);
      await playback.player.pause();
      await desktop.syncPlaybackIndicator();
      expect(desktop.displayedPlaying, isFalse);
      for (final size in [const Size(1280, 900), const Size(900, 650)]) {
        await windowManager.setSize(size);
        await tester.pumpAndSettle();
        for (final label in ['订阅库', '播放队列', '播放器', '本地媒体', '设置', '概览']) {
          await tester.ensureVisible(find.text(label).first);
          await tester.tap(find.text(label).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$label at $size');
        }
      }
      await app.save();
      expect((await app.store.load())['queue'], hasLength(2));
      expect((await app.store.load())['blurPreviews'], isTrue);
      // Missing items are skipped with bounded retries, including repeat-one.
      final missing = MediaEntry(
        path: p.join(temporary.path, 'missing.mp4'),
        title: 'Missing',
        source: MediaSource.local,
      );
      await playback.play([missing, first]);
      expect(playback.index, 1);
      await playback.play([missing]);
      expect(playback.playing, isFalse);
      expect(playback.error, contains('均不可用'));
      await tester.pumpWidget(const SizedBox.shrink());
      await desktop.dispose();
      await playback.shutdown();
      await app.store.flush();
      await temporary.delete(recursive: true);
    },
  );
}
