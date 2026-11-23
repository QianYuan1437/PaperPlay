# PaperPlay

Windows 上的 **Wallpaper Engine 视频订阅管理器与本地影音播放器**。基于 Flutter，界面沿用 [OpenSpeak](https://github.com/QianYuan1437/OpenSpeak) 的圆角卡片与主题系统。

[下载 Windows 版](https://github.com/QianYuan1437/PaperPlay/releases/latest) · [官方网站](https://QianYuan1437.github.io/PaperPlay/) · [全部 Release](https://github.com/QianYuan1437/PaperPlay/releases)

## 功能

- **订阅管理**：自动读取 Steam 注册表和 `libraryfolders.vdf`，发现多个库中的 `steamapps/workshop/content/431960`；读取 `project.json` 视频项目、预览、标题和标签。缓存浏览、搜索、收藏、排序、批量操作。
- **播放队列**：视频或纯音频模式；顺序播放（末尾停止）、随机播放（避免连续重复）、单曲循环、列表循环；拖动排序、上一首/下一首、保存/重命名/更新/删除播放列表。
- **视频播放**：使用 media_kit / libmpv，支持播放暂停、进度、音量、全屏。纯音频模式禁用视频轨道。托盘支持恢复窗口、暂停、切歌和退出。
- **本地媒体**：导入文件或递归导入文件夹，支持 MP4、MKV、WebM、MOV、AVI 等视频和 MP3、FLAC、WAV、M4A、OGG 等音频，共享收藏与播放列表。
- **统一外观**：八种主题色、浅色/深色/跟随系统；卡片、菜单、下拉项与对话框统一圆角。
- **预览隐私**：标题栏、设置和媒体列表中的「模糊预览」同步，覆盖所有封面与视频画面，控件保持清晰并持久保存；不会改变原始媒体文件。
- **紧凑布局**：默认 1040×700，按屏幕工作区域和 DPI 自动收缩；等高概览卡片、双栏设置，窄窗口自动适配。
- **检查更新**：设置中手动检查 GitHub 最新正式 Release；点击侧栏版本号可直接跳转并检查，发现更新后打开发布页下载；匿名 API 限流时自动使用官方 Release 页面作为备用检查路径。
- **统一图标**：浅黄色背景、透明外缘、双齿轮轮廓与放大播放符号。应用内、任务栏与托盘图标按播放引擎状态显示三角 / 暂停；桌面快捷方式使用静态品牌图标。

## v1.0.2

修复纯音频播放期间模糊开关的渲染闪烁，统一所有模糊开关。进度拖动改为本地预览、松手后单次跳转，避免旧播放位置拉回滑块；进度条独立重绘，收藏等无关操作复用现有主题。

原生回归测试逐帧比较静止按钮的像素，覆盖实际音频播放；组件测试验证拖动跳转、失效跳转恢复和周边页面重绘隔离。调试测试可设置 `PAPERPLAY_TEST_INSTANCE=1`，使用独立互斥锁与临时媒体库，与已运行的正式版共存；正式版仍保持单实例。

## 使用

1. 下载安装版 EXE，或把便携 ZIP **完整解压**，运行 `paperplay.exe`。请保留全部 DLL 与 `data` 文件夹。
2. 启动后自动扫描 Steam。无结果时，在设置中添加 Steam 根目录、库目录或 `431960` 文件夹，然后扫描。
3. 在订阅库选择媒体，播放或加入队列。队列可拖动排序，并保存为命名列表；要编辑已存列表，加载后调整队列，再选择「用当前队列更新」。
4. 点击「只听声音」关闭视频轨道；标题栏「收起到托盘」隐藏窗口并继续播放。默认关闭窗口也收起到托盘，从托盘菜单退出。

扫描仅包含本机已下载且 `type=video` 的项目。scene、web、application 不作为视频播放，不解包 `scene.pkg`。Steam 负责下载与订阅更新；本应用不查询在线订阅状态。缓存可能包含已取消订阅或暂时离线的项目，播放时自动跳过缺失文件，也可手动移出记录。移出记录**不删除磁盘文件、不取消订阅**，再次扫描会重新发现仍在磁盘中的项目。

无音轨的视频不会凭空产生声音。播放支持程度取决于文件编码与随包的 libmpv 解码能力。

## 构建与验证

需要 Flutter **3.41.7**、Visual Studio C++ 桌面开发工具及 Windows SDK；安装包需要 Inno Setup 6。

```powershell
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter test integration_test/playback_test.dart -d windows --dart-define="TEST_MEDIA=$((Get-Location).Path)/test/fixtures/sample.mp4"
flutter test integration_test/interaction_test.dart -d windows --dart-define="TEST_MEDIA=$((Get-Location).Path)/test/fixtures/sample.mp4"
flutter build windows --release
./tool/package.ps1 -Version 1.0.2
```

只保留 `windows/` 平台；Pages 是独立静态介绍站，不是 Flutter Web。测试视频由 FFmpeg 的 `testsrc2` 与 `sine` 合成，不包含用户订阅内容。

`Windows CI` 检查格式、静态分析、单元/组件测试、原生播放器/托盘集成测试并编译 Windows。`Windows Release` 可在 Actions 手动输入 `X.Y.Z` 触发，或推送 `vX.Y.Z` 标签；每次发布新版本，保留历史 Release，不覆盖既有发布。

Release 包含便携 ZIP、Inno Setup 安装包、SHA-256 校验、构建信息以及 GitHub 自动提供的源代码归档。ZIP 包含完整 Flutter Release 目录、原生播放库和许可证。仓库首次部署 Pages 时设置 **Settings → Pages → Source: GitHub Actions**。

## 数据与代码

设置、媒体缓存、收藏、列表及队列保存在系统应用支持目录中的 `library.json`，可从设置「打开数据目录」访问。写入串行化，保留 `.bak`；损坏时尝试恢复备份。启动恢复队列但不会自动播放。每个用户只运行一个实例，避免多进程写入冲突。

| 目录 | 内容 |
| --- | --- |
| `lib/services/steam_scanner.dart` | Steam 发现、VDF 解析、隔离任务扫描、文件路径校验 |
| `lib/services/playback_controller.dart` | 原生播放、队列与音视频切换 |
| `lib/services/library_store.dart` | 持久化与备份恢复 |
| `lib/ui/` | 概览、媒体库、队列、播放器、设置、共享主题 |
| `test/`、`integration_test/` | 扫描与数据测试、原生播放和窗口测试 |
| `docs/` | GitHub Pages |
| `tool/package.ps1` | 完整 Windows 发布打包 |

## 参考与许可

应用原创代码采用 MIT；复用的 OpenSpeak 主题保留 MIT 署名。Dart 插件与原生二进制各自适用其许可证，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) 和发行包 `licenses/`。播放器直接复用成熟组件，没有复制其他项目的媒体内容。

- [OpenSpeak](https://github.com/QianYuan1437/OpenSpeak)：主题实现与视觉风格。
- [media_kit](https://github.com/media-kit/media-kit)：Flutter 视频/音频播放。
- [window_manager](https://github.com/leanflutter/window_manager)、[tray_manager](https://github.com/leanflutter/tray_manager)：Windows 窗口与系统托盘。
- [Steam Deck Wallpaper bridge](https://github.com/DavisSolomon/Stream-Deck-Wallpaper-Engine)：参考其文档中的 Steam Workshop 目录约定；扫描实现为本项目原创。

PaperPlay 与 Valve / Wallpaper Engine 无隶属关系，不分发用户媒体。
