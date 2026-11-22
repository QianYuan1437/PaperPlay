import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../app_state.dart';

class DesktopService with WindowListener, TrayListener {
  DesktopService(this.app);
  final AppState app;
  bool trayReady = false;
  bool _quitting = false;
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
    if (!trayReady || _quitting) return Future.value();
    final playing = app.playback.playing;
    final title = app.playback.current?.title ?? '你的私人影音库';
    if (_requestedPlaying == playing && _requestedTitle == title) {
      return _indicatorUpdates;
    }
    _requestedPlaying = playing;
    _requestedTitle = title;
    _indicatorUpdates = _indicatorUpdates
        .then((_) async {
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
    app.playback.removeListener(_onPlaybackChanged);
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    await _indicatorUpdates;
    if (trayReady) {
      await trayManager.destroy();
      trayReady = false;
    }
  }

  Future<void> show() async {
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

  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    await app.save();
    await app.store.flush();
    await dispose();
    await app.playback.shutdown();
    await windowManager.destroy();
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
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
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

  static const options = WindowOptions(
    size: Size(1280, 840),
    minimumSize: Size(900, 650),
    center: true,
    title: 'PaperPlay',
    titleBarStyle: TitleBarStyle.hidden,
  );
}
