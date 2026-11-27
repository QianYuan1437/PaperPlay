enum VideoLoading { disk, memory }

/// Bounds demuxed packet storage, not decoded frames or total process memory.
/// libmpv reads asynchronously; no Dart byte copies or whole-file allocations.
Map<String, String> videoLoadingProperties(VideoLoading mode, int cacheMiB) {
  final budget = [128, 256, 512].contains(cacheMiB) ? cacheMiB : 256;
  final memory = mode == VideoLoading.memory;
  return {
    'cache': memory ? 'yes' : 'no',
    'cache-on-disk': 'no',
    'cache-pause': 'no',
    'demuxer-seekable-cache': memory ? 'yes' : 'no',
    'demuxer-max-bytes': '${(memory ? budget * 3 ~/ 4 : 8) * 1048576}',
    'demuxer-max-back-bytes': '${(memory ? budget ~/ 4 : 0) * 1048576}',
    'demuxer-readahead-secs': memory ? '60' : '1',
    'cache-secs': '60',
    // Decode to the exact target, but don't render every discarded frame.
    'hr-seek-framedrop': 'yes',
  };
}
