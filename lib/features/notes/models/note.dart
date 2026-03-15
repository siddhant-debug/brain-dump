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

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as int,
      content: json['content'] as String,
      title: json['title'] as String?,
      locationName: json['location_name'] as String?,
      musicTrack: json['music_track'] as String?,
      focusMode: json['focus_mode'] as String?,
      sentiment: json['sentiment'] as String?,
      isFavorite: json['is_favorite'] as bool? ?? false,
      categories: (json['categories'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
