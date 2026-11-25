import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/services/playback_diagnostics.dart';

void main() {
  testWidgets(
    'audio progress does not hide a failed video decoder; recovery clears it',
    (tester) async {
      var seconds = 1, frame = 10.0;
      String? error;
      final diagnostics = PlaybackDiagnostics(
        probe: () async => DecodeProbe(
          position: Duration(seconds: seconds),
          needsVideo: true,
          audioReady: true,
          videoPosition: frame,
        ),
        onError: (value) => error = value,
      );
      diagnostics.report('Could not open codec.');
      await tester.pump();
      seconds++;
      await tester.pump(const Duration(milliseconds: 650));
      expect(error, 'Could not open codec.');
      frame = 20;
      seconds++;
      diagnostics.progress();
      await tester.pump(const Duration(milliseconds: 650));
      expect(error, isNull);
      diagnostics.dispose();
    },
  );

  testWidgets(
    'audio-only recovery needs a working audio decoder; repeats cannot postpone failure',
    (tester) async {
      var seconds = 1;
      var audioReady = false;
      String? error;
      final diagnostics = PlaybackDiagnostics(
        probe: () async => DecodeProbe(
          position: Duration(seconds: seconds),
          needsVideo: false,
          audioReady: audioReady,
        ),
        onError: (value) => error = value,
      );
      diagnostics.report('Could not open codec.');
      await tester.pump();
      for (var i = 0; i < 7; i++) {
        seconds++;
        diagnostics.report('Could not open codec.');
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(error, isNotNull);
      audioReady = true;
      seconds++;
      diagnostics.progress();
      await tester.pump(const Duration(milliseconds: 650));
      expect(error, isNull);
      diagnostics.report('Unrecognized file format');
      expect(error, 'Unrecognized file format');
      diagnostics.reset();
      expect(error, isNull);
      diagnostics.dispose();
    },
  );

  testWidgets(
    'late probes cannot restore errors after a new file or shutdown',
    (tester) async {
      final pending = Completer<DecodeProbe>();
      final errors = <String?>[];
      final diagnostics = PlaybackDiagnostics(
        probe: () => pending.future,
        onError: errors.add,
      );
      diagnostics.report('Could not open codec.');
      diagnostics.reset();
      diagnostics.dispose();
      pending.complete(
        const DecodeProbe(
          position: Duration.zero,
          needsVideo: true,
          audioReady: false,
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(errors, [null]);
    },
  );
}
