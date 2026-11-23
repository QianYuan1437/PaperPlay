import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../app_info.dart';
import '../services/update_service.dart';
import 'theme.dart';
import 'widgets.dart';

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
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('模糊预览'),
              subtitle: const Text('同步模糊所有封面与视频画面，播放控件保持清晰'),
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
            const Text('自动读取 Steam 安装位置与 libraryfolders.vdf，支持多个磁盘中的订阅。'),
            const SizedBox(height: 8),
            if (app.detectedRoots.isEmpty && app.manualRoots.isEmpty)
              const Text('尚未检测到目录，可添加 Steam 根目录或 431960 文件夹。'),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                '扫描目录（${app.detectedRoots.length + app.manualRoots.length}）',
              ),
              children: [
                for (final root in app.detectedRoots)
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 20,
                    ),
                    title: SelectableText(root),
                    subtitle: const Text('已发现的订阅目录'),
                  ),
                for (final root in app.manualRoots)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.folder_outlined, size: 20),
                    title: SelectableText(root),
                    subtitle: const Text('手动添加'),
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
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('启动时自动扫描'),
              subtitle: const Text('扫描在后台进行，优先显示上次缓存的媒体库'),
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
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('关闭窗口时收起到托盘'),
              subtitle: const Text('音视频继续播放；从托盘菜单选择「退出」可完全关闭'),
              value: app.closeToTray,
              onChanged: (v) {
                app.closeToTray = v;
                app.changed();
              },
            ),
            const ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('纯音频模式'),
              subtitle: Text('关闭视频轨道，保留声音。播放器切换页面或收起到托盘后仍会继续播放。'),
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
            const Text(
              'PaperPlay $appVersion · Windows x64',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '基于 Flutter 与 media_kit / libmpv。界面主题衍生自 OpenSpeak。\n只管理本机已下载的媒体；scene、web 和 application 壁纸不参与视频扫描。',
            ),
            const SizedBox(height: 8),
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
                TextButton(
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
    return PageFrame(
      title: '偏好设置',
      subtitle: '外观、媒体来源与软件更新。',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final update = _UpdateCard(app: app);
            if (constraints.maxWidth < 700) {
              return column([update, cards[0], cards[2], cards[1], cards[3]]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: column([cards[0], cards[2]])),
                const SizedBox(width: 12),
                Expanded(child: column([update, cards[1], cards[3]])),
              ],
            );
          },
        ),
      ],
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
