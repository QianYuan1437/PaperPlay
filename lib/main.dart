import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'app_state.dart';
import 'services/desktop_service.dart';
import 'services/library_store.dart';
import 'services/playback_controller.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('正在打开 PaperPlay…'),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    await launchPaperPlay();
  } catch (error) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 42),
                  const SizedBox(height: 16),
                  const Text('PaperPlay 启动失败'),
                  const SizedBox(height: 12),
                  SelectableText('$error'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => windowManager.destroy(),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> launchPaperPlay() async {
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  final app = AppState(
    LibraryStore(File(p.join(directory.path, 'library.json'))),
    PlaybackController(),
  );
  await app.initialize();
  final desktop = DesktopService(app);
  await desktop.initialize();
  runApp(PaperPlayApp(app: app, desktop: desktop));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(app.initializePlayback());
  });
  await windowManager.waitUntilReadyToShow(DesktopService.options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  if (app.autoScan) unawaited(app.scan());
}

class PaperPlayApp extends StatelessWidget {
  const PaperPlayApp({super.key, required this.app, required this.desktop});
  final AppState app;
  final DesktopService desktop;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app,
    builder: (context, _) => MaterialApp(
      title: 'PaperPlay',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, accent: app.accent),
      darkTheme: buildTheme(Brightness.dark, accent: app.accent),
      themeMode: app.themeMode,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) =>
          PreviewPrivacy(enabled: app.blurPreviews, child: child!),
      home: AppShell(app: app, desktop: desktop),
    ),
  );
}
