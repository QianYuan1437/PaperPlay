import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Hover controls stay mounted and cannot disappear while a pointer is down.
/// No parent pan recognizer competes with the timeline's horizontal drag.
class VideoControlsSurface extends StatefulWidget {
  const VideoControlsSurface({
    super.key,
    required this.child,
    required this.shortcuts,
    required this.onFullscreen,
    required this.onVolumeScroll,
  });
  final Widget child;
  final Map<ShortcutActivator, VoidCallback> shortcuts;
  final VoidCallback onFullscreen;
  final ValueChanged<double> onVolumeScroll;

  @override
  State<VideoControlsSurface> createState() => _VideoControlsSurfaceState();
}

class _VideoControlsSurfaceState extends State<VideoControlsSurface> {
  final _pointers = <int>{};
  Timer? _hideTimer;
  bool _visible = false, _inside = false;

  void _show() {
    if (!_visible) setState(() => _visible = true);
    _hideTimer?.cancel();
    if (_pointers.isEmpty) {
      _hideTimer = Timer(const Duration(seconds: 3), _hide);
    }
  }

  void _hide() {
    if (mounted && _pointers.isEmpty && _visible) {
      setState(() => _visible = false);
    }
  }

  void _release(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_inside) {
      _show();
    } else {
      _hide();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: widget.shortcuts,
    child: Focus(
      autofocus: true,
      child: MouseRegion(
        onEnter: (_) {
          _inside = true;
          _show();
        },
        onHover: (_) => _show(),
        onExit: (_) {
          _inside = false;
          _hide();
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            _pointers.add(event.pointer);
            _show();
          },
          onPointerMove: (_) => _show(),
          onPointerUp: _release,
          onPointerCancel: _release,
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              widget.onVolumeScroll(event.scrollDelta.dy);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: widget.onFullscreen,
              ),
              AnimatedOpacity(
                key: const ValueKey('video-controls-opacity'),
                opacity: _visible ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                child: IgnorePointer(
                  ignoring: !_visible,
                  child: ExcludeFocus(
                    excluding: !_visible,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.55, 1],
                                colors: [Colors.transparent, Color(0xB3000000)],
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Material(
                            color: Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: widget.child,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
