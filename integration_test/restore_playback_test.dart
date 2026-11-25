import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:paperplay/app_state.dart';
import 'package:paperplay/models/media_entry.dart';
import 'package:paperplay/services/library_store.dart';
import 'package:paperplay/services/playback_controller.dart';
import 'package:paperplay/ui/player_view.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('restored queue starts from the video surface before the bar', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    final directory = await Directory.systemTemp.createTemp(
      'paperplay-restore-',
    );
    final store = LibraryStore(File('${directory.path}/library.json'));
    final media = File(
      const String.fromEnvironment(
        'TEST_MEDIA',
        defaultValue: 'test/fixtures/sample.mp4',
      ),
    ).absolute;
    final entry = MediaEntry(
      path: media.path,
      title: '恢复的视频',
      source: MediaSource.local,
    );
    await store.save({
      'queue': [entry.toJson()],
      'audioOnly': false,
    });
    final playback = PlaybackController();
    final app = AppState(store, playback);
    await app.initialize();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await playback.shutdown();
      await store.flush();
      app.dispose();
      await directory.delete(recursive: true);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: Center(child: PlayerView(playback: playback)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await (playback.player.platform as NativePlayer).setProperty('ao', 'null');
    expect(playback.player.state.playlist.medias, isEmpty);
    final restoreButton = find.byKey(const ValueKey('load-restored-video'));
    if (restoreButton.evaluate().isNotEmpty) {
      await tester.tap(restoreButton);
    } else {
      // Exercise the original media_kit control as the red reproduction.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(Video)));
      await tester.pump(const Duration(milliseconds: 200));
      final control = find.byType(MaterialDesktopPlayOrPauseButton);
      await tester.tap(control);
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 900)),
    );
    await tester.pumpAndSettle();
    expect(
      playback.player.state.playlist.medias,
      isNotEmpty,
      reason:
          'The video play button must load the restored file, not toggle an empty native player',
    );
    expect(playback.player.state.duration, greaterThan(Duration.zero));
    expect(playback.player.state.position, greaterThan(Duration.zero));
    expect(playback.playing, isTrue);
    await playback.toggle();
    expect(playback.playing, isFalse);
  });
}
