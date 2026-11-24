import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../app_state.dart';
import '../app_info.dart';
import '../models/media_entry.dart';
import '../services/desktop_service.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'player_view.dart';
import 'queue_page.dart';
import 'settings_page.dart';
import 'widgets.dart';
import 'brand_icon.dart';
import 'blur_toggle.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.app, required this.desktop});
  final AppState app;
  final DesktopService desktop;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  int settingsVisit = 0;
  void go(int value) => setState(() => index = value);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.app,
    builder: (context, _) {
      final app = widget.app;
      final colors = Theme.of(context).colorScheme;
      final body = switch (index) {
        0 => HomePage(app: app, go: go),
        1 => LibraryPage(
          key: const ValueKey('wallpaper'),
          app: app,
          source: MediaSource.wallpaper,
          openPlayer: () => go(3),
        ),
        2 => QueuePage(app: app),
        3 => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListenableBuilder(
                listenable: app.playback,
                builder: (context, _) => Row(
                  key: const ValueKey('player-toolbar'),
                  children: [
                    Expanded(
                      child: Text(
                        app.playback.current?.title ?? '选择视频开始播放',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('纯音频'),
                      selected: app.playback.audioOnly,
                      avatar: const Icon(Icons.headphones_rounded, size: 18),
                      onSelected: app.playback.setAudioOnly,
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: widget.desktop.hide,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                      label: const Text('收起到托盘'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(child: PlayerView(playback: app.playback, fill: true)),
            ],
          ),
        ),
        4 => LibraryPage(
          key: const ValueKey('local'),
          app: app,
          source: MediaSource.local,
          openPlayer: () => go(3),
        ),
        _ => SettingsPage(key: ValueKey(settingsVisit), app: app),
      };
      return Scaffold(
        body: Column(
          children: [
            SizedBox(
              height: 38,
              child: Row(
                children: [
                  Expanded(
                    child: DragToMoveArea(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Row(
                          children: [
                            BrandIcon(playback: app.playback, size: 23),
                            const SizedBox(width: 8),
                            const Text(
                              'PaperPlay',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: BlurToggle(app: app),
                  ),
                  IconButton(
                    tooltip: '收起到托盘',
                    iconSize: 18,
                    onPressed: widget.desktop.hide,
                    icon: const Icon(Icons.expand_more_rounded),
                  ),
                  SizedBox(
                    width: 138,
                    child: WindowCaption(
                      brightness: Theme.of(context).brightness,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
            if (app.busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Column(
                      children: [
                        if (MediaQuery.sizeOf(context).height >= 760) ...[
                          const SizedBox(height: 24),
                          BrandIcon(playback: app.playback, size: 44),
                          const SizedBox(height: 7),
                          Text(
                            'PAPERPLAY',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 28),
                        ] else
                          const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: SizedBox(
                              height: 400,
                              child: NavigationRail(
                                selectedIndex: index,
                                onDestinationSelected: go,
                                minWidth: 88,
                                groupAlignment: -1,
                                labelType: NavigationRailLabelType.all,
                                destinations: const [
                                  NavigationRailDestination(
                                    icon: Icon(Icons.grid_view_rounded),
                                    label: Text('概览'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.wallpaper_rounded),
                                    label: Text('订阅库'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.queue_music_rounded),
                                    label: Text('播放队列'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(
                                      Icons.play_circle_outline_rounded,
                                    ),
                                    label: Text('播放器'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.video_library_outlined),
                                    label: Text('本地媒体'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.tune_rounded),
                                    label: Text('设置'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextButton(
                            key: const ValueKey('sidebar-version'),
                            onPressed: () {
                              setState(() {
                                index = 5;
                                settingsVisit++;
                              });
                              app.updates.check();
                            },
                            child: const Text(
                              'v$appVersion',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        if (app.message != null)
                          Container(
                            margin: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    app.message!,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  tooltip: '关闭提示',
                                  onPressed: app.dismissMessage,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            PlaybackBar(app: app, openPlayer: () => go(3)),
          ],
        ),
      );
    },
  );
}
