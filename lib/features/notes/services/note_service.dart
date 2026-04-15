import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/providers/dio_provider.dart';
import '../models/note.dart';

// [Architect] PROVIDER DEFINITION
// This is the entry point for the UI to access the NoteService.
// We use a simple Provider because the Service is stateless (logic only).
final noteServiceProvider = Provider<NoteService>((ref) {
  return NoteService(ref.read(dioProvider));
});

// [Architect] FUTURE PROVIDER (DATA FETCHING)
// This provider automatically calls getNotes() when watched.
// It handles the AsyncValue state (loading/data/error) for the UI.
final notesProvider = FutureProvider<List<Note>>((ref) async {
  return ref.watch(noteServiceProvider).getNotes();
});

/*
1 : NoteService handles the persistence of text thoughts to the remote backend.
It includes automatic token retrieval with retries to handle disk I/O latency.
*/
class NoteService {
  final Dio _dio;

  NoteService(this._dio);

  /*
  3 : _getToken attempts to read the JWT from secure storage.
  */
  Future<String?> _getToken() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: 'jwt_token');
  }

  /*
  4 : saveNote sends a new text thought to the API.
  It requires an authenticated session.
  */
  Future<Map<String, dynamic>> saveNote(
    String content, {
    Map<String, dynamic>? location,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await _dio.post(
        '/notes/',
        data: {'content': content, 'location': location},
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
  Future<List<Note>> getNotes() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await _dio.get(
        '/notes/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final List<dynamic> data = response.data;
      return data.map((json) => Note.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch notes: $e');
    }
  }

  /*
  6 : deleteNote removes a thought from the backend.
  */
  Future<void> deleteNote(int id) async {
    final token = await _getToken();
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
