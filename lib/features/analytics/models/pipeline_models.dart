import 'package:flutter/material.dart';

// ── Lane metadata ─────────────────────────────────────────────────────────────

class PipelineLane {
  final String key;
  final String label;
  final Color color;

  const PipelineLane({
    required this.key,
    required this.label,
    required this.color,
  });

  factory PipelineLane.fromJson(Map<String, dynamic> json) => PipelineLane(
    key: json['key'] as String,
    label: json['label'] as String,
    color: _hexColor(json['color'] as String),
  );
}

// ── Node ──────────────────────────────────────────────────────────────────────

enum ThoughtType { thought, question, action, anxiety, insight, calm }

class PipelineNode {
  final String id;
  final String content;
  final String topic;
  final int lane;
  final ThoughtType thoughtType;
  final DateTime timestamp;
  final List<String> parentIds;

  const PipelineNode({
    required this.id,
    required this.content,
    required this.topic,
    required this.lane,
    required this.thoughtType,
    required this.timestamp,
    required this.parentIds,
  });

  factory PipelineNode.fromJson(Map<String, dynamic> json) => PipelineNode(
    id: json['id'] as String,
    content: json['content'] as String,
    topic: json['topic'] as String,
    lane: json['lane'] as int,
    thoughtType: _parseType(json['thought_type'] as String),
    timestamp: DateTime.parse(json['timestamp'] as String),
    parentIds: List<String>.from(json['parent_ids'] as List),
  );

  // Colour per lane index — must match backend PIPELINE_LANES order:
  //  0 = Work (blue), 1 = Health (green), 2 = Personal (purple)
  static Color laneColor(int lane) {
    const colors = [
      Color(0xFF2979FF), // 0 Work — Neon Blue
      Color(0xFF81B622), // 1 Health — Sage Green
      Color(0xFFBB86FC), // 2 Personal — Electric Purple
      Color(0xFFE53935), // 3 fallback — red
    ];
    return colors[lane.clamp(0, colors.length - 1)];
  }

  Color get color => laneColor(lane);

  String get typeIcon {
    switch (thoughtType) {
      case ThoughtType.question:
        return '?';
      case ThoughtType.action:
        return '›';
      case ThoughtType.anxiety:
        return '~';
      case ThoughtType.insight:
        return '!';
      case ThoughtType.calm:
        return '–';
      case ThoughtType.thought:
        return '○';
    }
  }
}

// ── Wrapper ───────────────────────────────────────────────────────────────────

class PipelineData {
  final DateTime generatedAt;
  final List<PipelineLane> lanes;
  final List<PipelineNode> nodes;

  const PipelineData({
    required this.generatedAt,
    required this.lanes,
    required this.nodes,
  });

  factory PipelineData.fromJson(Map<String, dynamic> json) => PipelineData(
    generatedAt: DateTime.parse(json['generated_at'] as String),
    lanes: (json['lanes'] as List)
        .map((e) => PipelineLane.fromJson(e as Map<String, dynamic>))
        .toList(),
    nodes: (json['nodes'] as List)
        .map((e) => PipelineNode.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _hexColor(String hex) {
  final clean = hex.replaceAll('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

ThoughtType _parseType(String raw) {
  switch (raw) {
    case 'question':
      return ThoughtType.question;
    case 'action':
      return ThoughtType.action;
    case 'anxiety':
      return ThoughtType.anxiety;
    case 'insight':
      return ThoughtType.insight;
    case 'calm':
      return ThoughtType.calm;
    default:
      return ThoughtType.thought;
  }
}
