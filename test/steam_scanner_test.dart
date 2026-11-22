import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:paperplay/services/steam_scanner.dart';

void main() {
  test(
    'Valve KeyValues handles modern, legacy, comments and escaped paths',
    () {
      final parsed =
          parseVdf(r'''
      "libraryfolders" {
        // library paths
        "0" { "path" "D:\\Steam" "apps" { "431960" "100" } }
        "1" "E:\\Games"
        "2" { "path" "F:\\游戏 库" }
      }
    ''')['libraryfolders']
              as Map;
      expect(parsed['0']['path'], r'D:\Steam');
      expect(parsed['1'], r'E:\Games');
      expect(parsed['2']['path'], r'F:\游戏 库');
    },
  );

  late Directory temporary;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('paperplay-scan-');
  });
  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  Future<Directory> project(String id, Map<String, dynamic> data) async {
    final dir = await Directory(
      p.join(temporary.path, '431960', id),
    ).create(recursive: true);
    await File(
      p.join(dir.path, 'project.json'),
    ).writeAsString(jsonEncode(data));
    return dir;
  }

  test(
    'imports only declared video projects and rejects missing or escaping paths',
    () async {
      final valid = await project('1', {
        'type': 'video',
        'title': '中文 标题',
        'file': 'clip.mp4',
        'preview': 'cover.jpg',
        'tags': ['Nature'],
      });
      await File(p.join(valid.path, 'clip.mp4')).writeAsBytes([1, 2]);
      await File(p.join(valid.path, 'cover.jpg')).writeAsBytes([3]);
      final scene = await project('2', {'type': 'scene', 'file': 'scene.pkg'});
      await File(p.join(scene.path, 'incidental.mp4')).writeAsBytes([1]);
      await project('3', {'type': 'video', 'file': 'missing.mp4'});
      await project('4', {'type': 'video', 'file': '../outside.mp4'});
      await File(
        p.join(temporary.path, '431960', 'outside.mp4'),
      ).writeAsBytes([1]);
      final broken = await project('5', {});
      await File(
        p.join(broken.path, 'project.json'),
      ).writeAsString('{bad json');
      final result = await SteamScanner.scanRoots([
        p.join(temporary.path, '431960'),
      ]);
      expect(result.items, hasLength(1));
      expect(result.items.single.title, '中文 标题');
      expect(result.items.single.bytes, 2);
      expect(result.items.single.preview, endsWith('cover.jpg'));
      expect(result.skipped, 1);
      expect(result.warnings, hasLength(3));
    },
  );
  test('discovers a manual Steam installation and its other libraries', () async {
    final first = await Directory(
      p.join(temporary.path, 'Steam', 'steamapps'),
    ).create(recursive: true);
    final other = p.join(temporary.path, 'Other Library');
    final root = await Directory(
      p.join(other, 'steamapps', 'workshop', 'content', '431960'),
    ).create(recursive: true);
    await File(p.join(first.path, 'libraryfolders.vdf')).writeAsString(
      '"libraryfolders" { "0" { "path" "${other.replaceAll('\\', '\\\\')}" } }',
    );
    final roots = await SteamScanner().discoverRoots([first.parent.path]);
    expect(roots, contains(root.path));
  });
  test(
    'local recursive import accepts audio and deduplicates overlaps',
    () async {
      final sub = await Directory(p.join(temporary.path, 'nested')).create();
      final audio = File(p.join(sub.path, '音乐.MP3'));
      await audio.writeAsBytes([1]);
      await File(p.join(temporary.path, 'ignore.txt')).writeAsString('ignored');
      final result = await SteamScanner.importLocal([
        temporary.path,
        audio.path,
      ]);
      expect(result.items, hasLength(1));
      expect(result.items.single.isAudio, isTrue);
    },
  );
}
