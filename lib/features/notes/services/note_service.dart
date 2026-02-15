import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/api_constants.dart';

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

/*
1 : NoteService handles the persistence of text thoughts to the remote backend.
It includes automatic token retrieval with retries to handle disk I/O latency.
*/
class NoteService {
  NoteService();

  /*
  2 : _dio is configured for communication with the FastAPI backend.
  */
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /*
  3 : _getTokenWithRetry attempts to read the JWT from secure storage.
  It retries up to 3 times because the disk write on login might still be in progress
  when the first request (like fetching notes) is triggered.
  */
  Future<String?> _getTokenWithRetry() async {
    const storage = FlutterSecureStorage();
    String? token;
    int attempts = 0;
    while (attempts < 3) {
      token = await storage.read(key: 'jwt_token');
      if (token != null) {
        return token;
      }
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
    return null;
  }

  /*
  4 : saveNote sends a new text thought to the API.
  It requires an authenticated session.
  */
  Future<Map<String, dynamic>> saveNote(String content) async {
    final token = await _getTokenWithRetry();
    if (token == null) throw Exception('Not authenticated');

    try {
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

  /*
  5 : getNotes retrieves all previously saved thoughts from the vault.
  */
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

  /*
  6 : deleteNote removes a thought from the backend.
  */
  Future<void> deleteNote(int id) async {
    final token = await _getTokenWithRetry();
    if (token == null) throw Exception('Not authenticated');

    try {
      await _dio.delete(
        '/notes/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      throw Exception('Failed to delete note: $e');
    }
  }
}
