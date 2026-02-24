import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';

/*
1 : dioProvider is a basic Provider that exposes a configured Dio instance.
It is reused across the app (services, controllers) for HTTP communication.
The BaseOptions set the root API URL and timeout policies.
*/
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
});
