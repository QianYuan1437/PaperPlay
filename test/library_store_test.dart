import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:paperplay/services/library_store.dart';

void main() {
  late Directory directory;
  late LibraryStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('paperplay-store-');
    store = LibraryStore(File(p.join(directory.path, 'library.json')));
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test('overlapping writes serialize and retain a backup', () async {
    await Future.wait([
      store.save({'name': '一'}),
      store.save({'name': '二'}),
      store.save({'name': '三'}),
    ]);
    expect((await store.load())['name'], '三');
    expect(await File('${store.file.path}.bak').exists(), isTrue);
  });
  test('corrupted primary recovers previous intact snapshot', () async {
    await store.save({'name': 'healthy'});
    await store.save({'name': 'latest'});
    await store.file.writeAsString('{broken');
    expect((await store.load())['name'], 'healthy');
    expect(store.recoveryMessage, contains('恢复'));
    await store.save({'name': 'recovered'});
    expect(await File('${store.file.path}.corrupt').exists(), isTrue);
  });
}
