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
  Widget build(BuildContext context) => PageFrame(
    title: '让收藏，重新流动。',
    subtitle: '订阅与本地影音，一处浏览，自在播放。',
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth < 650
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;
          final cardHeight = (cardWidth - 32) * 9 / 16 + 76;
          Widget card(
            int index,
            String title,
            IconData icon,
            String action,
            Widget child,
          ) => SizedBox(
            key: ValueKey('overview-card-$index'),
            height: cardHeight,
            child: SectionCard(
              leading: index == 1
                  ? OutlinedButton.icon(
                      onPressed: app.busy ? null : app.scan,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(app.busy ? '扫描中…' : '刷新媒体库'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    )
                  : null,
              title: title,
              icon: icon,
              trailing: index == 1
                  ? null
                  : OutlinedButton(
                      onPressed: () => go(index),
                      child: Text(action),
                    ),
              child: Expanded(child: child),
            ),
          );
          final cards = [
            card(
              1,
              '壁纸订阅',
              Icons.wallpaper_rounded,
              '浏览全部 →',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${app.subscriptions.length} 个视频收藏',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => go(1),
                        child: const Text('浏览全部 →'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: app.subscriptions.isEmpty
                        ? const Center(child: Text('扫描本地订阅，发现你的收藏'))
                        : Row(
                            children: [
                              for (final entry in app.subscriptions.take(3))
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () {
                                        app.playback.play([
                                          entry,
                                        ], asAudio: false);
                                        go(3);
                                      },
                                      child: MediaArt(
                                        entry: entry,
                                        height: double.infinity,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            card(
              2,
              '播放队列',
              Icons.queue_music_rounded,
              '管理队列 →',
              ListenableBuilder(
                listenable: app.playback,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${app.playback.queue.length} 个待播 · ${app.playlists.length} 张列表',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      app.playback.current?.title ?? '今天，想听点什么？',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),
            card(
              3,
              '视频播放',
              Icons.play_circle_outline_rounded,
              '打开播放器 →',
              Center(
                child: AspectRatio(
                  key: const ValueKey('overview-video-frame'),
                  aspectRatio: 16 / 9,
                  child: PlayerView(
                    playback: app.playback,
                    compact: true,
                    fill: true,
                  ),
                ),
              ),
            ),
            card(
              4,
              '本地媒体',
              Icons.video_library_outlined,
              '查看媒体 →',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${app.local.length} 个视频与音频',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),

                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
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
          if (constraints.maxWidth < 650) {
            return Column(
              children: [
                for (final item in cards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: item,
                  ),
              ],
            );
          }
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        },
      ),
      SectionCard(
        title: '性能',
        icon: Icons.speed_rounded,
        trailing: OutlinedButton.icon(
          onPressed: () => go(6),
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('查看性能'),
        ),
        child: Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            Text('后台视频解码：${app.suspendVideoInBackground ? '自动暂停' : '保持'}'),
            Text('预览缓存：${app.previewCacheMiB} MB'),
          ],
        ),
      ),
    ],
  );
}
