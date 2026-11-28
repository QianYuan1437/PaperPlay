import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:paperplay/app_state.dart';
import 'package:paperplay/models/media_entry.dart';
import 'package:paperplay/models/queue_order.dart';
import 'package:paperplay/models/video_loading.dart';
import 'package:paperplay/services/desktop_service.dart';
import 'package:paperplay/services/library_store.dart';
import 'package:paperplay/services/playback_controller.dart';

class _Player implements Player {
  @override
  PlayerState get state => PlayerState();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Playback extends ChangeNotifier implements PlaybackController {
  @override
  final Player player = _Player();
  @override
  VoidCallback? onPersist;
  @override
  final List<MediaEntry> queue = [];
  @override
  int index = 0;
  @override
  PlayMode mode = PlayMode.repeatAll;
  @override
  bool audioOnly = false;
  @override
  VideoLoading loadingMode = VideoLoading.memory;
  @override
  int videoCacheMiB = 256;
  @override
  bool playing = false;
  @override
  bool get videoDisabled => audioOnly;
  @override
  MediaEntry? get current => queue.isEmpty ? null : queue[index];
  @override
  Future<void> setBackgroundVideoSuppressed(bool value) async {}
  void update() => notifyListeners();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store extends LibraryStore {
  _Store() : super(File('unused.json'));
  Map<String, dynamic> data = {'performanceEnabled': false};
  @override
  Future<Map<String, dynamic>> load() async => data;
  @override
  Future<void> save(Map<String, dynamic> value) async => data = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('privacy hides shell names across settings, tracks and restart', (
    tester,
  ) async {
    final tips = <String>[];
    final captions = <String>[];
    for (final name in [
      'window_manager',
      'tray_manager',
      'paperplay/metrics',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async {
            if (call.method == 'setToolTip') {
              tips.add(call.arguments['toolTip'] as String);
            }
            if (call.method == 'setTitle') {
              captions.add(call.arguments['title'] as String);
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(name), null);
      });
    }
    final store = _Store();
    var playback = _Playback();
    var app = AppState(store, playback);
    await app.initialize();
    expect(app.privacyMode, isFalse);
    playback.queue.addAll([
      const MediaEntry(
        path: 'private.mp4',
        title: '私密视频',
        source: MediaSource.local,
      ),
      const MediaEntry(
        path: 'private.mp3',
        title: '私密音频',
        source: MediaSource.local,
      ),
    ]);
    var desktop = DesktopService(app);
    await desktop.initialize();
    expect(tips.last, contains('私密视频'));
    app.privacyMode = true;
    app.changed();
    await tester.pump();
    expect(tips.last, 'PaperPlay · 已暂停');
    tips.clear();
    desktop.onWindowMinimize();
    playback.index = 1;
    playback.audioOnly = true;
    playback.playing = true;
    playback.update();
    await desktop.syncPlaybackIndicator();
    expect(tips.last, 'PaperPlay · 正在播放');
    expect(tips.every((tip) => !tip.contains('私密')), isTrue);
    expect(captions, everyElement('PaperPlay'));
    await app.save();
    await desktop.dispose();
    app.dispose();
    playback.dispose();

    tips.clear();
    playback = _Playback();
    app = AppState(store, playback);
    await app.initialize();
    expect(app.privacyMode, isTrue);
    expect(playback.current!.title, '私密音频');
    desktop = DesktopService(app);
    await desktop.initialize();
    expect(tips.every((tip) => !tip.contains('私密')), isTrue);
    app.privacyMode = false;
    app.changed();
    await tester.pump();
    expect(tips.last, contains('私密音频'));
    // An older queued update must not restore a title after opting in.
    playback.index = 0;
    playback.update();
    app.privacyMode = true;
    app.changed();
    tips.clear();
    await desktop.syncPlaybackIndicator();
    expect(tips.last, 'PaperPlay · 已暂停');
    expect(tips.every((tip) => !tip.contains('私密')), isTrue);
    await desktop.dispose();
    app.dispose();
    playback.dispose();
  });
}
