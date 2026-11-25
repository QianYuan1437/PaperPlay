import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/media_entry.dart';
import '../models/queue_order.dart';

class PlaybackController extends ChangeNotifier {
  PlaybackController() {
    video = VideoController(player);
    _subscriptions.add(
      player.stream.completed.listen((done) {
        if (done && !_opening) unawaited(next(manual: false));
      }),
    );
    _subscriptions.add(player.stream.playing.listen((_) => notifyListeners()));
    _subscriptions.add(
      player.stream.error.listen((message) {
        error = message;
        notifyListeners();
      }),
    );
  }
  final Player player = Player(
    configuration: const PlayerConfiguration(title: 'PaperPlay'),
  );
  late final VideoController video;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<MediaEntry> queue = [];
  final List<MediaEntry> _history = [];
  int index = 0;
  PlayMode mode = PlayMode.repeatAll;
  bool audioOnly = false;
  bool _opening = false;
  bool _loaded = false;
  String? error;
  VoidCallback? onPersist;
  Future<void> _pending = Future.value();
  MediaEntry? get current =>
      queue.isEmpty ? null : queue[index.clamp(0, queue.length - 1)];
  bool get playing => player.state.playing;
  bool get mediaLoaded => _loaded;
  bool get opening => _opening;

  Future<void> _serial(Future<void> Function() action) {
    final task = _pending.then((_) async {
      try {
        await action();
      } catch (e) {
        error = '播放失败：$e';
      }
      notifyListeners();
    });
    _pending = task.catchError((Object _) {});
    return task;
  }

  void _changed() {
    notifyListeners();
    onPersist?.call();
  }

  Future<void> play(List<MediaEntry> items, {int start = 0, bool? asAudio}) =>
      _serial(() async {
        if (items.isEmpty) return;
        queue
          ..clear()
          ..addAll(items);
        _history.clear();
        index = start.clamp(0, queue.length - 1);
        if (asAudio != null) audioOnly = asAudio;
        await _open();
        _changed();
      });

  Future<void> _open() async {
    _opening = true;
    _loaded = false;
    error = null;
    notifyListeners();
    try {
      // A broken/moved file cannot cause an endless repeat-one retry loop.
      for (var attempt = 0; attempt < queue.length; attempt++) {
        final item = current!;
        if (await File(item.path).exists()) {
          await player.open(Media(item.path), play: false);
          await player.setVideoTrack(
            audioOnly ? VideoTrack.no() : VideoTrack.auto(),
          );
          await player.play();
          _loaded = true;
          return;
        }
        error = '文件已移动或不可用：${item.title}';
        index = (index + 1) % queue.length;
      }
      await player.stop();
      error = '队列中的文件均不可用，请重新扫描或导入';
    } finally {
      _opening = false;
    }
  }

  Future<void> toggle() => _serial(() async {
    if (current == null) return;
    if (!_loaded) {
      await _open();
    } else {
      await player.playOrPause();
    }
  });

  Future<void> next({bool manual = true}) => _serial(() async {
    final next = nextIndex(
      current: index,
      length: queue.length,
      mode: mode,
      manual: manual,
    );
    if (next == null) {
      await player.pause();
      return;
    }
    if (current != null && next != index) {
      _history.add(current!);
      if (_history.length > 200) _history.removeAt(0);
    }
    index = next;
    await _open();
    _changed();
  });

  Future<void> previous() => _serial(() async {
    if (queue.isEmpty) return;
    var target = -1;
    while (_history.isNotEmpty && target == -1) {
      final item = _history.removeLast();
      target = queue.indexWhere((e) => e.id == item.id);
    }
    index = target >= 0 ? target : (index - 1 + queue.length) % queue.length;
    await _open();
    _changed();
  });

  Future<void> jump(int value) => _serial(() async {
    if (value < 0 || value >= queue.length) return;
    index = value;
    await _open();
    _changed();
  });
  Future<void> setAudioOnly(bool value) => _serial(() async {
    audioOnly = value;
    if (_loaded) {
      await player.setVideoTrack(value ? VideoTrack.no() : VideoTrack.auto());
    }
    _changed();
  });
  void setMode(PlayMode value) {
    mode = value;
    _changed();
  }

  Future<void> enqueue(List<MediaEntry> items) => _serial(() async {
    queue.addAll(items);
    _changed();
  });
  Future<void> clear() => _serial(() async {
    await player.stop();
    queue.clear();
    _history.clear();
    index = 0;
    _loaded = false;
    _changed();
  });
  Future<void> remove(int value) => _serial(() async {
    if (value < 0 || value >= queue.length) return;
    final wasCurrent = value == index;
    queue.removeAt(value);
    if (queue.isEmpty) {
      await player.stop();
      index = 0;
      _loaded = false;
    } else {
      if (value < index) index--;
      index = index.clamp(0, queue.length - 1);
      if (wasCurrent) await _open();
    }
    _changed();
  });
  Future<void> reorder(int from, int to) => _serial(() async {
    if (from < to) to--;
    final moved = queue.removeAt(from);
    queue.insert(to, moved);
    if (index == from) {
      index = to;
    } else if (from < index && to >= index) {
      index--;
    } else if (from > index && to <= index) {
      index++;
    }
    _changed();
  });
  Future<void> shutdown() async {
    await _pending;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await player.dispose();
    super.dispose();
  }
}
