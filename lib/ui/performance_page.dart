import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_state.dart';
import 'performance_options.dart';
import 'widgets.dart';

class PerformancePage extends StatelessWidget {
  const PerformancePage({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) => ListTileTheme(
    data: ListTileTheme.of(context).copyWith(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      minTileHeight: 52,
      minVerticalPadding: 8,
      visualDensity: VisualDensity.standard,
    ),
    child: PageFrame(
      title: '性能',
      subtitle: '',
      children: [
        ListenableBuilder(
          listenable: app.performance,
          builder: (context, _) => Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 760 ? 4 : 2;
                  final width =
                      (constraints.maxWidth - 12 * (columns - 1)) / columns;
                  final samples = app.performance.samples;
                  final latest = samples.lastOrNull;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(
                        width: width,
                        title: 'CPU',
                        icon: Icons.speed_rounded,
                        value: latest == null
                            ? '—'
                            : '${latest.cpu.toStringAsFixed(1)}%',
                        values: samples.map((s) => s.cpu).toList(),
                        ceiling: 100,
                      ),
                      _MetricCard(
                        width: width,
                        title: 'GPU',
                        icon: Icons.developer_board_rounded,
                        value: latest?.gpu == null
                            ? '—'
                            : '${latest!.gpu!.toStringAsFixed(1)}%',
                        values: samples.map((s) => s.gpu).toList(),
                        ceiling: 100,
                      ),
                      _MetricCard(
                        width: width,
                        title: '内存',
                        icon: Icons.memory_rounded,
                        value: latest == null
                            ? '—'
                            : '${latest.memoryMiB.toStringAsFixed(0)} MB',
                        values: samples.map((s) => s.memoryMiB).toList(),
                      ),
                      _MetricCard(
                        width: width,
                        title: '进程 I/O',
                        icon: Icons.swap_vert_rounded,
                        value: latest == null
                            ? '—'
                            : '${latest.ioMiB.toStringAsFixed(2)} MB/s',
                        values: samples.map((s) => s.ioMiB).toList(),
                      ),
                    ],
                  );
                },
              ),
              if (!app.performanceEnabled || app.performance.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    app.performanceEnabled ? app.performance.error! : '性能统计已关闭',
                  ),
                ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final performance = SectionCard(
              title: '性能配置',
              icon: Icons.tune_rounded,
              child: PerformanceOptions(app: app),
            );
            final appearance = SectionCard(
              title: '外观与动效',
              icon: Icons.blur_on_rounded,
              child: AppearanceOptions(app: app),
            );
            if (constraints.maxWidth < 760) {
              return Column(
                children: [performance, const SizedBox(height: 12), appearance],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: performance),
                  const SizedBox(width: 12),
                  Expanded(child: appearance),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.title,
    required this.icon,
    required this.value,
    required this.values,
    this.ceiling,
  });
  final double width;
  final String title, value;
  final IconData icon;
  final List<double?> values;
  final double? ceiling;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: SectionCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 18),
          RepaintBoundary(
            child: SizedBox(
              height: 84,
              width: double.infinity,
              child: CustomPaint(
                painter: _CurvePainter(
                  values,
                  Theme.of(context).colorScheme.primary,
                  ceiling,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CurvePainter extends CustomPainter {
  _CurvePainter(this.values, this.color, this.ceiling);
  final List<double?> values;
  final Color color;
  final double? ceiling;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = 2 + (size.height - 4) * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final valid = values.whereType<double>().toList();
    if (valid.isEmpty) return;
    final maximum = ceiling ?? math.max(1.0, valid.reduce(math.max) * 1.15);
    Offset point(int i) => Offset(
      size.width * i / math.max(1, values.length - 1),
      size.height - 2 - (values[i]! / maximum).clamp(0, 1) * (size.height - 4),
    );
    // Missing GPU counters leave a gap rather than fabricating a zero reading.
    var start = 0;
    while (start < values.length) {
      if (values[start] == null) {
        start++;
        continue;
      }
      var end = start;
      while (end + 1 < values.length && values[end + 1] != null) {
        end++;
      }
      final first = point(start);
      if (end == start) {
        canvas.drawCircle(first, 2, Paint()..color = color);
        start++;
        continue;
      }
      final path = Path()..moveTo(first.dx, first.dy);
      for (var i = start + 1; i <= end; i++) {
        final a = point(i - 1), b = point(i);
        final mid = (a.dx + b.dx) / 2;
        path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
      }
      final fill = Path.from(path)
        ..lineTo(point(end).dx, size.height)
        ..lineTo(first.dx, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.01),
            ],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      start = end + 1;
    }
  }

  @override
  bool shouldRepaint(_CurvePainter oldDelegate) => true;
}
