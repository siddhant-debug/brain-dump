class Note {
  final int id;
  final String content;
  final String? title;
  final String? locationName;
  final String? musicTrack;
  final String? focusMode;
  final String? sentiment;
  final bool isFavorite;
  final List<String> categories;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.content,
    this.title,
    this.locationName,
    this.musicTrack,
    this.focusMode,
    this.sentiment,
    this.isFavorite = false,
    this.categories = const [],
    required this.createdAt,
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int,
      content: map['content'] as String,
      title: map['title'] as String?,
      locationName: map['location_name'] as String?,
      musicTrack: map['music_track'] as String?,
      focusMode: map['focus_mode'] as String?,
      sentiment: map['sentiment'] as String?,
      isFavorite: map['is_favorite'] as bool? ?? false,
      categories: (map['categories'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
