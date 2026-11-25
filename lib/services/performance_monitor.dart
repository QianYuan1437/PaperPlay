import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ProcessCounters {
  const ProcessCounters(
    this.seconds,
    this.cpuTicks,
    this.processors,
    this.workingSet,
    this.privateBytes,
    this.ioBytes,
  );
  factory ProcessCounters.fromMap(Map<dynamic, dynamic> data) =>
      ProcessCounters(
        (data['seconds'] as num).toDouble(),
        data['cpuTicks'] as int,
        data['processors'] as int,
        data['workingSet'] as int,
        data['privateBytes'] as int,
        data['ioBytes'] as int,
      );
  final double seconds;
  final int cpuTicks, processors, workingSet, privateBytes, ioBytes;
}

class ResourceSample {
  const ResourceSample(this.cpu, this.memoryMiB, this.privateMiB, this.ioMiB);
  factory ResourceSample.between(ProcessCounters before, ProcessCounters now) {
    final elapsed = now.seconds - before.seconds;
    return ResourceSample(
      elapsed <= 0
          ? 0
          : ((now.cpuTicks - before.cpuTicks) /
                    1e7 /
                    elapsed /
                    math.max(1, now.processors) *
                    100)
                .clamp(0, 100),
      now.workingSet / 1048576,
      now.privateBytes / 1048576,
      elapsed <= 0
          ? 0
          : math.max(0, now.ioBytes - before.ioBytes) / elapsed / 1048576,
    );
  }
  final double cpu, memoryMiB, privateMiB, ioMiB;
}

/// Samples only while the page is mounted and the desktop window is visible.
/// Counters use monotonic native time; a paused interval never becomes a spike.
class PerformanceMonitor extends ChangeNotifier {
  PerformanceMonitor({Future<ProcessCounters> Function()? read})
    : _read = read ?? readNative;
  static const channel = MethodChannel('paperplay/metrics');
  static Future<ProcessCounters> readNative() async => ProcessCounters.fromMap(
    (await channel.invokeMapMethod<dynamic, dynamic>('sample'))!,
  );
  final Future<ProcessCounters> Function() _read;
  final List<ResourceSample> samples = [];
  Timer? _timer;
  ProcessCounters? _previous;
  int _generation = 0;
  bool _reading = false;
  bool _active = false;
  int _interval = 2;
  String? error;
  void configure({required bool active, required int interval}) {
    if (_active == active && _interval == interval) return;
    _active = active;
    _interval = interval;
    _generation++;
    _timer?.cancel();
    _previous = null;
    samples.clear();
    if (active) {
      unawaited(sample());
      _timer = Timer.periodic(Duration(seconds: interval), (_) => sample());
    }
  }

  Future<void> sample() async {
    if (!_active || _reading) return;
    _reading = true;
    final generation = _generation;
    try {
      final now = await _read();
      if (generation != _generation) return;
      error = null;
      if (_previous != null) {
        samples.add(ResourceSample.between(_previous!, now));
        if (samples.length > 60) samples.removeAt(0);
      }
      _previous = now;
      notifyListeners();
    } catch (_) {
      if (generation != _generation) return;
      error = '暂时无法读取进程统计';
      _previous = null;
      notifyListeners();
    } finally {
      _reading = false;
    }
  }

  @override
  void dispose() {
    _active = false;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
