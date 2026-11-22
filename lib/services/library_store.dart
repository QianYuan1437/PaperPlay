import 'dart:convert';
import 'dart:io';

/// Serialized writes with an intact previous snapshot if the process is interrupted.
class LibraryStore {
  LibraryStore(this.file);
  final File file;
  Future<void> _pending = Future.value();
  String? recoveryMessage;

  Future<Map<String, dynamic>> load() async {
    for (final candidate in [file, File('${file.path}.bak')]) {
      if (!await candidate.exists()) continue;
      try {
        final value = jsonDecode(await candidate.readAsString());
        if (value is! Map<String, dynamic> || value['version'] != 1) {
          throw const FormatException('不支持的数据格式');
        }
        if (candidate.path != file.path) recoveryMessage = '已从备份恢复媒体库';
        return value;
      } catch (_) {
        recoveryMessage = '媒体库数据损坏；原文件已保留，请检查数据目录';
      }
    }
    return {};
  }

  Future<void> save(Map<String, dynamic> value) {
    final encoded = const JsonEncoder.withIndent(
      '  ',
    ).convert({'version': 1, ...value});
    final task = _pending.then((_) async {
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(encoded, flush: true);
      if (await file.exists()) {
        // Never replace a healthy backup with malformed data.
        try {
          jsonDecode(await file.readAsString());
          await file.copy('${file.path}.bak');
        } on FormatException {
          await file.copy('${file.path}.corrupt');
        }
      }
      await temporary.rename(file.path);
    });
    _pending = task.catchError((Object _) {});
    return task;
  }

  Future<void> flush() => _pending;
}
