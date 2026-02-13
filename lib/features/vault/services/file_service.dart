import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';

final fileServiceProvider = Provider((ref) => FileService(ref));

class FileService {
  final Ref _ref;

  FileService(this._ref);

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8000',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<String?> _getToken() async {
    return await _ref.read(authControllerProvider.notifier).getToken();
  }

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

  Future<List<Map<String, dynamic>>> getFiles() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await _dio.get(
      '/files/',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    return List<Map<String, dynamic>>.from(response.data);
  }

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

final filesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(fileServiceProvider).getFiles();
});
