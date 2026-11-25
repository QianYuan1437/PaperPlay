import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:paperplay/services/update_service.dart';
import 'package:paperplay/ui/blur_toggle.dart';
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
      final report = FlutterError.onError;
      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details, forceReport: true);
        report?.call(details);
      };
      addTearDown(() => FlutterError.onError = report);
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
        updates: UpdateService(fetch: () async => {'tag_name': 'v1.0.8'}),
      );
      await app.initialize();
      app.autoScan = false;
      final desktop = DesktopService(app);
      await desktop.initialize();
      await windowManager.setSize(const Size(1280, 900));
      await windowManager.show();
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: PaperPlayApp(app: app, desktop: desktop),
        ),
      );
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
      app.subscriptions = List.generate(
        24,
        (i) => MediaEntry(
          path: p.join(temporary.path, 'preview-$i.mp4'),
          title: '预览 ${i + 1}',
          source: MediaSource.wallpaper,
        ),
      );
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
      await playback.setAudioOnly(false);
      for (final size in [
        const Size(1040, 700),
        const Size(900, 650),
        const Size(800, 560),
      ]) {
        await windowManager.setSize(size);
        await tester.pumpAndSettle();
        for (final label in ['订阅库', '播放队列', '播放器', '本地媒体', '设置', '概览']) {
          await tester.ensureVisible(find.text(label).first);
          await tester.tap(find.text(label).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$label at $size');
          expect(find.byType(BlurToggle), findsWidgets);
          if (label == '播放队列' && size.width == 1040) {
            expect(
              tester.getCenter(find.text('保存列表')).dy,
              closeTo(tester.getCenter(find.text('清空队列')).dy, 2),
            );
          }
          if (label == '播放器') {
            final toolbar = find.byKey(const ValueKey('player-toolbar'));
            final audio = find.descendant(
              of: toolbar,
              matching: find.text('纯音频'),
            );
            final tray = find.descendant(
              of: toolbar,
              matching: find.text('收起到托盘'),
            );
            expect(
              tester.getCenter(audio).dy,
              closeTo(tester.getCenter(tray).dy, 2),
            );
            expect(
              tester.getCenter(audio).dx,
              lessThan(tester.getCenter(tray).dx),
            );
          }
          if (label == '概览') {
            final cards = [
              for (var i = 1; i <= 4; i++)
                tester.getSize(find.byKey(ValueKey('overview-card-$i'))).height,
            ];
            expect(cards.toSet().length, 1);
            final preview = tester.getSize(
              find.byKey(const ValueKey('overview-video-frame')),
            );
            expect(preview.width / preview.height, closeTo(16 / 9, 0.01));
            expect(find.byType(BackdropFilter), findsWidgets);
            await tester.tap(find.byType(BlurToggle).first);
            await tester.pumpAndSettle();
            expect(find.byType(BackdropFilter), findsNothing);
            await tester.tap(find.byType(BlurToggle).first);
            await tester.pumpAndSettle();
            expect(find.byType(BackdropFilter), findsWidgets);
          }
          if (label == '设置' && size.width == 1040) {
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('settings-appearance')))
                  .height,
              tester
                  .getSize(find.byKey(const ValueKey('settings-updates')))
                  .height,
            );
            final audioSwitch = find.byKey(
              const ValueKey('settings-audio-only'),
            );
            await tester.ensureVisible(audioSwitch);
            await tester.tap(audioSwitch);
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 300)),
            );
            await tester.pumpAndSettle();
            expect(playback.audioOnly, isTrue);
            expect(playback.player.state.track.video.id, 'no');
            expect(find.byTooltip('切换到视频'), findsOneWidget);
            await tester.tap(find.byTooltip('切换到视频'));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 300)),
            );
            await tester.pumpAndSettle();
            expect(tester.widget<SwitchListTile>(audioSwitch).value, isFalse);
            expect(playback.player.state.track.video.id, isNot('no'));

            expect(
              tester
                  .getTopLeft(find.byKey(const ValueKey('settings-updates')))
                  .dx,
              greaterThan(
                tester
                    .getTopLeft(
                      find.byKey(const ValueKey('settings-appearance')),
                    )
                    .dx,
              ),
            );
          }
          if (size.width == 1040) {
            final folder = const String.fromEnvironment('SCREENSHOT_DIR');
            if (folder.isNotEmpty) {
              await Directory(folder).create(recursive: true);
              final boundary =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                p.join(folder, '$label.png'),
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            }
          }
        }
      }
      await tester.tap(find.byTooltip('播放').first);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(playback.playing, isTrue);
      await tester.tap(find.byTooltip('暂停').first);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(playback.playing, isFalse);
      await tester.tap(find.text('本地媒体').first);
      await tester.pumpAndSettle();
      expect(find.byType(BlurToggle), findsNWidgets(2));
      await tester.tap(find.byType(BlurToggle).last);
      await tester.pumpAndSettle();
      for (final toggle in find.byType(BlurToggle).evaluate()) {
        final chip = find.descendant(
          of: find.byWidget(toggle.widget),
          matching: find.byType(FilterChip),
        );
        expect(tester.widget<FilterChip>(chip).selected, isFalse);
      }
      await tester.tap(find.byType(BlurToggle).first);
      await tester.pumpAndSettle();
      expect(app.blurPreviews, isTrue);
      await tester.tap(find.byKey(const ValueKey('sidebar-version')));
      await tester.pumpAndSettle();
      expect(find.text('发现新版本 v1.0.8'), findsOneWidget);
      expect(find.text('查看并下载更新'), findsOneWidget);
      await tester.ensureVisible(find.text('关于 PaperPlay'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sidebar-version')));
      await tester.pumpAndSettle();
      expect(find.text('检查更新').hitTestable(), findsOneWidget);
      await tester.tap(find.byType(BlurToggle).first);
      await tester.pumpAndSettle();
      expect(app.blurPreviews, isFalse);
      await tester.tap(find.byType(BlurToggle).first);
      await tester.pumpAndSettle();
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
