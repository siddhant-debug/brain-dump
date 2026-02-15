import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/api_constants.dart';

final brainServiceProvider = Provider<BrainService>((ref) {
  return BrainService();
});

class BrainService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(
        seconds: 60,
      ), // Increased for RAG processing
    ),
  );

  Future<String?> _getToken() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: 'jwt_token');
  }

  /// ASK AI: POST /chat
  Future<Map<String, dynamic>> askBrain(String query) async {
    final token = await _getToken();
    if (token == null) throw Exception('User not authenticated');

    try {
      final response = await _dio.post(
        '/chat/chat',
        data: {'query': query},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } catch (e) {
      throw Exception('Brain query failed: $e');
    }
  }

  /// MEMORIZE NOTE: POST /upload-to-brain
  Future<Map<String, dynamic>> saveNote(String content) async {
    final token = await _getToken();
    if (token == null) throw Exception('User not authenticated');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'note_$timestamp.txt';

    try {
      // Create Multipart request
      FormData formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          utf8.encode(content),
          filename: filename,
        ),
      });

      final response = await _dio.post(
        '/chat/upload-to-brain',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } catch (e) {
      throw Exception('Memory upload failed: $e');
    }
  }

  /// LIST FILES: GET /chat/files
  Future<List<Map<String, dynamic>>> listFiles() async {
    final token = await _getToken();
    if (token == null) throw Exception('User not authenticated');

    try {
      final response = await _dio.get(
        '/chat/files',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw Exception('Failed to fetch file list: $e');
    }
  }
}
