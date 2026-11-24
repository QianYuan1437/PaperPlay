import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/media_entry.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.actions = const [],
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    children: [
      PageHeading(title: title, subtitle: subtitle, actions: actions),
      if (actions.isNotEmpty) const SizedBox(height: 10),
      for (final child in children) ...[child, const SizedBox(height: 12)],
    ],
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });
  final String title;
  final String subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => actions.isEmpty
      ? const SizedBox.shrink()
      : Row(mainAxisAlignment: MainAxisAlignment.end, children: actions);
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    this.compact = false,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;
  final bool compact;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.all(compact ? 16 : 42),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              icon,
              size: compact ? 30 : 42,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (title.isNotEmpty) const SizedBox(height: 16),
          if (title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          if (description.isNotEmpty) const SizedBox(height: 8),
          if (description.isNotEmpty)
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class PreviewPrivacy extends InheritedWidget {
  const PreviewPrivacy({
    super.key,
    required this.enabled,
    required super.child,
  });
  final bool enabled;
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreviewPrivacy>()?.enabled ??
      false;
  @override
  bool updateShouldNotify(PreviewPrivacy oldWidget) =>
      enabled != oldWidget.enabled;
}

class MediaArt extends StatelessWidget {
  const MediaArt({
    super.key,
    required this.entry,
    this.width,
    this.height,
    this.radius = 12,
  });
  final MediaEntry? entry;
  final double? width;
  final double? height;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer,
            colors.secondaryContainer.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          entry?.isAudio == true
              ? Icons.graphic_eq_rounded
              : Icons.landscape_rounded,
          size: height != null && height! < 80 ? 24 : 46,
          color: colors.primary.withValues(alpha: 0.6),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ImageFiltered(
        enabled: PreviewPrivacy.of(context),
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 18,
          sigmaY: 18,
          tileMode: ui.TileMode.clamp,
        ),
        child: entry?.preview == null
            ? fallback
            : Image.file(
                File(entry!.preview!),
                width: width,
                height: height,
                fit: BoxFit.cover,
                cacheWidth: 640,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class RoundedSelect<T> extends StatelessWidget {
  const RoundedSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
    this.icon,
  });
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      for (final e in options.entries)
        MenuItemButton(
          leadingIcon: Icon(
            value == e.key ? Icons.check_rounded : null,
            size: 18,
          ),
          onPressed: () => onSelected(e.key),
          child: Text(e.value),
        ),
    ],
    builder: (context, controller, child) => OutlinedButton(
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Text(options[value] ?? ''),
          const SizedBox(width: 8),
          const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
    ),
  );
}

Future<String?> askName(
  BuildContext context, {
  String title = '保存播放列表',
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: '列表名称'),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  // The dialog route may still animate after its result completes.
  Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
  return result;
}

String formatBytes(int value) => value >= 1073741824
    ? '${(value / 1073741824).toStringAsFixed(1)} GB'
    : '${(value / 1048576).toStringAsFixed(1)} MB';
String clockLabel(Duration value) {
  final seconds = value.inSeconds.clamp(0, 999999);
  return '${seconds >= 3600 ? '${seconds ~/ 3600}:' : ''}${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
