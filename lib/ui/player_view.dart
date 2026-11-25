import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../app_state.dart';
import '../models/queue_order.dart';
import '../services/playback_controller.dart';
import 'widgets.dart';
import 'playback_timeline.dart';

const modeLabels = {
  PlayMode.sequential: '顺序播放',
  PlayMode.shuffle: '随机播放',
  PlayMode.repeatOne: '单曲循环',
  PlayMode.repeatAll: '列表循环',
};

class PlayerView extends StatelessWidget {
  const PlayerView({
    super.key,
    required this.playback,
    this.compact = false,
    this.fill = false,
  });
  final PlaybackController playback;
  final bool compact;
  final bool fill;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, _) {
      final item = playback.current;
      final blur = PreviewPrivacy.of(context);
      final content = item == null
          ? Container(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Center(
                child: EmptyState(
                  icon: Icons.play_circle_outline_rounded,
                  title: '',
                  description: '',
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
                child: SingleChildScrollView(
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
                    ],
                  ),
                ),
              ),
            )
          : Video(
              controller: playback.video,
              pauseUponEnteringBackgroundMode: false,
              resumeUponEnteringForegroundMode: false,
              controls: (state) => Stack(
                fit: StackFit.expand,
                children: [
                  if (blur)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: const ColoredBox(color: Color(0x18000000)),
                          ),
                        ),
                      ),
                    ),
                  if (!playback.mediaLoaded)
                    Positioned.fill(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MediaArt(entry: item, radius: 0),
                          Center(
                            child: FilledButton.icon(
                              key: const ValueKey('load-restored-video'),
                              onPressed: playback.opening
                                  ? null
                                  : playback.toggle,
                              icon: Icon(
                                playback.opening
                                    ? Icons.hourglass_top_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              label: Text(playback.opening ? '加载中…' : '播放'),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    AdaptiveVideoControls(state),
                ],
              ),
            );
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: fill
            ? SizedBox.expand(child: content)
            : AspectRatio(aspectRatio: 16 / 9, child: content),
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlaybackTimeline(
                key: ValueKey('${item?.id}-${playback.index}'),
                positionStream: playback.player.stream.position,
                durationStream: playback.player.stream.duration,
                initialPosition: playback.player.state.position,
                initialDuration: playback.player.state.duration,
                onSeek: playback.player.seek,
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
