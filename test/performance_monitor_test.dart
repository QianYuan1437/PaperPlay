import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/services/performance_monitor.dart';

void main() {
  test('CPU is normalized across cores, memory and I/O use real deltas', () {
    const before = ProcessCounters(10, 0, 8, 0, 0, 0);
    const now = ProcessCounters(12, 80000000, 8, 104857600, 209715200, 4194304);
    final sample = ResourceSample.between(before, now);
    expect(sample.cpu, 50);
    expect(sample.memoryMiB, 100);
    expect(sample.privateMiB, 200);
    expect(sample.ioMiB, 2);
  });
  test('history is bounded and visibility resets the time baseline', () async {
    var reads = 0;
    final monitor = PerformanceMonitor(
      read: () async {
        reads++;
        return ProcessCounters(
          reads.toDouble(),
          reads * 1000000,
          4,
          100,
          200,
          reads * 100,
        );
      },
    );
    monitor.configure(active: true, interval: 5);
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 70; i++) {
      await monitor.sample();
    }
    expect(monitor.samples, hasLength(60));
    monitor.configure(active: false, interval: 5);
    final pausedReads = reads;
    await monitor.sample();
    expect(reads, pausedReads);
    monitor.configure(active: true, interval: 5);
    await Future<void>.delayed(Duration.zero);
    expect(monitor.samples, isEmpty);
    await monitor.sample();
    expect(monitor.samples.single.cpu, 2.5);
    monitor.dispose();
  });
  test('late native results cannot notify after dispose or overlap', () async {
    final pending = Completer<ProcessCounters>();
    var reads = 0, notifications = 0;
    final monitor = PerformanceMonitor(
      read: () {
        reads++;
        return pending.future;
      },
    );
    monitor.addListener(() => notifications++);
    monitor.configure(active: true, interval: 2);
    await monitor.sample();
    expect(reads, 1);
    monitor.dispose();
    pending.complete(const ProcessCounters(1, 0, 4, 100, 200, 0));
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 0);
  });
  test(
    'failed counters report unavailable rather than inserting fake zeros',
    () async {
      final monitor = PerformanceMonitor(
        read: () async => throw StateError('unavailable'),
      );
      monitor.configure(active: true, interval: 2);
      await Future<void>.delayed(Duration.zero);
      expect(monitor.error, isNotNull);
      expect(monitor.samples, isEmpty);
      monitor.dispose();
    },
  );
}
