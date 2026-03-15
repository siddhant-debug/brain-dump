import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/life_path.dart';
import '../../../core/providers/dio_provider.dart';
import '../../auth/controllers/auth_controller.dart';

final lifePathProvider = FutureProvider<List<LifePathItem>>((ref) async {
  final dio = ref.watch(dioProvider);
  final auth = ref.watch(authControllerProvider.notifier);
  final token = await auth.getToken();

  if (token == null) return [];

  try {
    // 1. Fetch history
    final response = await dio.get(
      '/api/lifepath/history',
      queryParameters: {'limit': 20},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      List<LifePathItem> items = data.map((item) => LifePathItem.fromMap(item as Map<String, dynamic>)).toList();
      
      // 2. If no history, or if the last node is very old, trigger an evaluation
      bool shouldEvaluate = items.isEmpty;
      if (!shouldEvaluate && items.isNotEmpty) {
        final lastEval = items.first.createdAt;
        if (DateTime.now().difference(lastEval).inHours >= 24) {
          shouldEvaluate = true;
        }
      }

      if (shouldEvaluate) {
        // Trigger evaluation (fire and forget for now, or await for immediate update)
        try {
          final evalResponse = await dio.post(
            '/api/lifepath/evaluate',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          if (evalResponse.statusCode == 200) {
             // If successful, re-fetch history or add the new node locally
             final newNode = LifePathItem.fromMap(evalResponse.data as Map<String, dynamic>);
             return [newNode, ...items];
          }
        } catch (e) {
          debugPrint("On-demand evaluation skipped or failed: $e");
          // If it failed due to 429 (dedup), just return current items
        }
      }

      return items;
    }
  } catch (e) {
    debugPrint("Error fetching life path history: $e");
    return [];
  }
  
  return [];
});
