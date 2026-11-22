import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/models/queue_order.dart';

void main() {
  test('sequential stops at end while repeat-all wraps', () {
    expect(nextIndex(current: 2, length: 3, mode: PlayMode.sequential), isNull);
    expect(nextIndex(current: 2, length: 3, mode: PlayMode.repeatAll), 0);
    expect(nextIndex(current: 0, length: 0, mode: PlayMode.repeatAll), isNull);
  });
  test('repeat-one repeats on completion but manual next advances', () {
    expect(nextIndex(current: 1, length: 3, mode: PlayMode.repeatOne), 1);
    expect(
      nextIndex(current: 1, length: 3, mode: PlayMode.repeatOne, manual: true),
      2,
    );
  });
  test('shuffle never immediately repeats when alternatives exist', () {
    final random = Random(42);
    for (var i = 0; i < 100; i++) {
      final result = nextIndex(
        current: 2,
        length: 4,
        mode: PlayMode.shuffle,
        random: random,
      );
      expect(result, inInclusiveRange(0, 3));
      expect(result, isNot(2));
    }
    expect(nextIndex(current: 0, length: 1, mode: PlayMode.shuffle), 0);
  });
}
