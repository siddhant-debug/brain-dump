import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/providers/storage_provider.dart';
import '../../brain_dump/providers/brain_dump_provider.dart';
import '../../notes/services/note_service.dart';
import '../../analytics/services/analytics_service.dart';

/*
Variables and Providers 

1 : auth controller provider variable stores the instance of AuthController which 
is used to manage the state of the authentication process. State notifier provider 
takes a callback function that returns an instance of AuthController.
*/

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref);
});

final isNewUserProvider = StateProvider<bool>((ref) => false);
/*
2 : isNewUserProvider is a state provider that stores a boolean value indicating 
whether the user is a new user or not.
*/

final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final storage = ref.read(secureStorageProvider);
  final token = await storage.read(key: 'jwt_token');
  if (token == null) return false;

  // MED-9: Decode the JWT payload and check the 'exp' claim locally.
  // No signature verification needed — we just need to know if it's expired.
  try {
    final parts = token.split('.');
    if (parts.length != 3) {
      await storage.delete(key: 'jwt_token');
      return false;
    }
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
            as Map<String, dynamic>;

    final exp = payload['exp'] as int?;
    if (exp == null || DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp) {
      // Token is expired — clear it so the app routes to login
      await storage.delete(key: 'jwt_token');
      return false;
    }
    return true;
  } on FormatException {
    // Malformed token — base64 decode or json decode failed
    await storage.delete(key: 'jwt_token');
    return false;
  } on RangeError {
    // Index out of bounds (though parts.length check mitigates most of this)
    await storage.delete(key: 'jwt_token');
    return false;
  } catch (_) {
    // Catch-all for any other unexpected decoding errors
    await storage.delete(key: 'jwt_token');
    return false;
  }
});

/*
3 : isAuthenticatedProvider is a future provider that returns a boolean value 
indicating whether the user is authenticated or not.
*/

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

/*
4 : userProvider is a future provider that returns a UserModel object containing 
the user's information.
*/

final userProvider = FutureProvider<UserModel?>((ref) async {
  final auth = ref.watch(isAuthenticatedProvider);
  if (auth.value != true) return null;

  /*
  5 : authController is a state notifier provider that stores an instance of AuthController.
  It is used to manage the state of the authentication process.
  */

  final authController = ref.read(authControllerProvider.notifier);

  /*
  6 : token is a String that stores the JWT token used to authenticate the user.
  */
  final token = await authController.getToken();
  if (token == null) return null;

  try {
    /*
    7 : dio is a Dio instance that is used to make HTTP requests to the server.
    */
    final dio = authController._dio;
    final response = await dio.get(
      '/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    /*
    8 : UserModel.fromJson(response.data) is a factory constructor that creates
    a UserModel object from the JSON response.
    */
    return UserModel.fromJson(response.data);
  } catch (e) {
    return null;
  }
});

/*
9 : AuthController extends StateNotifier to manage complex state logic.
It exposes an AsyncValue<void> to the UI to represent loading/success/error states.
*/
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this.ref)
      : _dio = ref.read(dioProvider),
        _storage = ref.read(secureStorageProvider),
        super(const AsyncValue.data(null));

  /*
  10 : ref is a Ref object that is used to interact with other providers or invalidate
   them (e.g., refresh user data on login).
  */
  final Ref ref;
  final Dio _dio;
  late final FlutterSecureStorage _storage;

  /*
  12 : login is a method that is used to login the user.
  It takes an email and password as parameters.
  */
  Future<void> login(String email, String password) async {
    /*
    13 : state = const AsyncValue.loading(); is used to set the state to loading.
    */
    state = const AsyncValue.loading();
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      /*
      14 : final String accessToken = response.data['access_token']; 
      is used to get the access token from the response.
      */
      final String accessToken = response.data['access_token'];
      await _storage.write(key: 'jwt_token', value: accessToken);

      // Clear any cached data from a previous user session before
      // fetching fresh data for the newly logged-in user.
      _invalidateUserData();

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
      print(
          'Signup Validation error [${e.response?.statusCode}]: ${e.response?.data}');
      if (e.response?.statusCode == 400) {
        errorMessage = 'Email already registered';
      } else if (e.response?.statusCode == 422) {
        errorMessage = 'Validation Error: ${e.response?.data}';
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

      // Wipe all user-scoped provider caches so the next user
      // cannot see this user's data.
      _invalidateUserData();

      ref.invalidate(isAuthenticatedProvider);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      print('Logout error: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Invalidates every provider that caches user-specific data.
  /// Call this on BOTH login and logout to prevent cross-user data leakage.
  /// When adding a new user-scoped provider, register it here.
  void _invalidateUserData() {
    // Chat history (in-memory message list)
    ref.invalidate(brainDumpProvider);
    // Notes / Thoughts list
    ref.invalidate(notesProvider);
    // Analytics tab
    ref.invalidate(consistencyProvider);
    ref.invalidate(themesProvider);
    ref.invalidate(loopsProvider);
    // userProvider itself (profile data)
    ref.invalidate(userProvider);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }
}
