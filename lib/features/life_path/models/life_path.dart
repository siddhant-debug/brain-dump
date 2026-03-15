import 'package:flutter/material.dart';

class LifePathTag {
  final String label;
  final Color color;

  const LifePathTag(this.label, this.color);

  factory LifePathTag.fromMap(Map<String, dynamic> map) {
    return LifePathTag(
      map['label'] as String,
      Color(int.parse(map['color'].toString().replaceAll('#', '0xFF'))),
    );
  }
}

class LifePathItem {
  final String id;
  final String title;
  final String subtitle;
  final List<LifePathTag> tags;
  final bool isGoal;
  final bool isDimmed;
  final bool isNegative;
  final DateTime createdAt;

  const LifePathItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.tags = const [],
    this.isGoal = false,
    this.isDimmed = false,
    this.isNegative = false,
    required this.createdAt,
  });

  factory LifePathItem.fromMap(Map<String, dynamic> map) {
    final trajectory = map['trajectory'] as Map<String, dynamic>? ?? {};
    final progress = trajectory['progress'] as List? ?? [];
    
    // Use the first progress point as title, or a default string
    String title = progress.isNotEmpty ? progress.first.toString() : "Daily Insight";
    String subtitle = "";
    
    if (trajectory['short_term_goals'] != null && (trajectory['short_term_goals'] as List).isNotEmpty) {
      subtitle = "Next: ${(trajectory['short_term_goals'] as List).first}";
    }

    return LifePathItem(
      id: map['id'].toString(),
      title: title,
      subtitle: subtitle,
      tags: (map['tags'] as List? ?? [])
          .map((t) => LifePathTag.fromMap(t as Map<String, dynamic>))
          .toList(),
      isGoal: map['is_goal'] as bool? ?? false,
      isDimmed: map['is_dimmed'] as bool? ?? false,
      isNegative: (trajectory['blockers'] as List? ?? []).isNotEmpty,
      createdAt: DateTime.parse(map['computed_at'] as String),
    );
  }
}
