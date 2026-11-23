import 'dart:async';
import 'package:flutter/material.dart';
import 'widgets.dart';

/// Playback ticks and drag feedback are painted locally. A drag commits a single
/// seek, so native operations cannot queue up behind every pointer movement.
class PlaybackTimeline extends StatefulWidget {
  const PlaybackTimeline({
    super.key,
    required this.positionStream,
    required this.durationStream,
    required this.initialPosition,
    required this.initialDuration,
    required this.onSeek,
  });
  final Stream<Duration> positionStream, durationStream;
  final Duration initialPosition, initialDuration;
  final ValueChanged<Duration> onSeek;
  @override
  State<PlaybackTimeline> createState() => _PlaybackTimelineState();
}

class _PlaybackTimelineState extends State<PlaybackTimeline> {
  late Duration _position, _duration;
  StreamSubscription<Duration>? _positions, _durations;
  Timer? _seekTimeout;
  double? _dragValue, _pendingSeek;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _duration = widget.initialDuration;
    _subscribe();
  }

  void _subscribe() {
    _positions = widget.positionStream.listen((value) {
      if (!mounted || (value == _position && _pendingSeek == null)) return;
      setState(() {
        _position = value;
        if (_pendingSeek != null &&
            (value.inMilliseconds - _pendingSeek!).abs() <= 1000) {
          _pendingSeek = null;
          _seekTimeout?.cancel();
        }
      });
    });
    _durations = widget.durationStream.listen((value) {
      if (!mounted || value == _duration) return;
      setState(() => _duration = value);
    });
  }

  @override
  void didUpdateWidget(PlaybackTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.positionStream != oldWidget.positionStream ||
        widget.durationStream != oldWidget.durationStream) {
      _positions?.cancel();
      _durations?.cancel();
      _position = widget.initialPosition;
      _duration = widget.initialDuration;
      _dragValue = _pendingSeek = null;
      _seekTimeout?.cancel();
      _subscribe();
    }
  }

  void _seek(double value) {
    setState(() {
      _dragValue = null;
      _pendingSeek = value;
    });
    _seekTimeout?.cancel();
    // Unsupported seeks must not leave the thumb frozen indefinitely.
    _seekTimeout = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _pendingSeek = null);
    });
    widget.onSeek(Duration(milliseconds: value.round()));
  }

  @override
  void dispose() {
    _positions?.cancel();
    _durations?.cancel();
    _seekTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final max = _duration.inMilliseconds.toDouble();
    final value =
        (_dragValue ?? _pendingSeek ?? _position.inMilliseconds.toDouble())
            .clamp(0.0, max > 0 ? max : 1.0);
    final textSize = MediaQuery.textScalerOf(context).scale(11);
    final timeWidth = clockLabel(_duration).length * textSize + 4;
    return SizedBox(
      width: double.infinity,
      height: (textSize * 1.6).clamp(24.0, double.infinity),
      child: RepaintBoundary(
        child: Row(
          children: [
            SizedBox(
              width: timeWidth,
              child: Text(
                clockLabel(Duration(milliseconds: value.round())),
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 18,
                child: Slider(
                  value: value,
                  max: max > 0 ? max : 1,
                  onChangeStart: max <= 0
                      ? null
                      : (value) => setState(() => _dragValue = value),
                  onChanged: max <= 0
                      ? null
                      : (value) => setState(() => _dragValue = value),
                  onChangeEnd: max <= 0 ? null : _seek,
                ),
              ),
            ),
            SizedBox(
              width: timeWidth,
              child: Text(
                clockLabel(_duration),
                textAlign: TextAlign.end,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
