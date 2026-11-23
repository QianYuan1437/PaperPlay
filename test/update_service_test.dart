import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/services/update_service.dart';

void main() {
  test('compares stable semantic versions numerically', () {
    expect(UpdateService.isNewer('v1.0.10', '1.0.9'), isTrue);
    expect(UpdateService.isNewer('v2.0.0', '1.99.99'), isTrue);
    expect(UpdateService.isNewer('v1.0.1', '1.0.1+2'), isFalse);
    expect(UpdateService.isNewer('v1.0.0', '1.0.1'), isFalse);
    expect(
      () => UpdateService.isNewer('v2.0.0-beta', '1.0.1'),
      throwsFormatException,
    );
  });
  test('deduplicates checks and provides an official release link', () async {
    final result = Completer<Map<String, dynamic>>();
    var requests = 0;
    final service = UpdateService(
      currentVersion: '1.0.1',
      fetch: () {
        requests++;
        return result.future;
      },
    );
    final pending = service.check();
    await service.check();
    expect(requests, 1);
    expect(service.status, UpdateStatus.checking);
    result.complete({'tag_name': 'v1.0.10'});
    await pending;
    expect(service.status, UpdateStatus.available);
    expect(
      service.releaseUrl.toString(),
      'https://github.com/QianYuan1437/PaperPlay/releases/tag/v1.0.10',
    );
    service.dispose();
  });
  test('handles latest, network failures, malformed data and retry', () async {
    var calls = 0;
    final service = UpdateService(
      currentVersion: '1.0.1',
      fetch: () async {
        calls++;
        if (calls == 1) throw const HttpException('GitHub 请求受限，请稍后重试');
        if (calls == 2) return {'tag_name': 'invalid'};
        if (calls == 3) throw TimeoutException('offline');
        return {'tag_name': 'v1.0.1'};
      },
    );
    for (var i = 0; i < 3; i++) {
      await service.check();
      expect(service.status, UpdateStatus.failed);
      expect(service.releaseUrl, isNull);
    }
    await service.check();
    expect(service.status, UpdateStatus.current);
    service.dispose();
  });
}
