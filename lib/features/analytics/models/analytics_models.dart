class HeatmapDay {
  final String date;
  final int count;

  const HeatmapDay({required this.date, required this.count});

  factory HeatmapDay.fromJson(Map<String, dynamic> json) =>
      HeatmapDay(date: json['date'] as String, count: json['count'] as int);
}

class ConsistencyData {
  final int currentStreak;
  final int longestStreak;
  final int totalNotes;
  final int activeDaysLast30;
  final List<HeatmapDay> heatmap;

  const ConsistencyData({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalNotes,
    required this.activeDaysLast30,
    required this.heatmap,
  });

  factory ConsistencyData.fromJson(Map<String, dynamic> json) =>
      ConsistencyData(
        currentStreak: json['current_streak'] as int,
        longestStreak: json['longest_streak'] as int,
        totalNotes: json['total_notes'] as int,
        activeDaysLast30: json['active_days_last_30'] as int,
        heatmap: (json['heatmap'] as List)
            .map((e) => HeatmapDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ThemeItem {
  final String key;
  final String name;
  final int count;
  final double pct;
  final String sample;

  const ThemeItem({
    required this.key,
    required this.name,
    required this.count,
    required this.pct,
    required this.sample,
  });

  factory ThemeItem.fromJson(Map<String, dynamic> json) => ThemeItem(
    key: json['key'] as String,
    name: json['name'] as String,
    count: json['count'] as int,
    pct: (json['pct'] as num).toDouble(),
    sample: json['sample'] as String,
  );
}

class ThemesData {
  final int windowDays;
  final int totalNotesAnalyzed;
  final List<ThemeItem> themes;

  const ThemesData({
    required this.windowDays,
    required this.totalNotesAnalyzed,
    required this.themes,
  });

  factory ThemesData.fromJson(Map<String, dynamic> json) => ThemesData(
    windowDays: json['window_days'] as int,
    totalNotesAnalyzed: json['total_notes_analyzed'] as int,
    themes: (json['themes'] as List)
        .map((e) => ThemeItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class LoopNote {
  final String date;
  final String preview;

  const LoopNote({required this.date, required this.preview});

  factory LoopNote.fromJson(Map<String, dynamic> json) => LoopNote(
    date: json['date'] as String,
    preview: json['preview'] as String,
  );
}

class LoopCluster {
  final String themeGuess;
  final int occurrences;
  final String severity; // high | medium | low
  final String firstSeen;
  final String lastSeen;
  final List<LoopNote> notes;
  final String pathForward;

  const LoopCluster({
    required this.themeGuess,
    required this.occurrences,
    required this.severity,
    required this.firstSeen,
    required this.lastSeen,
    required this.notes,
    required this.pathForward,
  });

  factory LoopCluster.fromJson(Map<String, dynamic> json) => LoopCluster(
    themeGuess: json['theme_guess'] as String,
    occurrences: json['occurrences'] as int,
    severity: json['severity'] as String,
    firstSeen: json['first_seen'] as String,
    lastSeen: json['last_seen'] as String,
    notes: (json['notes'] as List)
        .map((e) => LoopNote.fromJson(e as Map<String, dynamic>))
        .toList(),
    pathForward: json['path_forward'] as String,
  );
}

class LoopsData {
  final List<LoopCluster> loops;
  final int notesScanned;

  const LoopsData({required this.loops, required this.notesScanned});

  factory LoopsData.fromJson(Map<String, dynamic> json) => LoopsData(
    loops: (json['loops'] as List)
        .map((e) => LoopCluster.fromJson(e as Map<String, dynamic>))
        .toList(),
    notesScanned: json['notes_scanned'] as int,
  );
}
