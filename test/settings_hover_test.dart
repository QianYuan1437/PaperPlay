import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/app_state.dart';
import 'package:paperplay/models/video_loading.dart';
import 'package:paperplay/services/library_store.dart';
import 'package:paperplay/services/playback_controller.dart';
import 'package:paperplay/ui/settings_page.dart';
import 'package:paperplay/ui/theme.dart';

class _Playback extends ChangeNotifier implements PlaybackController {
  @override
  VideoLoading loadingMode = VideoLoading.memory;
  @override
  int videoCacheMiB = 256;
  @override
  Future<void> setLoading(VideoLoading value, {int? cacheMiB}) async {}
  @override
  VoidCallback? onPersist;
  @override
  bool get audioOnly => false;
  @override
  Future<void> setAudioOnly(bool value) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'settings hover shape encloses labels with rounded-edge clearance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1040, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final playback = _Playback();
      final app = AppState(LibraryStore(File('unused.json')), playback);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(brightness),
            home: Scaffold(body: SettingsPage(app: app)),
          ),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        for (final label in ['模糊预览', '启动时自动扫描', '关闭窗口时收起到托盘', '纯音频模式']) {
          final title = find.text(label);
          await tester.ensureVisible(title);
          await mouse.moveTo(tester.getCenter(title));
          await tester.pumpAndSettle();
          final ink = find
              .ancestor(of: title, matching: find.byType(InkWell))
              .first;
          final textRect = tester.getRect(title);
          final highlight = tester.getRect(ink).deflate(8);
          expect(
            highlight.contains(textRect.topLeft),
            isTrue,
            reason: '$label left/top clipped',
          );
          expect(
            highlight.contains(textRect.bottomRight),
            isTrue,
            reason: '$label right/bottom clipped',
          );
        }
        await mouse.removePointer();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
      playback.dispose();
    },
  );
}
