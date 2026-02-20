import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/timeout_constants.dart';
import '../models/chat_message.dart';

final brainServiceProvider = Provider<BrainService>((ref) {
  return BrainService();
});

class BrainService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: TimeoutConstants.connectionTimeout,
      receiveTimeout: TimeoutConstants.receiveTimeout,
    ),
  );

  Future<String?> _getToken() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: 'jwt_token');
  }

  /// ASK AI: POST /chat (STREAMING)
  Stream<Map<String, dynamic>> askBrain(
    String query, {
    Map<String, dynamic>? location,
  }) async* {
    final token = await _getToken();
    if (token == null) throw Exception('User not authenticated');

    try {
      final response = await _dio.post(
        '/chat/chat',
        data: {'query': query, if (location != null) 'location': location},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'text/event-stream',
          },
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero, // No timeout for streaming
        ),
      );

      // Parse SSE stream with timeout and proper error handling
      int malformedChunkCount = 0;

      final streamWithTimeout = response.data.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .timeout(
            TimeoutConstants.streamTimeout,
            onTimeout: (sink) {
              sink.addError(
                Exception('Response took too long. Please try again.'),
              );
              sink.close();
            },
          );

      await for (var chunk in streamWithTimeout) {
        // SSE format: "data: {json}\n\n"
        final lines = chunk.split('\n');
        for (var line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6); // Remove "data: " prefix
            try {
              final data = json.decode(jsonStr);

              if (data['error'] != null) {
                throw Exception(data['error']);
              }

              // Yield the full data object so provider can access 'chunk' and 'sources'
              yield data;

              if (data['done'] == true) {
                // Stream complete
                return;
              }

              malformedChunkCount = 0; // Reset on success
            } catch (e) {
              malformedChunkCount++;

              // Log for debugging
              print('Warning: Malformed SSE chunk: $jsonStr');

              // Fail fast if too many errors
              if (malformedChunkCount >= TimeoutConstants.maxMalformedChunks) {
                throw Exception(
                  'Too many malformed responses. Connection unstable.',
                );
              }

              continue;
            }
          }
        }
      }
    } on TimeoutException catch (e) {
      throw Exception('Request timed out: ${e.message ?? "Please try again"}');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout. Please try again.');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server took too long to respond.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Network error. Please check your connection.');
      } else {
        throw Exception('Brain query failed: ${e.message}');
      }
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

  /// GET HISTORY: GET /chat/history
  Future<List<ChatMessage>> getChatHistory() async {
    final token = await _getToken();
    if (token == null) throw Exception('User not authenticated');

    try {
      final response = await _dio.get(
        '/chat/history',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final List<dynamic> data = response.data;
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      // Fail silently or return empty list on error to not block UI
      print('Failed to fetch chat history: $e');
      return [];
    }
  }
}
