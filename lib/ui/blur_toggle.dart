import 'package:flutter/material.dart';
import '../app_state.dart';

class BlurToggle extends StatelessWidget {
  const BlurToggle({super.key, required this.app});
  final AppState app;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: '同步模糊所有封面与视频画面，播放控件保持清晰',
    child: FilterChip(
      avatar: const Icon(Icons.blur_on_rounded, size: 16),
      label: const Text('模糊预览'),
      selected: app.blurPreviews,
      onSelected: (value) {
        app.blurPreviews = value;
        app.changed();
      },
    ),
  );
}
