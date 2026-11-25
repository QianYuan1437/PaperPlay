import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../app_info.dart';
import '../services/update_service.dart';
import 'theme.dart';
import 'widgets.dart';
import 'performance_options.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      SectionCard(
        key: const ValueKey('settings-appearance'),
        title: '外观',
        icon: Icons.palette_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('显示模式')),
                RoundedSelect(
                  value: app.themeMode,
                  options: const {
                    ThemeMode.system: '跟随系统',
                    ThemeMode.light: '浅色',
                    ThemeMode.dark: '深色',
                  },
                  onSelected: (v) {
                    app.themeMode = v;
                    app.changed();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('主题色'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final preset in kAccentPresets)
                  ChoiceChip(
                    label: Text(preset.$2),
                    avatar: CircleAvatar(
                      backgroundColor: Color(preset.$1),
                      radius: 8,
                    ),
                    selected: app.accent == preset.$1,
                    onSelected: (_) {
                      app.accent = preset.$1;
                      app.changed();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('模糊预览'),
              value: app.blurPreviews,
              onChanged: (value) {
                app.blurPreviews = value;
                app.changed();
              },
            ),
          ],
        ),
      ),
      SectionCard(
        title: '媒体来源',
        icon: Icons.folder_open_rounded,
        trailing: OutlinedButton.icon(
          onPressed: () async {
            final value = await FilePicker.platform.getDirectoryPath(
              dialogTitle: '选择 Steam 根目录、库目录或 431960 文件夹',
            );
            if (value != null && !app.manualRoots.contains(value)) {
              app.manualRoots.add(value);
              app.changed();
              await app.scan();
            }
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('添加目录'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (app.detectedRoots.isEmpty && app.manualRoots.isEmpty)
              const Text('尚未检测到目录，可添加 Steam 根目录或 431960 文件夹。'),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              title: Text(
                '扫描目录（${app.detectedRoots.length + app.manualRoots.length}）',
              ),
              children: [
                for (final root in app.detectedRoots)
                  ListTile(
                    leading: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 20,
                    ),
                    title: SelectableText(root),
                  ),
                for (final root in app.manualRoots)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined, size: 20),
                    title: SelectableText(root),
                    trailing: IconButton(
                      tooltip: '移除扫描目录',
                      onPressed: () {
                        app.manualRoots.remove(root);
                        app.changed();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
              ],
            ),
            SwitchListTile(
              title: const Text('启动时自动扫描'),
              value: app.autoScan,
              onChanged: (v) {
                app.autoScan = v;
                app.changed();
              },
            ),
            if (app.lastScan != null)
              Text(
                '最近扫描：${app.lastScan!.toLocal().toString().split('.').first}',
                style: const TextStyle(fontSize: 12),
              ),
            if (app.warnings.isNotEmpty)
              ExpansionTile(
                title: Text('${app.warnings.length} 条扫描提示'),
                children: [
                  for (final warning in app.warnings.take(100))
                    ListTile(dense: true, title: SelectableText(warning)),
                ],
              ),
          ],
        ),
      ),
      SectionCard(
        title: '窗口与后台播放',
        icon: Icons.desktop_windows_outlined,
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('关闭窗口时收起到托盘'),
              value: app.closeToTray,
              onChanged: (v) {
                app.closeToTray = v;
                app.changed();
              },
            ),
            ListenableBuilder(
              listenable: app.playback,
              builder: (context, _) => SwitchListTile(
                key: const ValueKey('settings-audio-only'),
                title: const Text('纯音频模式'),
                value: app.playback.audioOnly,
                onChanged: app.playback.setAudioOnly,
              ),
            ),
          ],
        ),
      ),
      SectionCard(
        title: '关于 PaperPlay',
        icon: Icons.info_outline_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => launchUrl(
                    Uri.parse('https://github.com/QianYuan1437/PaperPlay'),
                  ),
                  child: const Text('项目主页'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      Process.run('explorer.exe', [app.store.file.parent.path]),
                  child: const Text('打开数据目录'),
                ),
                OutlinedButton(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'PaperPlay',
                    applicationVersion: appVersion,
                  ),
                  child: const Text('开源许可'),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
    Widget column(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in children) ...[child, const SizedBox(height: 12)],
      ],
    );
    return ListTileTheme(
      data: ListTileTheme.of(context).copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minVerticalPadding: 8,
        minTileHeight: 52,
        visualDensity: VisualDensity.standard,
      ),
      child: PageFrame(
        title: '偏好设置',
        subtitle: '外观、媒体来源与软件更新。',
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final update = _UpdateCard(app: app);
              final performance = SectionCard(
                title: '性能配置',
                icon: Icons.speed_rounded,
                child: PerformanceOptions(app: app),
              );
              final appearance = SectionCard(
                title: '窗口材质与动效',
                icon: Icons.blur_on_rounded,
                child: AppearanceOptions(app: app),
              );
              if (constraints.maxWidth < 700) {
                return column([
                  update,
                  cards[0],
                  cards[2],
                  cards[1],
                  performance,
                  appearance,
                  cards[3],
                ]);
              }
              Widget pair(Widget left, Widget right) => IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 12),
                    Expanded(child: right),
                  ],
                ),
              );
              return column([
                pair(cards[0], update),
                pair(cards[2], cards[1]),
                pair(performance, appearance),
                cards[3],
              ]);
            },
          ),
        ],
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app.updates,
    builder: (context, _) => SectionCard(
      key: const ValueKey('settings-updates'),
      title: '软件更新',
      icon: Icons.system_update_alt_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('当前版本 v$appVersion · Windows x64'),
          const SizedBox(height: 8),
          Text(app.updates.message, key: const ValueKey('update-status')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.tonalIcon(
                onPressed: app.updates.status == UpdateStatus.checking
                    ? null
                    : app.updates.check,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  app.updates.status == UpdateStatus.checking ? '检查中…' : '检查更新',
                ),
              ),
              if (app.updates.status == UpdateStatus.available)
                OutlinedButton(
                  onPressed: () => launchUrl(
                    app.updates.releaseUrl!,
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('查看并下载更新'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
