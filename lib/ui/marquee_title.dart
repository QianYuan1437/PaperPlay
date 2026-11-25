import 'dart:async';
import 'package:flutter/material.dart';

/// Animate only overflowing titles; keep layout and the rest of the bar static.
class MarqueeTitle extends StatefulWidget {
  const MarqueeTitle({super.key, required this.text, this.active = true});
  final String text;
  final bool active;
  @override
  State<MarqueeTitle> createState() => _MarqueeTitleState();
}

class _MarqueeTitleState extends State<MarqueeTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scroll = AnimationController(vsync: this);
  Timer? _delay;
  Object? _configuration;
  @override
  void dispose() {
    _delay?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(
      context,
    ).style.copyWith(fontWeight: FontWeight.w600);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final animate =
        widget.active &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: direction,
          textScaler: scaler,
        )..layout();
        final width = painter.width;
        final height = painter.height;
        painter.dispose();
        final overflow = width > constraints.maxWidth;
        final run = overflow && animate;
        final configuration = (widget.text, constraints.maxWidth, width, run);
        if (_configuration != configuration) {
          _configuration = configuration;
          _delay?.cancel();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _configuration != configuration) return;
            _scroll.stop();
            _scroll.value = 0;
            if (run) {
              _delay = Timer(const Duration(seconds: 1), () {
                if (!mounted || _configuration != configuration) return;
                _scroll.repeat(
                  period: Duration(
                    milliseconds: ((width + 32) / 28 * 1000).round(),
                  ),
                );
              });
            }
          });
        }
        if (!run) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        }
        return Semantics(
          label: widget.text,
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: ClipRect(
                child: SizedBox(
                  height: height,
                  child: AnimatedBuilder(
                    animation: _scroll,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.text, maxLines: 1, style: style),
                        const SizedBox(width: 32),
                        Text(widget.text, maxLines: 1, style: style),
                      ],
                    ),
                    builder: (context, child) => OverflowBox(
                      alignment: AlignmentDirectional.centerStart,
                      maxWidth: double.infinity,
                      child: Transform.translate(
                        key: const ValueKey('title-scroll-offset'),
                        offset: Offset(
                          (direction == TextDirection.rtl ? 1 : -1) *
                              _scroll.value *
                              (width + 32),
                          0,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
