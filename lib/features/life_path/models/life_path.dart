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
    return LifePathItem(
      id: map['id'] as String,
      title: map['title'] as String,
      subtitle: map['subtitle'] as String,
      tags: (map['tags'] as List? ?? [])
          .map((t) => LifePathTag.fromMap(t as Map<String, dynamic>))
          .toList(),
      isGoal: map['is_goal'] as bool? ?? false,
      isDimmed: map['is_dimmed'] as bool? ?? false,
      isNegative: map['is_negative'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
