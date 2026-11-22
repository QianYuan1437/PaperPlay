import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../app_state.dart';
import '../models/queue_order.dart';
import '../services/playback_controller.dart';
import 'widgets.dart';

const modeLabels = {
  PlayMode.sequential: '顺序播放',
  PlayMode.shuffle: '随机播放',
  PlayMode.repeatOne: '单曲循环',
  PlayMode.repeatAll: '列表循环',
};

class PlayerView extends StatelessWidget {
  const PlayerView({super.key, required this.playback, this.compact = false});
  final PlaybackController playback;
  final bool compact;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, _) {
      final item = playback.current;
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: item == null
              ? Container(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Center(
                    child: EmptyState(
                      icon: Icons.play_circle_outline_rounded,
                      title: '给喜欢的画面，按下播放',
                      description: '从订阅库或本地媒体选择视频',
                      compact: compact,
                    ),
                  ),
                )
              : playback.audioOnly || item.isAudio
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.surfaceContainerLow,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.headphones_rounded,
                          size: compact ? 44 : 76,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('只听声音 · 让专注多一点'),
                      ],
                    ),
                  ),
                )
              : Video(
                  controller: playback.video,
                  pauseUponEnteringBackgroundMode: false,
                  resumeUponEnteringForegroundMode: false,
                  controls: AdaptiveVideoControls,
                ),
        ),
      );
    },
  );
}

class PlaybackBar extends StatelessWidget {
  const PlaybackBar({super.key, required this.app, required this.openPlayer});
  final AppState app;
  final VoidCallback openPlayer;
  @override
  Widget build(BuildContext context) {
    final playback = app.playback;
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final colors = Theme.of(context).colorScheme;
        final item = playback.current;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            border: Border(
              top: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<Duration>(
                stream: playback.player.stream.position,
                initialData: playback.player.state.position,
                builder: (context, position) => StreamBuilder<Duration>(
                  stream: playback.player.stream.duration,
                  initialData: playback.player.state.duration,
                  builder: (context, duration) {
                    final max = (duration.data ?? Duration.zero).inMilliseconds
                        .toDouble();
                    return Row(
                      children: [
                        Text(
                          clockLabel(position.data ?? Duration.zero),
                          style: const TextStyle(fontSize: 11),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 18,
                            child: Slider(
                              value:
                                  (position.data?.inMilliseconds.toDouble() ??
                                          0)
                                      .clamp(0, max > 0 ? max : 1),
                              max: max > 0 ? max : 1,
                              onChanged: max <= 0
                                  ? null
                                  : (v) => playback.player.seek(
                                      Duration(milliseconds: v.round()),
                                    ),
                            ),
                          ),
                        ),
                        Text(
                          clockLabel(duration.data ?? Duration.zero),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  InkWell(
                    onTap: openPlayer,
                    borderRadius: BorderRadius.circular(12),
                    child: MediaArt(entry: item, width: 48, height: 48),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: openPlayer,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item?.title ?? '还没有播放内容',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item == null
                                ? '选择视频，或导入你的音乐'
                                : '${playback.audioOnly ? '纯音频' : item.format} · ${playback.index + 1} / ${playback.queue.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '上一首',
                    onPressed: item == null ? null : playback.previous,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  IconButton.filled(
                    tooltip: playback.playing ? '暂停' : '播放',
                    onPressed: item == null ? null : playback.toggle,
                    icon: Icon(
                      playback.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    iconSize: 28,
                  ),
                  IconButton(
                    tooltip: '下一首',
                    onPressed: item == null ? null : playback.next,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                  const SizedBox(width: 16),
                  RoundedSelect(
                    value: playback.mode,
                    options: modeLabels,
                    onSelected: playback.setMode,
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: playback.audioOnly ? '切换到视频' : '只听声音',
                    isSelected: playback.audioOnly,
                    onPressed: () => playback.setAudioOnly(!playback.audioOnly),
                    icon: const Icon(Icons.headphones_rounded),
                  ),
                  StreamBuilder<double>(
                    stream: playback.player.stream.volume,
                    initialData: playback.player.state.volume,
                    builder: (context, volume) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '静音 / 恢复音量',
                          icon: Icon(
                            (volume.data ?? 0) == 0
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                          ),
                          onPressed: () {
                            playback.player.setVolume(
                              (volume.data ?? 0) == 0 ? 70 : 0,
                            );
                            app.persist();
                          },
                        ),
                        SizedBox(
                          width: 90,
                          child: Slider(
                            value: (volume.data ?? 70).clamp(0, 100),
                            max: 100,
                            onChanged: playback.player.setVolume,
                            onChangeEnd: (_) => app.persist(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (playback.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: colors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          playback.error!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.error, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: playback.next,
                        child: const Text('跳过'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
