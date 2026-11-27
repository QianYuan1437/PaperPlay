import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/media_entry.dart';
import '../models/queue_order.dart';
import '../models/video_loading.dart';
import 'playback_diagnostics.dart';

class PlaybackController extends ChangeNotifier {
  PlaybackController() {
    _diagnostics = PlaybackDiagnostics(
      probe: _decodeProbe,
      onError: (value) {
        if (_closing || error == value) return;
        error = value;
        notifyListeners();
      },
    );
    video = VideoController(player);
    _subscriptions.add(
      player.stream.completed.listen((done) {
        if (done && !_opening) unawaited(next(manual: false));
      }),
    );
    _subscriptions.add(player.stream.playing.listen((_) => notifyListeners()));
    _subscriptions.add(
      player.stream.tracks.listen((_) {
        if (audioOnly || backgroundVideoSuppressed) {
          unawaited(
            _serial(() async {
              if (_loaded) await _applyVideoPolicy();
            }),
          );
        }
      }),
    );
    _subscriptions.add(
      player.stream.error.listen((message) {
        if (current != null && !_closing) _diagnostics.report(message);
      }),
    );
    _subscriptions.add(
      player.stream.position.listen((_) => _diagnostics.progress()),
    );
  }
  late final PlaybackDiagnostics _diagnostics;
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
  bool backgroundVideoSuppressed = false;
  bool get videoDisabled => audioOnly || backgroundVideoSuppressed;
  bool _resumeAfterSuppression = false;
  bool _opening = false;
  bool _loaded = false;
  bool _closing = false;
  VideoLoading loadingMode = VideoLoading.memory;
  int videoCacheMiB = 256;
  int _mediaGeneration = 0;
  int _seekRevision = 0;
  bool _loadingConfigured = false;
  Future<void>? _shutdown;
  String? error;
  VoidCallback? onPersist;
  Future<void> _pending = Future.value();
  MediaEntry? get current =>
      queue.isEmpty ? null : queue[index.clamp(0, queue.length - 1)];
  bool get playing => player.state.playing;
  bool get mediaLoaded => _loaded;
  bool get opening => _opening;

  Future<DecodeProbe> _decodeProbe() async {
    final native = player.platform;
    Future<String?> property(String name) async {
      if (native is! NativePlayer) return null;
      try {
        return await native.getProperty(name);
      } catch (_) {
        return null;
      }
    }

    final needsVideo = !videoDisabled && current?.isAudio == false;
    final hasAudio = player.state.tracks.audio.any(
      (track) => track.id != 'auto' && track.id != 'no',
    );
    final videoPts = needsVideo
        ? double.tryParse(await property('estimated-frame-number') ?? '')
        : null;
    final audioFormat = hasAudio ? await property('audio-params/format') : null;
    return DecodeProbe(
      position: player.state.position,
      needsVideo: needsVideo,
      videoPosition:
          (await property('video-out-params/pixelformat'))?.isNotEmpty == true
          ? videoPts
          : null,
      audioReady: !hasAudio || (audioFormat != null && audioFormat.isNotEmpty),
    );
  }

  Future<void> _serial(Future<void> Function() action) {
    if (_closing) return Future.value();
    final task = _pending.then((_) async {
      if (_closing) return;
      try {
        await action();
      } catch (e) {
        _diagnostics.reset();
        error = '播放失败：$e';
      }
      if (!_closing) notifyListeners();
    });
    _pending = task.catchError((Object _) {});
    return task;
  }

  void _changed() {
    if (_closing) return;
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
    _mediaGeneration++;
    _seekRevision++;
    _opening = true;
    _loaded = false;
    _resumeAfterSuppression = false;
    _diagnostics.reset();
    notifyListeners();
    try {
      // A broken/moved file cannot cause an endless repeat-one retry loop.
      for (var attempt = 0; attempt < queue.length; attempt++) {
        final item = current!;
        if (await File(item.path).exists()) {
          // A skipped missing entry must not leave its error on the next file.
          _diagnostics.reset();
          // Probe with video available, while paused. Opening a silent video
          // with vid=no makes mpv report EOF and incorrectly skip the queue.
          if (!_loadingConfigured) await _configureLoading();
          // Stop first: re-enabling video on the outgoing audio-only file
          // would initialize its decoder just before throwing it away.
          if (player.state.track.video.id == 'no') {
            await player.stop();
            await player.setVideoTrack(VideoTrack.auto());
          }
          await player.open(Media(item.path), play: false);
          _loaded = true;
          if (videoDisabled) {
            // open() returns before mpv publishes track metadata. Wait for the
            // first actual track list so play()/jump() finish in the correct
            // audio-playing or silent-paused state, rather than racing the UI.
            bool known(Tracks tracks) => [
              ...tracks.audio,
              ...tracks.video,
            ].any((track) => track.id != 'auto' && track.id != 'no');
            if (!known(player.state.tracks)) {
              final ready = Completer<void>();
              final subscription = player.stream.tracks.listen((tracks) {
                if (known(tracks) && !ready.isCompleted) ready.complete();
              });
              try {
                await ready.future.timeout(
                  const Duration(seconds: 3),
                  onTimeout: () {},
                );
              } finally {
                await subscription.cancel();
              }
            }
            _resumeAfterSuppression = true;
            await _applyVideoPolicy();
          } else {
            await player.play();
          }
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
      if (videoDisabled) await _applyVideoPolicy();
    }
  });

  Future<void> setLoading(VideoLoading value, {int? cacheMiB}) =>
      _serial(() async {
        loadingMode = value;
        if ([128, 256, 512].contains(cacheMiB)) videoCacheMiB = cacheMiB!;
        await _configureLoading();
        _changed();
      });

  Future<void> _configureLoading() async {
    final native = player.platform;
    if (native is NativePlayer) {
      for (final entry in videoLoadingProperties(
        loadingMode,
        videoCacheMiB,
      ).entries) {
        await native.setProperty(entry.key, entry.value);
      }
    }
    _loadingConfigured = true;
  }

  /// Both timelines and keyboard shortcuts share the media command queue.
  /// Drop superseded seeks and never apply an old drag to a newly opened file.
  Future<void> seek(Duration position) {
    final generation = _mediaGeneration;
    final revision = ++_seekRevision;
    return _serial(() async {
      if (!_loaded ||
          generation != _mediaGeneration ||
          revision != _seekRevision) {
        return;
      }
      final duration = player.state.duration;
      if (duration <= Duration.zero) return;
      final target = Duration(
        milliseconds: position.inMilliseconds.clamp(0, duration.inMilliseconds),
      );
      await player.seek(target);
    });
  }

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
    if (audioOnly == value) return;
    audioOnly = value;
    notifyListeners();
    if (_loaded) {
      await _applyVideoPolicy();
    }
    _changed();
  });
  Future<void> setBackgroundVideoSuppressed(bool value) => _serial(() async {
    if (backgroundVideoSuppressed == value) return;
    backgroundVideoSuppressed = value;
    if (_loaded) {
      await _applyVideoPolicy();
    }
  });

  Future<void> _applyVideoPolicy() async {
    final hasAudio = player.state.tracks.audio.any(
      (track) => track.id != 'auto' && track.id != 'no',
    );
    if (videoDisabled && !hasAudio) {
      _resumeAfterSuppression |= playing;
      await player.pause();
      // Keep the silent file loaded and paused, with no continuous decoding.
      // Tracks may still be loading; the tracks listener reapplies this policy.
      return;
    }
    final currentlyDisabled = player.state.track.video.id == 'no';
    if (currentlyDisabled != videoDisabled) {
      await player.setVideoTrack(
        videoDisabled ? VideoTrack.no() : VideoTrack.auto(),
      );
    }
    if (_resumeAfterSuppression) {
      _resumeAfterSuppression = false;
      await player.play();
    }
  }

  void setMode(PlayMode value) {
    mode = value;
    _changed();
  }

  Future<void> enqueue(List<MediaEntry> items) => _serial(() async {
    queue.addAll(items);
    _changed();
  });
  Future<void> clear() => _serial(() async {
    _mediaGeneration++;
    _resumeAfterSuppression = false;
    await player.stop();
    queue.clear();
    _history.clear();
    index = 0;
    _loaded = false;
    _diagnostics.reset();
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
      _diagnostics.reset();
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
  Future<void> shutdown() => _shutdown ??= _shutdownOnce();

  Future<void> _shutdownOnce() async {
    _closing = true;
    _diagnostics.dispose();
    onPersist = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _pending;
    await player.dispose();
    super.dispose();
  }
}
