import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:paperplay/services/update_service.dart';
import 'package:paperplay/ui/blur_toggle.dart';
import 'package:paperplay/ui/performance_page.dart';
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
import 'package:paperplay/services/performance_monitor.dart';

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
        updates: UpdateService(fetch: () async => {'tag_name': 'v1.0.10'}),
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
      await playback.setBackgroundVideoSuppressed(true);
      expect(playback.audioOnly, isFalse);
      expect(playback.player.state.track.video.id, 'no');
      await playback.setAudioOnly(true);
      await playback.setBackgroundVideoSuppressed(false);
      expect(playback.player.state.track.video.id, 'no');
      await playback.setAudioOnly(false);
      expect(playback.player.state.track.video.id, isNot('no'));
      final counters = await PerformanceMonitor.readNative();
      expect(counters.workingSet, greaterThan(0));
      expect(counters.cpuTicks, greaterThan(0));
      await desktop.hide();
      await playback.setAudioOnly(
        false,
      ); // Wait for the serialized visibility update.
      expect(playback.backgroundVideoSuppressed, isTrue);
      expect(playback.player.state.track.video.id, 'no');
      await desktop.show();
      await playback.setAudioOnly(false);
      expect(playback.backgroundVideoSuppressed, isFalse);
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
      expect(
        app.performance.samples,
        isNotEmpty,
        reason: 'Statistics must start before the Performance page is opened',
      );
      for (final size in [
        const Size(1040, 700),
        const Size(900, 650),
        const Size(800, 560),
      ]) {
        await windowManager.setSize(size);
        await tester.pumpAndSettle();
        for (final label in ['订阅库', '播放队列', '播放器', '本地媒体', '设置', '性能', '概览']) {
          final recentSample = app.performance.samples.last;
          await tester.ensureVisible(find.text(label).first);
          await tester.tap(find.text(label).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$label at $size');
          expect(find.byType(BlurToggle), findsWidgets);
          final globalAudio = find.byKey(const ValueKey('global-audio-toggle'));
          expect(globalAudio, findsOneWidget);
          expect(
            tester.getCenter(globalAudio).dx,
            lessThan(tester.getCenter(find.byType(BlurToggle).first).dx),
          );
          if (label == '性能') {
            expect(find.text('GPU'), findsOneWidget);
            expect(find.text('占整机总算力'), findsNothing);
            expect(find.textContaining('私有提交'), findsNothing);
            expect(find.text('读写速率'), findsNothing);
            expect(
              app.performance.samples,
              contains(recentSample),
              reason: 'Opening the page must preserve existing samples',
            );
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 6200)),
            );
            await tester.pumpAndSettle();
            expect(find.text('CPU'), findsOneWidget);
            expect(find.text('内存'), findsOneWidget);
            expect(find.text('进程 I/O'), findsOneWidget);
            expect(find.text('暂时无法读取进程统计'), findsNothing);
            final gpuValues = app.performance.samples
                .map((s) => s.gpu)
                .whereType<double>()
                .toList();
            if (const bool.fromEnvironment('EXPECT_GPU_STATS')) {
              expect(
                gpuValues,
                isNotEmpty,
                reason: 'Physical GPU must provide process counters',
              );
              expect(
                gpuValues.every((value) => value >= 0 && value <= 100),
                isTrue,
              );
            }
            debugPrint('GPU process samples: $gpuValues');
          }
          if (label == '播放队列' && size.width == 1040) {
            expect(
              tester.getCenter(find.text('保存列表')).dy,
              closeTo(tester.getCenter(find.text('清空队列')).dy, 2),
            );
          }
          if (label == '播放器') {
            final toolbar = find.byKey(const ValueKey('player-toolbar'));
            expect(
              find.descendant(of: toolbar, matching: find.text('纯音频')),
              findsNothing,
            );
            final title = find.byKey(const ValueKey('playback-title-link'));
            expect(
              tester.getCenter(title).dy,
              closeTo(tester.getCenter(find.byTooltip('播放').first).dy, 2),
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
            await tester.pumpAndSettle();
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
      expect(find.text('发现新版本 v1.0.10'), findsOneWidget);
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
      await tester.ensureVisible(find.text('性能').first);
      await tester.tap(find.text('性能').first);
      await tester.pumpAndSettle();
      for (final link in ['playback-artwork-link', 'playback-title-link']) {
        await tester.tap(find.byKey(ValueKey(link)));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('player-toolbar')), findsOneWidget);
        await tester.ensureVisible(find.text('性能').first);
        await tester.tap(find.text('性能').first);
        await tester.pumpAndSettle();
      }
      final statistics = find.byKey(const ValueKey('performance-enabled'));
      await tester.scrollUntilVisible(
        statistics,
        180,
        scrollable: find
            .descendant(
              of: find.byType(PerformancePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(statistics);
      await tester.pumpAndSettle();
      expect(app.performanceEnabled, isFalse);
      expect(app.performance.samples, isEmpty);
      final backgroundSwitch = find.widgetWithText(SwitchListTile, '后台停止视频解码');
      await tester.ensureVisible(backgroundSwitch);
      await tester.pumpAndSettle();
      await tester.tap(backgroundSwitch);
      await tester.pumpAndSettle();
      expect(app.suspendVideoInBackground, isFalse);
      await tester.ensureVisible(find.text('设置').first);
      await tester.tap(find.text('设置').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(backgroundSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(statistics).value, isFalse);
      await tester.ensureVisible(statistics);
      await tester.pumpAndSettle();
      await tester.tap(statistics);
      await tester.pumpAndSettle();
      expect(app.performanceEnabled, isTrue);
      await tester.ensureVisible(backgroundSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(backgroundSwitch).value, isFalse);
      await tester.tap(backgroundSwitch);
      await tester.pumpAndSettle();
      expect(app.suspendVideoInBackground, isTrue);
      final capabilities = await PerformanceMonitor.channel
          .invokeMapMethod<String, dynamic>('effects');
      for (final effect in [
        'transparent',
        'acrylic',
        'mica',
        'transparent',
        'solid',
      ]) {
        app.windowEffect = effect;
        app.changed();
        await desktop.syncAppearance();
        await tester.pumpAndSettle();
        final supported =
            effect == 'transparent' || capabilities?[effect] == true;
        expect(app.translucentWindow, supported);
        final native = await PerformanceMonitor.channel
            .invokeMapMethod<String, dynamic>('effects');
        if (native?['backdropType'] != null) {
          expect(native!['backdropType'], switch (effect) {
            'acrylic' => 3,
            'mica' => 2,
            _ => 1,
          });
        }
        expect(tester.takeException(), isNull);
      }
      app.previewCacheMiB = 32;
      app.sampleSeconds = 5;
      app.reduceMotion = true;
      app.changed();
      expect(
        PaintingBinding.instance.imageCache.maximumSizeBytes,
        32 * 1048576,
      );
      await app.save();
      expect((await app.store.load())['queue'], hasLength(2));
      expect((await app.store.load())['blurPreviews'], isTrue);
      final saved = await app.store.load();
      expect(saved['sampleSeconds'], 5);
      expect(saved['performanceEnabled'], isTrue);
      expect(saved['previewCacheMiB'], 32);
      expect(saved['reduceMotion'], isTrue);
      expect(saved['suspendVideoInBackground'], isTrue);
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
