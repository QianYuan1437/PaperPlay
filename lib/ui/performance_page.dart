import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/performance_monitor.dart';
import 'performance_options.dart';
import 'widgets.dart';

class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key, required this.app});
  final AppState app;
  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  final monitor = PerformanceMonitor();
  @override
  void initState() {
    super.initState();
    widget.app.addListener(_configure);
    widget.app.windowVisible.addListener(_configure);
    _configure();
  }

  void _configure() => monitor.configure(
    active: widget.app.windowVisible.value,
    interval: widget.app.sampleSeconds,
  );
  @override
  void dispose() {
    widget.app.removeListener(_configure);
    widget.app.windowVisible.removeListener(_configure);
    monitor.dispose();
    super.dispose();
  }

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
          listenable: monitor,
          builder: (context, _) => Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 24) / 3;
                  final samples = monitor.samples;
                  final latest = samples.lastOrNull;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetricCard(
                        width: width,
                        title: 'CPU',
                        icon: Icons.speed_rounded,
                        value: latest == null
                            ? '—'
                            : '${latest.cpu.toStringAsFixed(1)}%',
                        detail: '占整机总算力',
                        values: samples.map((s) => s.cpu).toList(),
                        ceiling: 100,
                      ),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: width,
                        title: '内存',
                        icon: Icons.memory_rounded,
                        value: latest == null
                            ? '—'
                            : '${latest.memoryMiB.toStringAsFixed(0)} MB',
                        detail: latest == null
                            ? '工作集'
                            : '私有提交 ${latest.privateMiB.toStringAsFixed(0)} MB',
                        values: samples.map((s) => s.memoryMiB).toList(),
                      ),
                      const SizedBox(width: 12),
                      _MetricCard(
                        width: width,
                        title: '进程 I/O',
                        icon: Icons.swap_vert_rounded,
                        value: latest == null
                            ? '—'
                            : '${latest.ioMiB.toStringAsFixed(2)} MB/s',
                        detail: '读写速率',
                        values: samples.map((s) => s.ioMiB).toList(),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  monitor.error ??
                      (monitor.samples.isEmpty
                          ? '正在采样…'
                          : '每 ${widget.app.sampleSeconds} 秒采样 · 最近 ${monitor.samples.length} 个点 · 仅统计 PaperPlay 进程'),
                  style: Theme.of(context).textTheme.bodySmall,
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
              child: PerformanceOptions(app: widget.app),
            );
            final appearance = SectionCard(
              title: '外观与动效',
              icon: Icons.blur_on_rounded,
              child: AppearanceOptions(app: widget.app),
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
    required this.detail,
    required this.values,
    this.ceiling,
  });
  final double width;
  final String title, value, detail;
  final IconData icon;
  final List<double> values;
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
          const SizedBox(height: 6),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
  final List<double> values;
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
    if (values.isEmpty) return;
    final maximum = ceiling ?? math.max(1.0, values.reduce(math.max) * 1.15);
    Offset point(int i) => Offset(
      size.width * i / math.max(1, values.length - 1),
      size.height - 2 - (values[i] / maximum).clamp(0, 1) * (size.height - 4),
    );
    final first = point(0);
    if (values.length == 1) {
      canvas.drawCircle(first, 2, Paint()..color = color);
      return;
    }
    final path = Path()..moveTo(first.dx, first.dy);
    for (var i = 1; i < values.length; i++) {
      final a = point(i - 1), b = point(i);
      final mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
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
  }

  @override
  bool shouldRepaint(_CurvePainter oldDelegate) => true;
}
