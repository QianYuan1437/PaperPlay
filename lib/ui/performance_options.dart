import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/video_loading.dart';
import 'widgets.dart';

/// The same controls and state are used in Settings and Performance.
class PerformanceOptions extends StatelessWidget {
  const PerformanceOptions({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListenableBuilder(
        listenable: app.playback,
        builder: (context, _) => Column(
          children: [
            ListTile(
              title: const Text('视频加载方式'),
              trailing: RoundedSelect(
                key: const ValueKey('video-loading-mode'),
                value: app.playback.loadingMode,
                options: const {
                  VideoLoading.disk: '硬盘直读',
                  VideoLoading.memory: '内存缓存',
                },
                onSelected: app.playback.setLoading,
              ),
            ),
            if (app.playback.loadingMode == VideoLoading.memory)
              ListTile(
                title: const Text('视频缓存上限'),
                trailing: RoundedSelect(
                  key: const ValueKey('video-cache-limit'),
                  value: app.playback.videoCacheMiB,
                  options: const {128: '128 MB', 256: '256 MB', 512: '512 MB'},
                  onSelected: (value) => app.playback.setLoading(
                    VideoLoading.memory,
                    cacheMiB: value,
                  ),
                ),
              ),
          ],
        ),
      ),
      SwitchListTile(
        key: const ValueKey('performance-enabled'),
        title: const Text('性能统计'),
        value: app.performanceEnabled,
        onChanged: (value) {
          app.performanceEnabled = value;
          app.changed();
        },
      ),
      SwitchListTile(
        title: const Text('后台停止视频解码'),
        value: app.suspendVideoInBackground,
        onChanged: (value) {
          app.suspendVideoInBackground = value;
          app.changed();
        },
      ),
      SwitchListTile(
        title: const Text('后台释放闲置预览缓存'),
        value: app.releasePreviewCache,
        onChanged: (value) {
          app.releasePreviewCache = value;
          app.changed();
        },
      ),
      ListTile(
        title: const Text('预览缓存上限'),
        trailing: RoundedSelect(
          value: app.previewCacheMiB,
          options: const {32: '32 MB', 64: '64 MB', 128: '128 MB'},
          onSelected: (value) {
            app.previewCacheMiB = value;
            app.changed();
          },
        ),
      ),
      ListTile(
        title: const Text('统计刷新间隔'),
        trailing: RoundedSelect(
          value: app.sampleSeconds,
          options: const {1: '1 秒', 2: '2 秒', 5: '5 秒'},
          onSelected: (value) {
            app.sampleSeconds = value;
            app.changed();
          },
        ),
      ),
    ],
  );
}

class AppearanceOptions extends StatelessWidget {
  const AppearanceOptions({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        title: const Text('窗口材质'),
        trailing: RoundedSelect(
          value: app.windowEffect,
          options: const {
            'solid': '纯色',
            'transparent': '透明',
            'acrylic': '亚克力',
            'mica': '云母',
          },
          onSelected: (value) {
            app.windowEffect = value;
            app.changed();
          },
        ),
      ),
      if (app.windowEffect != 'solid') ...[
        ListTile(
          title: const Text('背景不透明度'),
          trailing: Text('${(app.surfaceOpacity * 100).round()}%'),
        ),
        Slider(
          value: app.surfaceOpacity,
          min: 0.55,
          max: 1,
          divisions: 9,
          label: '${(app.surfaceOpacity * 100).round()}%',
          onChanged: app.previewOpacityChanged,
          onChangeEnd: (_) => app.persist(),
        ),
      ],
      if (app.appearanceMessage != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(app.appearanceMessage!),
        ),
      SwitchListTile(
        title: const Text('减少界面动效'),
        value: app.reduceMotion,
        onChanged: (value) {
          app.reduceMotion = value;
          app.changed();
        },
      ),
    ],
  );
}
