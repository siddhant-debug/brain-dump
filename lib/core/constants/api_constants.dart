import 'package:flutter/foundation.dart';

class ApiConstants {
  // Use localhost for Web/Emulators, and Local IP for physical devices
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    // Change this to your local IP for physical Android/iOS testing
    return 'http://192.168.1.27:8000';
  }
}
