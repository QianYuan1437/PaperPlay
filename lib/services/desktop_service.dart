import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../app_state.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'window_layout.dart';

class DesktopService with WindowListener, TrayListener {
  DesktopService(this.app);
  final AppState app;
  bool trayReady = false;
  bool _quitting = false;
  bool _disposed = false;
  bool? displayedPlaying;
  bool? _requestedPlaying;
  String? _requestedTitle;
  Future<void> _indicatorUpdates = Future.value();
  Future<void> initialize() async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    try {
      await trayManager.setIcon('assets/tray.ico');
      await trayManager.setToolTip('PaperPlay · 你的私人影音库');
      trayManager.addListener(this);
      trayReady = true;
      await syncPlaybackIndicator();
      app.playback.addListener(_onPlaybackChanged);
    } catch (e) {
      app.message = '托盘初始化失败，将保留任务栏窗口：$e';
    }
  }

  void _onPlaybackChanged() {
    unawaited(syncPlaybackIndicator());
  }

  Future<void> syncPlaybackIndicator() {
    if (!trayReady || _quitting || _disposed) return Future.value();
    final playing = app.playback.playing;
    final title = app.playback.current?.title ?? '你的私人影音库';
    if (_requestedPlaying == playing && _requestedTitle == title) {
      return _indicatorUpdates;
    }
    _requestedPlaying = playing;
    _requestedTitle = title;
    _indicatorUpdates = _indicatorUpdates
        .then((_) async {
          if (_quitting || _disposed) return;
          final icon = playing ? 'assets/tray_playing.ico' : 'assets/tray.ico';
          await trayManager.setIcon(icon);
          await windowManager.setIcon(icon);
          await trayManager.setToolTip(
            'PaperPlay · ${playing ? '正在播放' : '已暂停'} · $title',
          );
          await trayManager.setContextMenu(
            Menu(
              items: [
                MenuItem(key: 'show', label: '显示 PaperPlay'),
                MenuItem.separator(),
                MenuItem(key: 'toggle', label: playing ? '暂停' : '播放'),
                MenuItem(key: 'previous', label: '上一首'),
                MenuItem(key: 'next', label: '下一首'),
                MenuItem.separator(),
                MenuItem(key: 'quit', label: '退出 PaperPlay'),
              ],
            ),
          );
          displayedPlaying = playing;
        })
        .catchError((Object error) {
          _requestedPlaying = null;
          app.message = '状态图标更新失败：$error';
        });
    return _indicatorUpdates;
  }

  Future<void> dispose() async {
    _disposed = true;
    app.playback.removeListener(_onPlaybackChanged);
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    if (_quitting) {
      await _bestEffort(_indicatorUpdates, const Duration(milliseconds: 500));
    } else {
      await _indicatorUpdates;
    }
    if (trayReady) {
      await trayManager.destroy();
      trayReady = false;
    }
  }

  Future<void> show() async {
    if (_quitting || _disposed) return;
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    // The Windows plugin uses ShowWindowAsync; wait for the visibility change.
    for (var attempt = 0; attempt < 20; attempt++) {
      if (await windowManager.isVisible()) break;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    await windowManager.focus();
  }

  Future<void> hide() async {
    if (trayReady) {
      await windowManager.hide();
    } else {
      await windowManager.minimize();
    }
  }

  Future<void> _bestEffort(
    Future<void> task, [
    Duration limit = const Duration(seconds: 2),
  ]) async {
    try {
      await task.timeout(limit);
    } catch (_) {
      // A native cleanup failure must not keep the desktop window alive.
    }
  }

  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    await _bestEffort(windowManager.hide());
    await _bestEffort(dispose());
    app.playback.onPersist = null;
    try {
      // Snapshot before disposing the native player; keep disk writes intact.
      final saved = app.save();
      final cleanup = _bestEffort(app.playback.shutdown());
      await saved;
      await app.store.flush();
      await cleanup;
    } finally {
      await windowManager.destroy();
    }
  }

  @override
  void onWindowClose() {
    unawaited(app.closeToTray && trayReady ? hide() : quit());
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(show());
  }

  @override
  void onTrayIconRightMouseDown() {
    if (_quitting || _disposed) return;
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (_quitting) return;
    switch (menuItem.key) {
      case 'show':
        unawaited(show());
      case 'toggle':
        unawaited(app.playback.toggle());
      case 'previous':
        unawaited(app.playback.previous());
      case 'next':
        unawaited(app.playback.next());
      case 'quit':
        unawaited(quit());
    }
  }

  static Future<WindowOptions> windowOptions() async {
    var area = const Size(1100, 750);
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      area = display.visibleSize ?? display.size;
    } catch (_) {
      // A compact fallback is also safe when display enumeration is unavailable.
    }
    final size = initialWindowSize(area);
    return WindowOptions(
      size: size,
      minimumSize: Size(
        size.width < 800 ? size.width : 800,
        size.height < 560 ? size.height : 560,
      ),
      center: true,
      title: 'PaperPlay',
      titleBarStyle: TitleBarStyle.hidden,
    );
  }
}
