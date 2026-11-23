import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../app_info.dart';

enum UpdateStatus { idle, checking, current, available, failed }

/// Public release metadata only; downloads remain an explicit browser action.
class UpdateService extends ChangeNotifier {
  UpdateService({
    this.currentVersion = appVersion,
    Future<Map<String, dynamic>> Function()? fetch,
  }) : _fetch = fetch ?? fetchLatest;
  final String currentVersion;
  final Future<Map<String, dynamic>> Function() _fetch;
  UpdateStatus status = UpdateStatus.idle;
  String message = '手动检查 GitHub 上的最新正式版本';
  String? latestVersion;
  Uri? releaseUrl;

  static List<int> versionParts(String value) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:\+[^\s]+)?$',
    ).firstMatch(value);
    if (match == null) throw const FormatException('Invalid stable version');
    return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
  }

  static bool isNewer(String remote, String local) {
    final a = versionParts(remote), b = versionParts(local);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  Future<void> check() async {
    if (status == UpdateStatus.checking) return;
    status = UpdateStatus.checking;
    message = '正在检查更新…';
    releaseUrl = null;
    notifyListeners();
    try {
      final data = await _fetch().timeout(const Duration(seconds: 15));
      if (data['draft'] == true || data['prerelease'] == true) {
        throw const FormatException('Not a stable release');
      }
      final tag = data['tag_name'] as String;
      final newer = isNewer(tag, currentVersion);
      latestVersion = tag.replaceFirst(RegExp('^v'), '');
      releaseUrl = Uri.https(
        'github.com',
        '/QianYuan1437/PaperPlay/releases/tag/$tag',
      );
      status = newer ? UpdateStatus.available : UpdateStatus.current;
      message = newer ? '发现新版本 v$latestVersion' : '当前已是最新版本（v$currentVersion）';
    } on TimeoutException {
      status = UpdateStatus.failed;
      message = '检查超时，请检查网络后重试';
    } on HttpException catch (error) {
      status = UpdateStatus.failed;
      message = error.message;
    } catch (_) {
      status = UpdateStatus.failed;
      message = '暂时无法检查更新，请检查网络后重试';
    }
    notifyListeners();
  }

  static Future<Map<String, dynamic>> fetchLatest() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      return await (() async {
        final request = await client.getUrl(
          Uri.https(
            'api.github.com',
            '/repos/QianYuan1437/PaperPlay/releases/latest',
          ),
        );
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'PaperPlay/$appVersion',
        );
        request.headers.set(
          HttpHeaders.acceptHeader,
          'application/vnd.github+json',
        );
        final response = await request.close();
        if (response.statusCode != 200) {
          throw HttpException(switch (response.statusCode) {
            403 || 429 => 'GitHub 请求受限，请稍后重试',
            404 => '暂未找到正式发布版本',
            _ => '更新服务暂不可用（${response.statusCode}）',
          });
        }
        return jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>;
      })().timeout(const Duration(seconds: 12));
    } finally {
      client.close(force: true);
    }
  }
}
