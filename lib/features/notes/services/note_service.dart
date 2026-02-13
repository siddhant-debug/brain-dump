import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// [Architect] PROVIDER DEFINITION
// This is the entry point for the UI to access the NoteService.
// We use a simple Provider because the Service is stateless (logic only).
final noteServiceProvider = Provider<NoteService>((ref) {
  return NoteService();
});

// [Architect] FUTURE PROVIDER (DATA FETCHING)
// This provider automatically calls getNotes() when watched.
// It handles the AsyncValue state (loading/data/error) for the UI.
final notesProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.watch(noteServiceProvider).getNotes();
});

class NoteService {
  NoteService();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8000',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<String?> _getTokenWithRetry() async {
    // Read directly from secure storage to avoid potential provider access issues
    const storage = FlutterSecureStorage();
    String? token;
    int attempts = 0;
    while (attempts < 3) {
      token = await storage.read(key: 'jwt_token');
      if (token != null) {
        print('DEBUG: Token found on attempt ${attempts + 1}');
        return token;
      }
      print('DEBUG: Token null, retrying... (${attempts + 1}/3)');
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
    return null;
  }

  Future<Map<String, dynamic>> saveNote(String content) async {
    // [Architect] CROSS-PROVIDER INTERACTION
    // We read another provider (AuthController) to get the JWT token.
    final token = await _getTokenWithRetry();
    print(
      'DEBUG: NoteService.saveNote loaded token: ${token != null ? "PRESENT" : "NULL"}',
    );
    if (token == null) throw Exception('Not authenticated');

    try {
      // [Architect] API INTERACTION
      // We use Dio to perform the actual HTTP POST request to FastAPI.
      final response = await _dio.post(
        '/notes/',
        data: {'content': content},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to save note: $e');
    }
  }

  Future<List<dynamic>> getNotes() async {
    final token = await _getTokenWithRetry();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await _dio.get(
        '/notes/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to fetch notes: $e');
    }
  }
}
