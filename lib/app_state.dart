import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'models/media_entry.dart';
import 'models/queue_order.dart';
import 'services/library_store.dart';
import 'services/update_service.dart';
import 'services/playback_controller.dart';
import 'services/steam_scanner.dart';
import 'ui/theme.dart';

class AppState extends ChangeNotifier {
  AppState(this.store, this.playback, {UpdateService? updates})
    : updates = updates ?? UpdateService() {
    playback.onPersist = persist;
  }
  final UpdateService updates;
  final LibraryStore store;
  final PlaybackController playback;
  final SteamScanner scanner = SteamScanner();
  List<MediaEntry> subscriptions = [];
  List<MediaEntry> local = [];
  List<String> manualRoots = [];
  List<String> detectedRoots = [];
  final Set<String> favorites = {};
  final List<SavedPlaylist> playlists = [];
  ThemeMode themeMode = ThemeMode.system;
  int accent = kDefaultAccent;
  bool closeToTray = true;
  bool autoScan = true;
  bool blurPreviews = false;
  bool busy = false;
  String? message;
  List<String> warnings = [];
  DateTime? lastScan;
  double restoredVolume = 70;

  Future<void> initialize() async {
    final data = await store.load();
    message = store.recoveryMessage;
    try {
      List<MediaEntry> entries(String key) => (data[key] as List? ?? [])
          .map((e) => MediaEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      subscriptions = entries('subscriptions');
      local = entries('local');
      manualRoots = (data['manualRoots'] as List? ?? []).cast<String>();
      favorites.addAll((data['favorites'] as List? ?? []).cast<String>());
      playlists.addAll(
        (data['playlists'] as List? ?? []).map(
          (e) => SavedPlaylist.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
      accent = data['accent'] as int? ?? kDefaultAccent;
      themeMode = ThemeMode.values.byName(data['theme'] as String? ?? 'system');
      closeToTray = data['closeToTray'] as bool? ?? true;
      autoScan = data['autoScan'] as bool? ?? true;
      blurPreviews = data['blurPreviews'] as bool? ?? false;
      lastScan = DateTime.tryParse(data['lastScan'] as String? ?? '');
      playback.queue.addAll(entries('queue'));
      playback.index = (data['queueIndex'] as int? ?? 0).clamp(
        0,
        playback.queue.isEmpty ? 0 : playback.queue.length - 1,
      );
      playback.mode = PlayMode.values.byName(
        data['playMode'] as String? ?? 'repeatAll',
      );
      playback.audioOnly = data['audioOnly'] as bool? ?? false;
      restoredVolume = (data['volume'] as num? ?? 70).toDouble().clamp(0, 100);
    } catch (e) {
      message = '部分设置无法恢复：$e';
    }
    notifyListeners();
  }

  // VideoController initializes after the first Flutter frame. Never await a
  // native player operation before runApp/pumpWidget: that deadlocks startup.
  Future<void> initializePlayback() =>
      playback.player.setVolume(restoredVolume);

  Map<String, dynamic> snapshot() => {
    'subscriptions': subscriptions.map((e) => e.toJson()).toList(),
    'local': local.map((e) => e.toJson()).toList(),
    'manualRoots': manualRoots,
    'favorites': favorites.toList(),
    'playlists': playlists.map((e) => e.toJson()).toList(),
    'accent': accent,
    'theme': themeMode.name,
    'closeToTray': closeToTray,
    'autoScan': autoScan,
    'blurPreviews': blurPreviews,
    'lastScan': lastScan?.toIso8601String(),
    'queue': playback.queue.map((e) => e.toJson()).toList(),
    'queueIndex': playback.index,
    'playMode': playback.mode.name,
    'audioOnly': playback.audioOnly,
    'volume': playback.player.state.volume,
  };
  void persist() {
    unawaited(save());
  }

  Future<void> save() async {
    try {
      await store.save(snapshot());
    } catch (e) {
      message = '保存失败，请检查数据目录权限：$e';
      notifyListeners();
    }
  }

  void changed() {
    notifyListeners();
    persist();
  }

  void dismissMessage() {
    message = null;
    notifyListeners();
  }

  void favorite(MediaEntry entry) {
    if (!favorites.add(entry.id)) favorites.remove(entry.id);
    changed();
  }

  Future<void> scan() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      detectedRoots = await scanner.discoverRoots(manualRoots);
      if (detectedRoots.isEmpty) {
        message = '没有找到订阅目录。请在设置中添加 Steam 库或 431960 文件夹';
        return;
      }
      final result = await scanner.scan(detectedRoots);
      warnings = result.warnings;
      // Retain cached items from temporarily disconnected libraries or failed reads.
      final byId = {for (final e in subscriptions) e.id: e};
      for (final e in result.items) {
        byId[e.id] = e;
      }
      subscriptions = byId.values.toList();
      lastScan = DateTime.now();
      message =
          '发现 ${result.items.length} 个视频 · 跳过 ${result.skipped} 个非视频项目'
          '${warnings.isEmpty ? '' : ' · ${warnings.length} 项异常（设置中查看）'}';
      persist();
    } catch (e) {
      message = '扫描失败：$e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> import(List<String> paths) async {
    if (busy || paths.isEmpty) return;
    busy = true;
    notifyListeners();
    try {
      final result = await Isolate.run(() => SteamScanner.importLocal(paths));
      final byId = {for (final e in local) e.id: e};
      for (final item in result.items) {
        byId[item.id] = item;
      }
      local = byId.values.toList();
      warnings = result.warnings;
      message =
          '已导入 ${result.items.length} 个媒体文件${warnings.isEmpty ? '' : '，${warnings.length} 项异常'}';
      persist();
    } catch (e) {
      message = '导入失败：$e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void forget(List<MediaEntry> items) {
    final ids = items.map((e) => e.id).toSet();
    local.removeWhere((e) => ids.contains(e.id));
    subscriptions.removeWhere((e) => ids.contains(e.id));
    favorites.removeAll(ids);
    changed();
  }

  void savePlaylist(String name, List<MediaEntry> items) {
    if (name.trim().isEmpty || items.isEmpty) return;
    playlists.add(
      SavedPlaylist(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        items: List.of(items),
      ),
    );
    changed();
  }
}
