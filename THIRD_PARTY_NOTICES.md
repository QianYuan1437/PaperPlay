# Third-party notices

PaperPlay application code is Copyright (c) 2026 QianYuan1437, MIT licensed (see LICENSE). This does not relicense third-party components or media files.

## OpenSpeak

`lib/ui/theme.dart` is adapted from [QianYuan1437/OpenSpeak](https://github.com/QianYuan1437/OpenSpeak/blob/main/lib/ui/theme.dart), commit `9c81f34213cac211cf948a4002fdf7710fb24f67`. Copyright (c) 2026 QianYuan1437, MIT. The complete permission and warranty notice is reproduced in this repository's LICENSE.

## Playback and desktop dependencies

- [media_kit](https://github.com/media-kit/media-kit), media_kit_video and media_kit_libs_windows_video: Copyright © 2021 & onwards, Hitesh Kumar Saini; MIT for the Dart/Flutter wrapper. Native libraries have separate licenses.
  PaperPlay backports the Windows texture synchronization portions of [PR #1468](https://github.com/media-kit/media-kit/pull/1468), contributed by freeKC under MIT, to media_kit_video 2.0.1. The modified sources, provenance and license are in `windows/third_party/media_kit_video/`.
- [window_manager](https://github.com/leanflutter/window_manager) and [tray_manager](https://github.com/leanflutter/tray_manager): LeanFlutter contributors, MIT.
- [file_picker](https://github.com/miguelpruivo/flutter_file_picker): MIT.
- [flutter_acrylic](https://github.com/alexmercerind/flutter_acrylic) 1.1.4: Hitesh Kumar Saini and contributors, MIT. Used for native Windows transparency, acrylic and mica; its license is included in the packaged dependency notices.
- Flutter SDK and Flutter-maintained path, path_provider, url_launcher packages: respective BSD-style licenses.

The packaging script includes the LICENSE files from all resolved packages under `licenses/`. Dependency versions are pinned by `pubspec.lock`; full plugin sources can be obtained from the package repository URLs and corresponding pub.dev version archives.

## Native media libraries

media_kit_libs_windows_video 1.0.11 downloads the unmodified `mpv-dev-x86_64-20230924-git-652a1dd.7z` distribution from [media-kit/libmpv-win32-video-build release 2023-09-24](https://github.com/media-kit/libmpv-win32-video-build/releases/tag/2023-09-24), and ANGLE v1.0.1 from [flutter-windows-ANGLE-OpenGL-ES](https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/tag/v1.0.1).

mpv, FFmpeg and related native components carry their own GPL/LGPL/BSD and other notices, depending on their build configuration; they are not covered by PaperPlay's MIT license. Original native LICENSE/COPYING files are preserved by `tool/package.ps1`. Native source and build recipes are available in [libmpv-win32-video-build](https://github.com/media-kit/libmpv-win32-video-build), [mpv](https://github.com/mpv-player/mpv), [FFmpeg](https://github.com/FFmpeg/FFmpeg), and [ANGLE](https://github.com/google/angle). The bundled DLL is dynamically loaded, unmodified; users may replace it with a compatible build.

## Reference only

[Moriafly/SaltUI](https://github.com/Moriafly/SaltUI) (Apache-2.0) is a visual reference for rounded, translucent surfaces. PaperPlay does not include SaltUI's Kotlin code or artwork.

[DavisSolomon/Stream-Deck-Wallpaper-Engine](https://github.com/DavisSolomon/Stream-Deck-Wallpaper-Engine) documents the Workshop path convention. No code or artwork was copied from that project.

The test fixtures `test/fixtures/sample.mp4` and its audio-free derivative `silent.mp4` are generated from FFmpeg's synthetic test pattern and sine-wave generator. No Steam subscriptions, personal files, or copyrighted wallpaper artwork are included in this repository or its downloads.
