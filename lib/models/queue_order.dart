import 'dart:math';

enum PlayMode { sequential, shuffle, repeatOne, repeatAll }

/// Pure transition logic; playback errors advance even when repeat-one is enabled.
int? nextIndex({
  required int current,
  required int length,
  required PlayMode mode,
  bool manual = false,
  Random? random,
}) {
  if (length == 0) return null;
  if (mode == PlayMode.repeatOne && !manual) {
    return current.clamp(0, length - 1);
  }
  if (mode == PlayMode.shuffle) {
    if (length == 1) return 0;
    final n = (random ?? Random()).nextInt(length - 1);
    return n >= current ? n + 1 : n;
  }
  if (current + 1 < length) return current + 1;
  return mode == PlayMode.repeatAll || manual ? 0 : null;
}
