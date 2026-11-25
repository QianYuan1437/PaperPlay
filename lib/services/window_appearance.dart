import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import '../app_state.dart';
import 'performance_monitor.dart';

class WindowAppearance {
  static Future<void>? _initialized;
  Future<void> _pending = Future.value();
  Object? _requested;
  bool disposed = false;
  Future<void> apply(AppState app) {
    final dark =
        app.themeMode == ThemeMode.dark ||
        (app.themeMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
    final key = (app.windowEffect, dark);
    if (_requested == key) return _pending;
    _requested = key;
    _pending = _pending.then((_) async {
      if (disposed || _requested != key) return;
      try {
        // Leave the default compositor untouched until effects are requested.
        if (app.windowEffect == 'solid' && _initialized == null) return;
        _initialized ??= acrylic.Window.initialize();
        await _initialized;
        final capabilities = await PerformanceMonitor.channel
            .invokeMapMethod<String, dynamic>('effects');
        var effect = app.windowEffect;
        String? message;
        if ((effect == 'acrylic' || effect == 'mica') &&
            capabilities?[effect] != true) {
          message =
              '${effect == 'mica' ? '云母需要 Windows 11' : '亚克力需要 Windows 10 1803 或更新版本'}，已使用纯色';
          effect = 'solid';
        }
        await PerformanceMonitor.channel.invokeMethod<void>('resetBackdrop');
        await acrylic.Window.setEffect(
          effect: switch (effect) {
            'transparent' => acrylic.WindowEffect.transparent,
            'acrylic' => acrylic.WindowEffect.acrylic,
            'mica' => acrylic.WindowEffect.mica,
            _ => acrylic.WindowEffect.solid,
          },
          dark: dark,
          color: (dark ? const Color(0xFF17171F) : const Color(0xFFF7F7FB))
              .withValues(
                alpha: effect == 'solid'
                    ? 1
                    : effect == 'transparent'
                    ? 0
                    : 0.3,
              ),
        );
        if (!disposed && _requested == key) {
          app.appearanceApplied(
            translucent: effect != 'solid',
            message: message,
          );
        }
      } catch (_) {
        if (!disposed && _requested == key) {
          app.appearanceApplied(translucent: false, message: '窗口效果不可用，已使用纯色');
        }
      }
    });
    return _pending;
  }
}
