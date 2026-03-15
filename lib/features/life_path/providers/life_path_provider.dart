import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/life_path.dart';

final lifePathProvider = FutureProvider<List<LifePathItem>>((ref) async {
  // Simulate network delay for skeleton hardening
  await Future.delayed(const Duration(seconds: 2));
  
  // For now returning mock data until backend is ready
  return [
    LifePathItem(
      id: "1",
      title: "Ship BrainDump v1",
      subtitle: "Work goal · 68% aligned",
      tags: [const LifePathTag("on track", Color(0xFF4CAF50))],
      isGoal: true,
      createdAt: DateTime.now(),
    ),
    LifePathItem(
      id: "2",
      title: "Morning brain dump",
      subtitle: "Thinking about the RAG pipeline refactor...",
      tags: [
        const LifePathTag("Koramangala", Color(0xFF185FA5)),
        const LifePathTag("Daft Punk", Color(0xFF534AB7)),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    LifePathItem(
      id: "3",
      title: "Skipped gym again",
      subtitle: "Need to fix this habit loop...",
      tags: [const LifePathTag("off goal", Color(0xFFF44336))],
      isNegative: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];
});
