import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/services/performance_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native GPU baseline resets only on a new sampling session', () async {
    final resets = <bool>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(PerformanceMonitor.channel, (
      call,
    ) async {
      resets.add(call.arguments as bool);
      return {
        'seconds': resets.length,
        'cpuTicks': 0,
        'processors': 4,
        'workingSet': 100,
        'privateBytes': 100,
        'ioBytes': 0,
        'gpu': 12.5,
      };
    });
    final monitor = PerformanceMonitor();
    addTearDown(() {
      monitor.dispose();
      messenger.setMockMethodCallHandler(PerformanceMonitor.channel, null);
    });
    monitor.configure(active: true, interval: 5);
    await Future<void>.delayed(Duration.zero);
    await monitor.sample();
    expect(monitor.samples.single.gpu, 12.5);
    monitor.configure(active: false, interval: 5);
    await monitor.sample();
    monitor.configure(active: true, interval: 5);
    await Future<void>.delayed(Duration.zero);
    await monitor.sample();
    expect(resets, [true, false, true, false]);
  });
  test(
    'GPU readings preserve unavailable samples and bound valid percentages',
    () {
      const before = ProcessCounters(1, 0, 4, 0, 0, 0);
      ProcessCounters counters(Object? gpu) => ProcessCounters.fromMap({
        'seconds': 2,
        'cpuTicks': 100,
        'processors': 4,
        'workingSet': 100,
        'privateBytes': 200,
        'ioBytes': 100,
        'gpu': gpu,
      });
      expect(ResourceSample.between(before, counters(23.5)).gpu, 23.5);
      expect(ResourceSample.between(before, counters(0)).gpu, 0);
      expect(ResourceSample.between(before, counters(null)).gpu, isNull);
      expect(ResourceSample.between(before, counters(double.nan)).gpu, isNull);
      expect(ResourceSample.between(before, counters(130)).gpu, 100);
      expect(ResourceSample.between(before, counters(-1)).gpu, 0);
    },
  );
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
