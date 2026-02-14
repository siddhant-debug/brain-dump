import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/constants/api_constants.dart';

final fileServiceProvider = Provider((ref) => FileService(ref));

/*
1 : FileService manages binary data (PDF/TXT/MD) interactions with the backend.
It uses MultipartFormData for uploads and JSON for metadata/content retrieval.
*/
class FileService {
  final Ref _ref;

  FileService(this._ref);

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /*
  2 : _getToken helper ensures every request is authorized by the current user session.
  */
  Future<String?> _getToken() async {
    return await _ref.read(authControllerProvider.notifier).getToken();
  }

  /*
  3 : uploadFile converts a local File into a MultipartFile for server consumption.
  */
  Future<void> uploadFile(File file) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });

    await _dio.post(
      '/files/upload',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
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
}

/*
6 : filesProvider is a reactive FutureProvider that caches the list of metadata.
When ref.invalidate(filesProvider) is called, it re-fetches the list from the API.
*/
final filesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(fileServiceProvider).getFiles();
});
