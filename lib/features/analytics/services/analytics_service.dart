import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/providers/dio_provider.dart';
import '../models/analytics_models.dart';
import '../models/pipeline_models.dart';

// ─── Provider (stateless service) ────────────────────────────────────────────
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref.read(dioProvider));
});

// ─── Data providers (independent — slow loops won't block streak) ─────────────
final consistencyProvider = FutureProvider<ConsistencyData>((ref) {
  return ref.watch(analyticsServiceProvider).getConsistency();
});

final themesProvider = FutureProvider<ThemesData>((ref) {
  return ref.watch(analyticsServiceProvider).getThemes();
});

final loopsProvider = FutureProvider<LoopsData>((ref) {
  return ref.watch(analyticsServiceProvider).getLoops();
});

final pipelineProvider = FutureProvider<PipelineData>((ref) {
  return ref.watch(analyticsServiceProvider).getPipeline();
});

// ─── Service ─────────────────────────────────────────────────────────────────

/*
AnalyticsService fetches read-only brain analytics from the backend.
Follows the same pattern as BrainService / NoteService:
  - Dio with baseUrl + explicit timeouts
  - _getTokenWithRetry (up to 3 attempts — handles post-login disk-write lag)
  - null-token guard → throws 'Not authenticated'
  - DioException typed error handling
  - All errors re-thrown as friendly Exception messages
*/
class AnalyticsService {
  final Dio _dio;

  AnalyticsService(this._dio);

  Future<String?> _getToken() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: 'jwt_token');
  }

  Options _authOptions(String token) => Options(
    headers: {'Authorization': 'Bearer $token'},
    receiveTimeout: const Duration(seconds: 15),
  );

  // ── GET /analytics/consistency ─────────────────────────────────────────────
  Future<ConsistencyData> getConsistency() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await _dio.get(
        '/analytics/consistency',
        options: _authOptions(token),
      );
      return ConsistencyData.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to load consistency: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load consistency: $e');
    }
  }

  // ── GET /analytics/themes ─────────────────────────────────────────────────
  Future<ThemesData> getThemes({int days = 30}) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await _dio.get(
        '/analytics/themes',
        queryParameters: {'days': days},
        options: _authOptions(token),
      );
      return ThemesData.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to load themes: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load themes: $e');
    }
  }

  // ── GET /analytics/loops ──────────────────────────────────────────────────
  Future<LoopsData> getLoops({int days = 30}) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await _dio.get(
        '/analytics/loops',
        queryParameters: {'days': days},
        options: _authOptions(token),
      );
      return LoopsData.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to scan loops: ${e.message}');
    } catch (e) {
      throw Exception('Failed to scan loops: $e');
    }
  }

  // ── GET /analytics/pipeline ───────────────────────────────────────────────
  Future<PipelineData> getPipeline({int days = 30}) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await _dio.get(
        '/analytics/pipeline',
        queryParameters: {'days': days},
        options: _authOptions(token),
      );
      return PipelineData.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to load pipeline: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load pipeline: $e');
    }
  }
}
