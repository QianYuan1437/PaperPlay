import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../models/media_entry.dart';
import 'widgets.dart';
import 'blur_toggle.dart';

Future<void> importFiles(AppState app, {bool folder = false}) async {
  try {
    if (folder) {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '导入媒体文件夹',
      );
      if (path != null) await app.import([path]);
    } else {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [...videoExtensions, ...audioExtensions],
        dialogTitle: '导入视频或音频',
      );
      if (result != null) {
        await app.import(result.paths.whereType<String>().toList());
      }
    }
  } catch (e) {
    app.message = '无法打开文件选择器：$e';
    app.changed();
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.app,
    required this.source,
    required this.openPlayer,
  });
  final AppState app;
  final MediaSource source;
  final VoidCallback openPlayer;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final selected = <String>{};
  final search = TextEditingController();
  final scroll = ScrollController();
  bool favoritesOnly = false;
  String sort = 'title';
  String kind = 'all';
  AppState get app => widget.app;
  bool get wallpaper => widget.source == MediaSource.wallpaper;
  @override
  void dispose() {
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = wallpaper ? app.subscriptions : app.local;
    final query = search.text.trim().toLowerCase();
    final filtered = source
        .where(
          (e) =>
              (!favoritesOnly || app.favorites.contains(e.id)) &&
              (kind == 'all' || (kind == 'audio' ? e.isAudio : !e.isAudio)) &&
              '${e.title} ${e.tags.join(' ')} ${e.workshopId ?? ''} ${e.path}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    filtered.sort(
      (a, b) => switch (sort) {
        'recent' => b.modified.compareTo(a.modified),
        'size' => b.bytes.compareTo(a.bytes),
        _ => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      },
    );
    final chosen = filtered.where((e) => selected.contains(e.id)).toList();
    final actionItems = chosen.isEmpty ? filtered : chosen;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '搜索名称、标签或路径',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空搜索',
                            onPressed: () => setState(search.clear),
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: app.busy
                    ? null
                    : wallpaper
                    ? app.scan
                    : () => importFiles(app),
                icon: Icon(
                  wallpaper ? Icons.refresh_rounded : Icons.add_rounded,
                  size: 18,
                ),
                label: Text(wallpaper ? (app.busy ? '扫描中…' : '扫描订阅') : '导入文件'),
              ),
              const SizedBox(width: 10),
              FilterChip(
                label: const Text('我的收藏'),
                avatar: const Icon(Icons.favorite_border_rounded, size: 16),
                selected: favoritesOnly,
                onSelected: (v) => setState(() => favoritesOnly = v),
              ),
              const SizedBox(width: 12),
              RoundedSelect(
                value: sort,
                options: const {
                  'title': '名称排序',
                  'recent': '最近修改',
                  'size': '文件大小',
                },
                onSelected: (v) => setState(() => sort = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BlurToggle(app: app),
              Text(
                '${filtered.length} 个媒体${chosen.isEmpty ? '' : ' · 已选 ${chosen.length} 项'}',
                style: const TextStyle(fontSize: 12),
              ),
              OutlinedButton(
                onPressed: filtered.isEmpty
                    ? null
                    : () => setState(() {
                        if (chosen.length == filtered.length) {
                          selected.clear();
                        } else {
                          selected.addAll(filtered.map((e) => e.id));
                        }
                      }),
                child: Text(
                  chosen.length == filtered.length && filtered.isNotEmpty
                      ? '取消选择'
                      : '全选',
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: actionItems.isEmpty
                    ? null
                    : () {
                        app.playback.play(actionItems, asAudio: false);
                        widget.openPlayer();
                      },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(chosen.isEmpty ? '播放全部' : '播放所选'),
              ),
              OutlinedButton.icon(
                onPressed: actionItems.isEmpty
                    ? null
                    : () => app.playback.play(actionItems, asAudio: true),
                icon: const Icon(Icons.headphones_rounded, size: 18),
                label: const Text('只听声音'),
              ),
              OutlinedButton.icon(
                onPressed: actionItems.isEmpty
                    ? null
                    : () {
                        app.playback.enqueue(actionItems);
                        _toast('已加入播放队列');
                      },
                icon: const Icon(Icons.playlist_add_rounded, size: 18),
                label: const Text('加入队列'),
              ),
              OutlinedButton(
                onPressed: actionItems.isEmpty
                    ? null
                    : () => _save(actionItems),
                child: const Text('保存为列表'),
              ),
              if (!wallpaper) ...[
                RoundedSelect(
                  value: kind,
                  options: const {'all': '全部类型', 'video': '视频', 'audio': '音频'},
                  onSelected: (v) => setState(() => kind = v),
                ),
                OutlinedButton(
                  onPressed: app.busy
                      ? null
                      : () => importFiles(app, folder: true),
                  child: const Text('导入文件夹'),
                ),
              ],
              if (chosen.isNotEmpty)
                OutlinedButton(
                  onPressed: () => _forget(chosen),
                  child: const Text('移出媒体库'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: EmptyState(
                      icon: wallpaper
                          ? Icons.wallpaper_rounded
                          : Icons.video_library_outlined,
                      title: source.isEmpty
                          ? (wallpaper ? '开始整理你的壁纸收藏' : '你的本地影音空间')
                          : '没有匹配的媒体',
                      description: source.isEmpty
                          ? (wallpaper
                                ? '自动查找 Steam 订阅目录，也可以在设置中添加路径。'
                                : '支持视频与音频文件，导入文件夹时会包含子文件夹。')
                          : '试试其他关键词，或清除收藏 / 类型筛选。',
                      action: source.isEmpty
                          ? OutlinedButton(
                              onPressed: app.busy
                                  ? null
                                  : wallpaper
                                  ? app.scan
                                  : () => importFiles(app),
                              child: Text(wallpaper ? '查找本地订阅' : '选择媒体文件'),
                            )
                          : null,
                    ),
                  )
                : ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: Scrollbar(
                      controller: scroll,
                      child: ScrollEdgeFade(
                        child: GridView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.only(
                            top: 16,
                            bottom: 26,
                            right: 16,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 290,
                                mainAxisExtent: 226,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final item = filtered[i];
                            return _MediaCard(
                              entry: item,
                              selected: selected.contains(item.id),
                              favorite: app.favorites.contains(item.id),
                              onSelect: () => setState(() {
                                if (!selected.add(item.id)) {
                                  selected.remove(item.id);
                                }
                              }),
                              onFavorite: () => app.favorite(item),
                              onPlay: () {
                                app.playback.play(
                                  filtered,
                                  start: i,
                                  asAudio: false,
                                );
                                widget.openPlayer();
                              },
                              onAudio: () =>
                                  app.playback.play([item], asAudio: true),
                              onEnqueue: () {
                                app.playback.enqueue([item]);
                                _toast('已加入播放队列');
                              },
                              onForget: () => _forget([item]),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
  Future<void> _save(List<MediaEntry> items) async {
    final name = await askName(context);
    if (name != null) {
      app.savePlaylist(name, items);
      if (mounted) _toast('播放列表已保存');
    }
  }

  Future<void> _forget(List<MediaEntry> items) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移出媒体库？'),
        content: Text(
          '移除 ${items.length} 项记录，磁盘文件不会删除，也不会取消 Steam 订阅。订阅项目再次扫描后会重新显示。',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      app.forget(items);
      if (mounted) setState(() => selected.removeAll(items.map((e) => e.id)));
    }
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.entry,
    required this.selected,
    required this.favorite,
    required this.onSelect,
    required this.onFavorite,
    required this.onPlay,
    required this.onAudio,
    required this.onEnqueue,
    required this.onForget,
  });
  final MediaEntry entry;
  final bool selected;
  final bool favorite;
  final VoidCallback onSelect, onFavorite, onPlay, onAudio, onEnqueue, onForget;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    shape: selected
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          )
        : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              InkWell(
                onTap: onPlay,
                child: MediaArt(entry: entry, radius: 0),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onSelect(),
                    side: const BorderSide(color: Colors.white),
                    checkColor: Colors.white,
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.format,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
          child: Text(
            entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 6, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatBytes(entry.bytes),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: favorite ? '取消收藏' : '收藏',
                onPressed: onFavorite,
                iconSize: 19,
                icon: Icon(
                  favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: favorite
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    onPressed: onPlay,
                    leadingIcon: const Icon(Icons.play_arrow_rounded),
                    child: const Text('播放视频'),
                  ),
                  MenuItemButton(
                    onPressed: onAudio,
                    leadingIcon: const Icon(Icons.headphones_rounded),
                    child: const Text('只听声音'),
                  ),
                  MenuItemButton(
                    onPressed: onEnqueue,
                    leadingIcon: const Icon(Icons.playlist_add_rounded),
                    child: const Text('加入队列'),
                  ),
                  MenuItemButton(
                    onPressed: () async {
                      await Process.run('explorer.exe', [
                        p.dirname(entry.path),
                      ]);
                    },
                    leadingIcon: const Icon(Icons.folder_open_rounded),
                    child: const Text('打开所在文件夹'),
                  ),
                  if (entry.workshopId != null &&
                      RegExp(r'^\d+$').hasMatch(entry.workshopId!))
                    MenuItemButton(
                      onPressed: () => launchUrl(
                        Uri.https(
                          'steamcommunity.com',
                          '/sharedfiles/filedetails/',
                          {'id': entry.workshopId!},
                        ),
                      ),
                      leadingIcon: const Icon(Icons.open_in_new_rounded),
                      child: const Text('查看创意工坊'),
                    ),
                  MenuItemButton(
                    onPressed: onForget,
                    leadingIcon: const Icon(
                      Icons.remove_circle_outline_rounded,
                    ),
                    child: const Text('移出媒体库'),
                  ),
                ],
                builder: (context, controller, _) => IconButton(
                  tooltip: '更多操作',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
