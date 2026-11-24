import 'package:flutter/material.dart';
import '../app_state.dart';

class BlurToggle extends StatelessWidget {
  const BlurToggle({super.key, required this.app});
  final AppState app;
  @override
  // Keep playback and animated-cover repaints out of the static control layer.
  Widget build(BuildContext context) => RepaintBoundary(
    child: Tooltip(
      message: '同步模糊所有封面与视频画面，播放控件保持清晰',
      child: FilterChip(
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        avatar: Icon(
          app.blurPreviews ? Icons.blur_on_rounded : Icons.blur_off_rounded,
          size: 16,
        ),
        label: const Text('模糊预览'),
        selected: app.blurPreviews,
        onSelected: (value) {
          app.blurPreviews = value;
          app.changed();
        },
      ),
    ),
  );
}
