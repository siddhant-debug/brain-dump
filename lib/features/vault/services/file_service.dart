import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/providers/dio_provider.dart';

final fileServiceProvider = Provider(
  (ref) => FileService(ref, ref.read(dioProvider)),
);

/*
1 : FileService manages binary data (PDF/TXT/MD) interactions with the backend.
It uses MultipartFormData for uploads and JSON for metadata/content retrieval.
*/
class FileService {
  final Ref _ref;
  final Dio _dio;

  FileService(this._ref, this._dio);

  /*
  2 : _getToken helper ensures every request is authorized by the current user session.
  */
  Future<String?> _getToken() async {
    return await _ref.read(authControllerProvider.notifier).getToken();
  }

  /*
  3 : uploadFile converts a local File into a MultipartFile for server consumption.
  */
  Future<void> uploadFile(File file, {
    void Function(int, int)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });

    await _dio.post(
      '/chat/upload-to-brain',
      data: formData,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
  }

  /*
  4 : getFiles returns a list of all file metadata associated with the user account.
  */
  Future<List<Map<String, dynamic>>> getFiles() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await _dio.get(
      '/files/',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    return List<Map<String, dynamic>>.from(response.data);
  }

  /*
  5 : getFileContent retrieves the parsed text/content of a specific file by its database ID.
  */
  Future<dynamic> getFileContent(int fileId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await _dio.get(
      '/files/$fileId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    return response.data;
  }

  /*
  7 : deleteFile removes a file from the vault and the brain.
  */
  Future<void> deleteFile(int id) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      // Use the RAG router endpoint which also cleans up vectors and disk
      await _dio.delete(
        '/chat/files/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}

/*
6 : filesProvider is a reactive FutureProvider that caches the list of metadata.
When ref.invalidate(filesProvider) is called, it re-fetches the list from the API.
*/
final filesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(fileServiceProvider).getFiles();
});
