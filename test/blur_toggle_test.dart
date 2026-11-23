import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/app_state.dart';
import 'package:paperplay/services/library_store.dart';
import 'package:paperplay/services/playback_controller.dart';
import 'package:paperplay/ui/blur_toggle.dart';
import 'package:paperplay/ui/theme.dart';

class _Playback extends ChangeNotifier implements PlaybackController {
  @override
  VoidCallback? onPersist;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _App extends AppState {
  _App() : super(LibraryStore(File('unused.json')), _Playback());
  @override
  void persist() {}
}

void main() {
  testWidgets(
    'blur control pixels remain stable under stationary hover and repeated app updates',
    (tester) async {
      final app = _App();
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: app,
          builder: (context, _) => MaterialApp(
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: SizedBox(
                  height: 38,
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: BlurToggle(app: app),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(BlurToggle)));
      await tester.tap(find.byType(BlurToggle));
      await tester.pumpAndSettle();
      Future<List<int>> pixels() async => (await tester.runAsync(() async {
        final image =
            await (boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return bytes!.buffer.asUint8List();
      }))!;
      final baseline = await pixels();
      for (var i = 0; i < 30; i++) {
        app.notifyListeners();
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          await pixels(),
          baseline,
          reason: 'Stationary blur control changed at frame $i',
        );
      }
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    },
  );
}
