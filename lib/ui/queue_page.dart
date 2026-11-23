import 'package:flutter/material.dart';
import '../app_state.dart';
import 'player_view.dart';
import 'widgets.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final playback = app.playback;
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeading(
              title: '播放队列',
              subtitle: '为此刻的心情，排一张歌单。视频也可以只听声音。',
              actions: [
                FilledButton.icon(
                  onPressed: playback.queue.isEmpty
                      ? null
                      : () async {
                          final items = List.of(playback.queue);
                          final name = await askName(context);
                          if (name != null) app.savePlaylist(name, items);
                        },
                  icon: const Icon(Icons.playlist_add_rounded, size: 18),
                  label: const Text('保存列表'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RoundedSelect(
                  value: playback.mode,
                  options: modeLabels,
                  onSelected: playback.setMode,
                ),
                FilterChip(
                  selected: playback.audioOnly,
                  onSelected: playback.setAudioOnly,
                  avatar: const Icon(Icons.headphones_rounded, size: 18),
                  label: const Text('纯音频播放'),
                ),
                Text(
                  '${playback.queue.length} 首',
                  style: const TextStyle(fontSize: 13),
                ),
                TextButton(
                  onPressed: playback.queue.isEmpty ? null : playback.clear,
                  child: const Text('清空队列'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Card(
                      child: playback.queue.isEmpty
                          ? const Center(
                              child: EmptyState(
                                icon: Icons.queue_music_rounded,
                                title: '队列等你来填满',
                                description: '在媒体卡片中选择「加入队列」，\n或播放右侧已保存的列表。',
                              ),
                            )
                          : ReorderableListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: playback.queue.length,
                              buildDefaultDragHandles: false,
                              onReorder: playback.reorder,
                              itemBuilder: (context, i) {
                                final entry = playback.queue[i];
                                return ListTile(
                                  key: ValueKey('$i-${entry.id}'),
                                  selected: playback.index == i,
                                  selectedTileColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.4),
                                  leading: MediaArt(
                                    entry: entry,
                                    width: 54,
                                    height: 42,
                                    radius: 8,
                                  ),
                                  title: Text(
                                    entry.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${entry.format} · ${formatBytes(entry.bytes)}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onTap: () => playback.jump(i),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: '移出队列',
                                        onPressed: () => playback.remove(i),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                        ),
                                      ),
                                      ReorderableDragStartListener(
                                        index: i,
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.drag_indicator_rounded,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 2,
                    child: SectionCard(
                      title: '我的播放列表',
                      icon: Icons.library_music_outlined,
                      child: Expanded(
                        child: app.playlists.isEmpty
                            ? const Center(
                                child: Text(
                                  '保存当前队列，\n让喜欢的组合随时回来。',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.separated(
                                itemCount: app.playlists.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final list = app.playlists[i];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    leading: IconButton(
                                      tooltip: '播放列表',
                                      onPressed: () =>
                                          playback.play(list.items),
                                      icon: const Icon(
                                        Icons.play_circle_outline_rounded,
                                      ),
                                    ),
                                    title: Text(
                                      list.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text('${list.items.length} 个媒体'),
                                    trailing: MenuAnchor(
                                      menuChildren: [
                                        MenuItemButton(
                                          onPressed: () => playback.play(
                                            list.items,
                                            asAudio: true,
                                          ),
                                          child: const Text('纯音频播放'),
                                        ),
                                        MenuItemButton(
                                          onPressed: () =>
                                              playback.enqueue(list.items),
                                          child: const Text('追加到队列'),
                                        ),
                                        MenuItemButton(
                                          onPressed: () async {
                                            final name = await askName(
                                              context,
                                              title: '重命名列表',
                                              initial: list.name,
                                            );
                                            if (name != null) {
                                              list.name = name;
                                              app.changed();
                                            }
                                          },
                                          child: const Text('重命名'),
                                        ),
                                        MenuItemButton(
                                          onPressed: playback.queue.isEmpty
                                              ? null
                                              : () async {
                                                  final confirmed =
                                                      await showDialog<bool>(
                                                        context: context,
                                                        builder: (context) => AlertDialog(
                                                          title: const Text(
                                                            '用当前队列更新列表？',
                                                          ),
                                                          content: Text(
                                                            '「${list.name}」将保存当前 ${playback.queue.length} 个媒体及其顺序。',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    false,
                                                                  ),
                                                              child: const Text(
                                                                '取消',
                                                              ),
                                                            ),
                                                            FilledButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    true,
                                                                  ),
                                                              child: const Text(
                                                                '更新',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                  if (confirmed == true) {
                                                    list.items = List.of(
                                                      playback.queue,
                                                    );
                                                    app.changed();
                                                  }
                                                },
                                          child: const Text('用当前队列更新'),
                                        ),
                                        MenuItemButton(
                                          onPressed: () async {
                                            final yes = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('删除播放列表？'),
                                                content: Text(
                                                  '删除「${list.name}」，原始媒体文件不受影响。',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: const Text('取消'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: const Text('删除'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (yes == true) {
                                              app.playlists.remove(list);
                                              app.changed();
                                            }
                                          },
                                          child: const Text('删除列表'),
                                        ),
                                      ],
                                      builder: (context, controller, _) =>
                                          IconButton(
                                            tooltip: '列表操作',
                                            icon: const Icon(
                                              Icons.more_horiz_rounded,
                                            ),
                                            onPressed: () => controller.isOpen
                                                ? controller.close()
                                                : controller.open(),
                                          ),
                                    ),
                                  );
                                },
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
    );
  }
}
