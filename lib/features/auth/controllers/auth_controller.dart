import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      return AuthController(ref);
    });

final isNewUserProvider = StateProvider<bool>((ref) => false);

final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final storage = const FlutterSecureStorage();
  final token = await storage.read(key: 'jwt_token');
  return token != null;
});

class UserModel {
  final int id;
  final String email;
  final String? fullName;
  final String? profilePic;

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.profilePic,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      profilePic: json['profile_pic'],
    );
  }
}

final userProvider = FutureProvider<UserModel?>((ref) async {
  final auth = ref.watch(isAuthenticatedProvider);
  if (auth.value != true) return null;

  final authController = ref.read(authControllerProvider.notifier);

  final token = await authController.getToken();
  if (token == null) return null;

  try {
    final dio = authController._dio;
    final response = await dio.get(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return UserModel.fromJson(response.data);
  } catch (e) {
    return null;
  }
});

// [Architect] STATE MANAGEMENT (LOGIC LAYER)
// AuthController extends StateNotifier to manage complex state logic.
// It exposes an AsyncValue<void> to the UI to represent loading/success/error states.
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this.ref) : super(const AsyncValue.data(null));

  // [Architect] REF INJECTION
  // We hold `ref` to interact with other providers or invalidate them (e.g., refresh user data on login).
  final Ref ref;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl:
          'http://localhost:8000', // Update with your server local IP for physical devices
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final String accessToken = response.data['access_token'];
      await _storage.write(key: 'jwt_token', value: accessToken);

      ref.invalidate(isAuthenticatedProvider);
      state = const AsyncValue.data(null);
    } on DioException catch (e, stack) {
      String errorMessage = 'An error occurred';
      if (e.response?.statusCode == 401) {
        errorMessage = 'Invalid email or password';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timed out';
      }
      state = AsyncValue.error(errorMessage, stack);
    } catch (e, stack) {
      state = AsyncValue.error(e.toString(), stack);
    }
  }

  Future<void> signup(String email, String password, {String? fullName}) async {
    state = const AsyncValue.loading();
    try {
      await _dio.post(
        '/auth/signup',
        data: {'email': email, 'password': password, 'full_name': fullName},
      );

      // Set isNewUser to true BEFORE logging in, so main.dart knows where to route
      ref.read(isNewUserProvider.notifier).state = true;

      // Auto-login after signup
      await login(email, password);
    } on DioException catch (e, stack) {
      String errorMessage = 'Registration failed';
      if (e.response?.statusCode == 400) {
        errorMessage = 'Email already registered';
      }
      state = AsyncValue.error(errorMessage, stack);
    } catch (e, stack) {
      state = AsyncValue.error(e.toString(), stack);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _storage.delete(key: 'jwt_token');
      // Verify deletion
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        throw Exception('Token deletion failed');
      }
      ref.read(isNewUserProvider.notifier).state = false;
      ref.invalidate(isAuthenticatedProvider);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      print('Logout error: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }
}
