import 'package:flutter_test/flutter_test.dart';
import 'package:paperplay/models/video_loading.dart';

void main() {
  test(
    'memory cache divides a bounded budget between forward and reverse seeks',
    () {
      for (final size in [128, 256, 512]) {
        final options = videoLoadingProperties(VideoLoading.memory, size);
        expect(
          int.parse(options['demuxer-max-bytes']!) +
              int.parse(options['demuxer-max-back-bytes']!),
          size * 1048576,
        );
        expect(options['cache-on-disk'], 'no');
        expect(options['cache-pause'], 'no');
        expect(options['demuxer-seekable-cache'], 'yes');
      }
    },
  );
  test(
    'disk reads use a small buffer and never copy the file to disk cache',
    () {
      final options = videoLoadingProperties(VideoLoading.disk, 512);
      expect(options['cache'], 'no');
      expect(options['cache-on-disk'], 'no');
      expect(options['demuxer-max-bytes'], '${8 * 1048576}');
      expect(options['demuxer-max-back-bytes'], '0');
    },
  );
  test(
    'invalid restored cache capacity cannot create an unbounded allocation',
    () {
      expect(
        videoLoadingProperties(VideoLoading.memory, -1),
        videoLoadingProperties(VideoLoading.memory, 256),
      );
    },
  );
}
