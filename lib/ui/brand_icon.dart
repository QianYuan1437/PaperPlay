import 'package:flutter/material.dart';
import '../services/playback_controller.dart';

/// Same artwork as the executable, taskbar, tray and website; never guesses state.
class BrandIcon extends StatelessWidget {
  const BrandIcon({super.key, required this.playback, this.size = 40});
  final PlaybackController playback;
  final double size;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, _) => Semantics(
      label: playback.playing ? 'PaperPlay 正在播放' : 'PaperPlay 已暂停',
      child: Image.asset(
        playback.playing ? 'assets/logo_playing.png' : 'assets/logo.png',
        width: size,
        height: size,
        gaplessPlayback: true,
      ),
    ),
  );
}
