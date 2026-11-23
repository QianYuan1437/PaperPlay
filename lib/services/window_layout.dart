import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// screen_retriever supplies logical work-area pixels, already adjusted for DPI.
Size initialWindowSize(Size workArea) => Size(
  math.min(1040, workArea.width * .94),
  math.min(700, workArea.height * .94),
);
