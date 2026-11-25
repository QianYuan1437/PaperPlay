import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/app_state.dart';
import 'package:paperplay/services/desktop_service.dart';
import 'package:paperplay/services/library_store.dart';
import 'package:paperplay/services/playback_controller.dart';

class _Playback extends ChangeNotifier implements PlaybackController {
  final stopped = Completer<void>();
  @override
  VoidCallback? onPersist;
  @override
  Future<void> shutdown() => stopped.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _App extends AppState {
  _App(super.store, super.playback);
  final saved = Completer<void>();
  @override
  Future<void> save() => saved.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'tray quit removes visible UI before slow persistence and decoder cleanup',
    (tester) async {
      final calls = <String>[];
      for (final name in ['window_manager', 'tray_manager']) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(name), (call) async {
              calls.add('$name.${call.method}');
              return null;
            });
      }
      final playback = _Playback();
      final app = _App(LibraryStore(File('unused.json')), playback);
      final desktop = DesktopService(app)..trayReady = true;
      final quit = desktop.quit();
      await tester.pump();
      expect(calls, contains('window_manager.hide'));
      expect(calls, contains('tray_manager.destroy'));
      expect(calls, isNot(contains('window_manager.destroy')));
      app.saved.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await quit;
      expect(
        calls.where((call) => call == 'window_manager.destroy'),
        hasLength(1),
      );
      playback.stopped.complete();
      await tester.pump();
      app.dispose();
      playback.dispose();
    },
  );
}
