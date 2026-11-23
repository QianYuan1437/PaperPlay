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
import 'package:paperplay/services/desktop_service.dart';
import 'package:paperplay/services/library_store.dart';
import 'package:paperplay/services/playback_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'stationary blur control remains visually stable during native audio playback',
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
        updates: UpdateService(fetch: () async => {'tag_name': 'v1.0.2'}),
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
      app.blurPreviews = true;
      app.changed();
      await windowManager.setSize(const Size(1040, 700));
      await playback.setAudioOnly(true);
      await playback.play([first, second], asAudio: true);
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(BlurToggle));
      Future<int> controlPixels() async {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final picture = await boundary.toImage(pixelRatio: 1);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawImageRect(
          picture,
          rect,
          Rect.fromLTWH(0, 0, rect.width, rect.height),
          Paint(),
        );
        final drawing = recorder.endRecording();
        final cropped = await drawing.toImage(
          rect.width.ceil(),
          rect.height.ceil(),
        );
        final bytes = await cropped.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final result = Object.hashAll(bytes!.buffer.asUint8List());
        picture.dispose();
        drawing.dispose();
        cropped.dispose();
        return result;
      }

      await tester.pump(const Duration(seconds: 1));
      final baseline = await controlPixels();
      var changedFrames = 0;
      for (var frame = 0; frame < 90; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        if (await controlPixels() != baseline) changedFrames++;
      }
      expect(
        changedFrames,
        0,
        reason:
            'Blur control changed during audio-only playback without pointer interaction',
      );
      await playback.player.pause();
      await tester.pumpAndSettle();
      final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
      app.favorite(first);
      await tester.pumpAndSettle();
      expect(
        identical(
          theme,
          tester.widget<MaterialApp>(find.byType(MaterialApp)).theme,
        ),
        isTrue,
        reason: 'A library favorite must not recreate the application theme',
      );
      app.accent = 0xFF2563EB;
      app.changed();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .theme!
            .colorScheme
            .primary,
        isNot(theme!.colorScheme.primary),
        reason: 'Explicit accent changes must still apply',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await desktop.dispose();
      await playback.shutdown();
      await app.store.flush();
      await temporary.delete(recursive: true);
    },
  );
}
