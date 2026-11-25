import 'dart:async';

/// Decode evidence, rather than a log severity, determines whether playback
/// recovered. Audio progress alone cannot prove that video is working.
class DecodeProbe {
  const DecodeProbe({
    required this.position,
    required this.needsVideo,
    required this.audioReady,
    this.videoPosition,
  });
  final Duration position;
  final bool needsVideo, audioReady;
  final double? videoPosition;

  bool progressedFrom(DecodeProbe before) =>
      audioReady &&
      position > before.position &&
      (!needsVideo ||
          (videoPosition != null &&
              (before.videoPosition == null ||
                  videoPosition != before.videoPosition)));
}

class PlaybackDiagnostics {
  PlaybackDiagnostics({required this.probe, required this.onError});
  final Future<DecodeProbe> Function() probe;
  final void Function(String?) onError;
  Timer? _timer;
  DecodeProbe? _previous;
  String? _pending;
  int _generation = 0;
  bool _reading = false;
  bool _disposed = false;

  void report(String message) {
    if (_disposed) return;
    // Other failures (missing files, demuxing, output devices) remain visible.
    if (!RegExp(
      r'codec|decoder|decoding',
      caseSensitive: false,
    ).hasMatch(message)) {
      reset();
      onError(message);
      return;
    }
    if (_pending != null) {
      return; // Repeated diagnostics must not postpone checks.
    }
    _pending = message;
    _previous = null;
    unawaited(_check(initial: true));
  }

  void progress() {
    if (_disposed || _pending == null || _timer != null || _reading) return;
    _timer = Timer(const Duration(milliseconds: 600), () {
      _timer = null;
      unawaited(_check());
    });
  }

  Future<void> _check({bool initial = false}) async {
    if (_disposed || _pending == null || _reading) return;
    _reading = true;
    final generation = _generation;
    try {
      final now = await probe();
      if (_disposed || generation != _generation) return;
      if (_previous != null && now.progressedFrom(_previous!)) {
        _pending = null;
        _timer?.cancel();
        _timer = null;
        onError(null);
      } else {
        _previous = now;
        if (!initial) onError(_pending);
      }
    } catch (_) {
      if (!_disposed && generation == _generation && !initial) {
        onError(_pending);
      }
    } finally {
      _reading = false;
      // Always check once even when decoding failed and no position events fire.
      if (!_disposed && generation == _generation && initial) progress();
      if (!_disposed && generation != _generation && _pending != null) {
        unawaited(_check(initial: true));
      }
    }
  }

  void reset() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _previous = null;
    if (!_disposed) onError(null);
  }

  void dispose() {
    _disposed = true;
    reset();
  }
}
