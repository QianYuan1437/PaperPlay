import 'package:path/path.dart' as p;

enum MediaSource { wallpaper, local }

const videoExtensions = {
  'mp4',
  'mkv',
  'webm',
  'mov',
  'avi',
  'wmv',
  'm4v',
  'mpg',
  'mpeg',
  'ts',
};
const audioExtensions = {
  'mp3',
  'flac',
  'wav',
  'aac',
  'm4a',
  'ogg',
  'opus',
  'wma',
};
String pathKey(String value) => p.normalize(p.absolute(value)).toLowerCase();
String extension(String value) =>
    p.extension(value).replaceFirst('.', '').toLowerCase();

class MediaEntry {
  const MediaEntry({
    required this.path,
    required this.title,
    required this.source,
    this.preview,
    this.workshopId,
    this.tags = const [],
    this.bytes = 0,
    this.modified = 0,
  });
  final String path;
  final String title;
  final MediaSource source;
  final String? preview;
  final String? workshopId;
  final List<String> tags;
  final int bytes;
  final int modified;
  String get id => pathKey(path);
  bool get isAudio => audioExtensions.contains(extension(path));
  String get format => extension(path).toUpperCase();

  Map<String, dynamic> toJson() => {
    'path': path,
    'title': title,
    'source': source.name,
    'preview': preview,
    'workshopId': workshopId,
    'tags': tags,
    'bytes': bytes,
    'modified': modified,
  };
  factory MediaEntry.fromJson(Map<String, dynamic> j) => MediaEntry(
    path: j['path'] as String,
    title: j['title'] as String,
    source: j['source'] == 'wallpaper'
        ? MediaSource.wallpaper
        : MediaSource.local,
    preview: j['preview'] as String?,
    workshopId: j['workshopId'] as String?,
    tags: (j['tags'] as List? ?? []).cast<String>(),
    bytes: j['bytes'] as int? ?? 0,
    modified: j['modified'] as int? ?? 0,
  );
}

class SavedPlaylist {
  SavedPlaylist({required this.id, required this.name, required this.items});
  final String id;
  String name;
  List<MediaEntry> items;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((e) => e.toJson()).toList(),
  };
  factory SavedPlaylist.fromJson(Map<String, dynamic> j) => SavedPlaylist(
    id: j['id'] as String,
    name: j['name'] as String,
    items: (j['items'] as List)
        .map((e) => MediaEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}
