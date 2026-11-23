import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/ui/playback_timeline.dart';

class _PaintCounter extends CustomPainter {
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) {
    paints++;
  }

  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}

void main() {
  testWidgets(
    'seek feedback accepts engine acknowledgement and recovers from an unsupported seek',
    (tester) async {
      final positions = StreamController<Duration>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaybackTimeline(
              positionStream: positions.stream,
              durationStream: const Stream.empty(),
              initialPosition: const Duration(seconds: 10),
              initialDuration: const Duration(seconds: 100),
              onSeek: (_) {},
            ),
          ),
        ),
      );
      tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(60000);
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).value, 60000);
      positions.add(const Duration(seconds: 60));
      await tester.pump();
      positions.add(const Duration(seconds: 62));
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).value, 62000);
      tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(90000);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.widget<Slider>(find.byType(Slider)).value, 62000);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(positions.close());
      await tester.pump();
    },
  );

  testWidgets(
    'drag previews locally, ignores stale positions and seeks once on release',
    (tester) async {
      final positions = StreamController<Duration>();
      final seeks = <Duration>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaybackTimeline(
              positionStream: positions.stream,
              durationStream: const Stream.empty(),
              initialPosition: const Duration(seconds: 10),
              initialDuration: const Duration(seconds: 100),
              onSeek: seeks.add,
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(Slider));
      final gesture = await tester.startGesture(
        Offset(rect.left + 50, rect.center.dy),
      );
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(15, 0));
        await tester.pump();
      }
      final dragged = tester.widget<Slider>(find.byType(Slider)).value;
      positions.add(const Duration(seconds: 2));
      await tester.pump();
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        dragged,
        reason:
            'Incoming playback positions must not pull the dragged thumb back',
      );
      await gesture.up();
      await tester.pump();
      expect(
        seeks,
        hasLength(1),
        reason: 'One drag must submit one native seek',
      );
      expect(seeks.single.inMilliseconds, closeTo(dragged, 1));
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(positions.close());
      await tester.pump();
    },
  );

  testWidgets('position ticks do not repaint the surrounding page', (
    tester,
  ) async {
    final positions = StreamController<Duration>();
    final counter = _PaintCounter();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomPaint(
            painter: counter,
            child: PlaybackTimeline(
              positionStream: positions.stream,
              durationStream: const Stream.empty(),
              initialPosition: Duration.zero,
              initialDuration: const Duration(seconds: 100),
              onSeek: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final baseline = counter.paints;
    for (var i = 1; i <= 20; i++) {
      positions.add(Duration(milliseconds: i * 200));
      await tester.pump();
    }
    expect(
      counter.paints - baseline,
      0,
      reason: 'Timeline repaints should stay inside the playback controls',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(positions.close());
    await tester.pump();
  });
}
