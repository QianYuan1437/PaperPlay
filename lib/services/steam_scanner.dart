import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;
import '../models/media_entry.dart';

/// Valve KeyValues, including legacy library entries, comments and escaped paths.
Map<String, dynamic> parseVdf(String text) {
  final tokens = RegExp(r'"(?:\\.|[^"\\])*"|[{}]|//[^\r\n]*|[^\s{}"]+')
      .allMatches(text)
      .map((m) => m.group(0)!)
      .where((t) => !t.startsWith('//'))
      .toList();
  var index = 0;
  String decode(String t) => t.startsWith('"')
      ? t
            .substring(1, t.length - 1)
            .replaceAll(r'\\', r'\')
            .replaceAll(r'\"', '"')
      : t;
  Map<String, dynamic> object() {
    final result = <String, dynamic>{};
    while (index < tokens.length) {
      final key = tokens[index++];
      if (key == '}') break;
      if (index >= tokens.length) break;
      final value = tokens[index++];
      result[decode(key).toLowerCase()] = value == '{'
          ? object()
          : decode(value);
    }
    return result;
  }

  return object();
}

class ScanResult {
  ScanResult(this.items, this.roots, this.warnings, this.skipped);
  final List<MediaEntry> items;
  final List<String> roots;
  final List<String> warnings;
  final int skipped;
}

class SteamScanner {
  Future<List<String>> discoverRoots(List<String> manual) async {
    final candidates = <String>{...manual};
    if (Platform.isWindows) {
      for (final key in [
        r'HKCU\Software\Valve\Steam',
        r'HKLM\SOFTWARE\WOW6432Node\Valve\Steam',
      ]) {
        try {
          final result = await Process.run('reg.exe', [
            'query',
            key,
          ], stdoutEncoding: systemEncoding);
          for (final m in RegExp(
            r'(?:SteamPath|InstallPath)\s+REG_SZ\s+(.+)',
            caseSensitive: false,
          ).allMatches('${result.stdout}')) {
            candidates.add(m.group(1)!.trim());
          }
        } catch (_) {
          /* Default and manual paths remain available. */
        }
      }
    }
    for (final name in ['ProgramFiles(x86)', 'ProgramFiles']) {
      final base = Platform.environment[name];
      if (base != null) candidates.add(p.join(base, 'Steam'));
    }
    final libraries = <String>{...candidates};
    for (final root in candidates) {
      for (final file in [
        p.join(root, 'steamapps', 'libraryfolders.vdf'),
        p.join(root, 'config', 'libraryfolders.vdf'),
      ]) {
        try {
          final data = parseVdf(
            await File(file).readAsString(),
          )['libraryfolders'];
          if (data is! Map) continue;
          for (final entry in data.entries) {
            if (entry.value is Map && entry.value['path'] is String) {
              libraries.add(entry.value['path'] as String);
            } else if (int.tryParse('${entry.key}') != null &&
                entry.value is String) {
              libraries.add(entry.value as String);
            }
          }
        } on FileSystemException {
          /* Other Steam installations may be valid. */
        }
      }
    }
    final roots = <String, String>{};
    for (final library in libraries) {
      final options = [
        library,
        p.join(library, 'steamapps', 'workshop', 'content', '431960'),
        p.join(library, 'workshop', 'content', '431960'),
        p.join(library, 'content', '431960'),
      ];
      for (final root in options) {
        if (p.basename(root) == '431960' && await Directory(root).exists()) {
          roots[pathKey(root)] = p.normalize(root);
        }
      }
    }
    return roots.values.toList();
  }

  Future<ScanResult> scan(List<String> roots) =>
      Isolate.run(() => scanRoots(roots));

  static Future<ScanResult> scanRoots(List<String> roots) async {
    final items = <String, MediaEntry>{};
    final warnings = <String>[];
    var skipped = 0;
    for (final root in roots) {
      try {
        await for (final dir in Directory(root).list(followLinks: false)) {
          if (dir is! Directory) continue;
          final project = File(p.join(dir.path, 'project.json'));
          if (!await project.exists()) {
            skipped++;
            continue;
          }
          try {
            final decoded = jsonDecode(
              (await project.readAsString()).replaceFirst('\uFEFF', ''),
            );
            if (decoded is! Map) {
              throw const FormatException('project.json 不是对象');
            }
            if ('${decoded['type']}'.toLowerCase() != 'video') {
              skipped++;
              continue;
            }
            final path = await _safeFile(dir.path, decoded['file']);
            if (path == null || !videoExtensions.contains(extension(path))) {
              warnings.add('${p.basename(dir.path)}：视频文件缺失或路径无效');
              continue;
            }
            final stat = await File(path).stat();
            final preview = await _safeFile(dir.path, decoded['preview']);
            final title =
                '${decoded['title'] ?? p.basenameWithoutExtension(path)}';
            final item = MediaEntry(
              path: path,
              title: title,
              source: MediaSource.wallpaper,
              preview: preview,
              workshopId: p.basename(dir.path),
              tags: decoded['tags'] is List
                  ? (decoded['tags'] as List).map((e) => '$e').toList()
                  : [],
              bytes: stat.size,
              modified: stat.modified.millisecondsSinceEpoch,
            );
            items[item.id] = item;
          } catch (e) {
            warnings.add('${p.basename(dir.path)}：$e');
          }
        }
      } on FileSystemException catch (e) {
        warnings.add('$root：${e.message}');
      }
    }
    final sorted = items.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return ScanResult(sorted, roots, warnings, skipped);
  }

  static Future<String?> _safeFile(String root, dynamic relative) async {
    if (relative is! String || relative.isEmpty || p.isAbsolute(relative)) {
      return null;
    }
    final file = File(
      p.normalize(p.join(root, relative.replaceAll('\\', p.separator))),
    );
    if (!p.isWithin(p.normalize(root), file.path) || !await file.exists()) {
      return null;
    }
    final resolvedRoot = await Directory(root).resolveSymbolicLinks();
    final resolvedFile = await file.resolveSymbolicLinks();
    return p.isWithin(resolvedRoot.toLowerCase(), resolvedFile.toLowerCase())
        ? file.path
        : null;
  }

  static Future<ScanResult> importLocal(List<String> paths) async {
    final items = <String, MediaEntry>{};
    final warnings = <String>[];
    Future<void> addFile(String path) async {
      if (!{...videoExtensions, ...audioExtensions}.contains(extension(path))) {
        return;
      }
      try {
        final file = File(path);
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file) return;
        final item = MediaEntry(
          path: p.absolute(path),
          title: p.basenameWithoutExtension(path),
          source: MediaSource.local,
          bytes: stat.size,
          modified: stat.modified.millisecondsSinceEpoch,
        );
        items[item.id] = item;
      } on FileSystemException catch (e) {
        warnings.add('$path：${e.message}');
      }
    }

    for (final path in paths) {
      try {
        if (await Directory(path).exists()) {
          await for (final file in Directory(
            path,
          ).list(recursive: true, followLinks: false)) {
            if (file is File) await addFile(file.path);
          }
        } else {
          await addFile(path);
        }
      } on FileSystemException catch (e) {
        warnings.add('$path：${e.message}');
      }
    }
    return ScanResult(items.values.toList(), paths, warnings, 0);
  }
}
