import 'package:flutter/material.dart';
import '../app_state.dart';
import 'library_page.dart';
import 'player_view.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.app, required this.go});
  final AppState app;
  final ValueChanged<int> go;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PageFrame(
      title: '让收藏，重新流动。',
      subtitle: 'YOUR SPACE. YOUR PACE.  /  你的私人影音库',
      actions: [
        OutlinedButton.icon(
          onPressed: app.busy ? null : app.scan,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(app.busy ? '扫描中…' : '刷新媒体库'),
        ),
      ],
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.primaryContainer,
                colors.secondaryContainer.withValues(alpha: 0.35),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '画面留在眼前，声音陪在身边。',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '从 Wallpaper Engine 收藏到本地媒体，一处浏览，自在播放。',
                      style: TextStyle(
                        color: colors.onPrimaryContainer.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Icon(
                Icons.slow_motion_video_rounded,
                size: 64,
                color: colors.primary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              SectionCard(
                title: 'Wallpaper Engine 订阅',
                icon: Icons.wallpaper_rounded,
                trailing: TextButton(
                  onPressed: () => go(1),
                  child: const Text('浏览全部 →'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${app.subscriptions.length}',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 9),
                          child: Text('个视频收藏'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (app.subscriptions.isEmpty)
                      Container(
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('扫描本地订阅，发现你的收藏'),
                      )
                    else
                      SizedBox(
                        height: 96,
                        child: Row(
                          children: [
                            for (final entry in app.subscriptions.take(3))
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: InkWell(
                                    onTap: () {
                                      app.playback.play([
                                        entry,
                                      ], asAudio: false);
                                      go(3);
                                    },
                                    child: MediaArt(entry: entry, height: 96),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      '无需开启壁纸引擎 · 自动发现 Steam 多库',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: '播放队列',
                icon: Icons.queue_music_rounded,
                trailing: TextButton(
                  onPressed: () => go(2),
                  child: const Text('管理队列 →'),
                ),
                child: ListenableBuilder(
                  listenable: app.playback,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${app.playback.queue.length}',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 9),
                            child: Text('个待播 · ${app.playlists.length} 张列表'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 96,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.headphones_rounded,
                              color: colors.primary,
                              size: 36,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.playback.current?.title ?? '今天，想听点什么？',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    modeLabels[app.playback.mode]!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '顺序 / 随机 / 循环 · 视频也能只听声音',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SectionCard(
                title: '视频播放',
                icon: Icons.play_circle_outline_rounded,
                trailing: TextButton(
                  onPressed: () => go(3),
                  child: const Text('打开播放器 →'),
                ),
                child: PlayerView(playback: app.playback, compact: true),
              ),
              SectionCard(
                title: '本地媒体',
                icon: Icons.video_library_outlined,
                trailing: TextButton(
                  onPressed: () => go(4),
                  child: const Text('查看媒体 →'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${app.local.length}',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 8, bottom: 9),
                          child: Text('个视频与音频'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '电影、音乐、生活的片段。\n让你的文件夹，成为随身的放映室。',
                      style: TextStyle(height: 1.8),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: app.busy ? null : () => importFiles(app),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('导入文件'),
                        ),
                        OutlinedButton(
                          onPressed: app.busy
                              ? null
                              : () => importFiles(app, folder: true),
                          child: const Text('选择文件夹'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ];
            if (constraints.maxWidth < 780) {
              return Column(
                children: [
                  for (final card in cards)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: card,
                    ),
                ],
              );
            }
            return Column(
              children: [
                for (var i = 0; i < cards.length; i += 2) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[i]),
                      const SizedBox(width: 18),
                      Expanded(child: cards[i + 1]),
                    ],
                  ),
                  if (i == 0) const SizedBox(height: 18),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
