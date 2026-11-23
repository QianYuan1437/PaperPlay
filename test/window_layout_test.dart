import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/services/window_layout.dart';

void main() {
  test('default window fits normal and high-DPI logical work areas', () {
    expect(initialWindowSize(const Size(1920, 1040)), const Size(1040, 700));
    for (final area in [
      const Size(1280, 680),
      const Size(911, 480),
      const Size(720, 430),
    ]) {
      final window = initialWindowSize(area);
      expect(window.width, lessThan(area.width));
      expect(window.height, lessThan(area.height));
    }
  });
}
