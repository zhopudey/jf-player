/// One captured scene mark, as POSTed to MODAK (`POST /marks`, JSON array).
enum SceneMarkType { start, end, point, song }

class SceneMark {
  SceneMark({
    required this.id,
    required this.sceneId,
    required this.itemId,
    required this.title,
    required this.positionMs,
    required this.type,
    required this.createdAt,
    this.year,
    this.imdbId,
    this.tmdbId,
    this.note,
    this.synced = false,
  });

  /// Unique per mark (local only; also sent, harmless).
  final String id;

  /// Shared by a start and its end so MODAK can pair them.
  final String sceneId;
  final String itemId;
  final String title;
  final int? year;
  final String? imdbId;
  final String? tmdbId;
  final int positionMs;
  SceneMarkType type;
  final DateTime createdAt;
  String? note;
  bool synced;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sceneId': sceneId,
    'itemId': itemId,
    'title': title,
    'year': year,
    'imdbId': imdbId,
    'tmdbId': tmdbId,
    'positionMs': positionMs,
    'type': type.name,
    'markedAt': createdAt.toUtc().toIso8601String(),
    'note': note,
    'synced': synced,
  };

  factory SceneMark.fromJson(Map<String, dynamic> j) => SceneMark(
    id: j['id'] as String,
    sceneId: j['sceneId'] as String,
    itemId: j['itemId'] as String,
    title: j['title'] as String? ?? '',
    year: j['year'] as int?,
    imdbId: j['imdbId'] as String?,
    tmdbId: j['tmdbId'] as String?,
    positionMs: j['positionMs'] as int,
    type: SceneMarkType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => SceneMarkType.point,
    ),
    createdAt: DateTime.parse(j['markedAt'] as String),
    note: j['note'] as String?,
    synced: j['synced'] as bool? ?? false,
  );
}
