import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:paperplay/app_state.dart';
import 'package:paperplay/models/media_entry.dart';
import 'package:paperplay/models/queue_order.dart';
import 'package:paperplay/models/video_loading.dart';
import 'package:paperplay/services/library_store.dart';
import 'package:paperplay/services/performance_monitor.dart';
import 'package:paperplay/services/playback_controller.dart';

class _Player implements Player {
  @override
  PlayerState get state => PlayerState();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Playback extends ChangeNotifier implements PlaybackController {
  @override
  VideoLoading loadingMode = VideoLoading.memory;
  @override
  int videoCacheMiB = 256;
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store extends LibraryStore {
  _Store(this.data) : super(File('unused.json'));
  Map<String, dynamic> data;
  @override
  Future<Map<String, dynamic>> load() async => data;
  @override
  Future<void> save(Map<String, dynamic> value) async {
    data = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'saved opt-out makes no reads; enabled stats run without a page or visible window',
    (tester) async {
      var reads = 0;
      final store = _Store({'performanceEnabled': false, 'sampleSeconds': 1});
      final playback = _Playback();
      final monitor = PerformanceMonitor(
        read: () async => ProcessCounters(
          (++reads).toDouble(),
          reads * 100,
          4,
          100,
          200,
          reads * 100,
        ),
      );
      final app = AppState(store, playback, performance: monitor);
      await app.initialize();
      await tester.pump(const Duration(seconds: 3));
      expect(reads, 0);
      app.performanceEnabled = true;
      app.changed();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(monitor.samples, hasLength(1));
      app.windowVisible.value = false;
      await tester.pump(const Duration(seconds: 1));
      expect(monitor.samples, hasLength(2));
      final original = monitor.samples.first;
      app.blurPreviews = true;
      app.changed();
      expect(monitor.samples.first, same(original));
      expect(store.data['performanceEnabled'], isTrue);
      app.performanceEnabled = false;
      app.changed();
      final stopped = reads;
      await tester.pump(const Duration(seconds: 3));
      expect(reads, stopped);
      expect(store.data['performanceEnabled'], isFalse);
      app.dispose();
      playback.dispose();
    },
  );
}
