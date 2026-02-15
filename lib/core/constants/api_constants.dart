import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConstants {
  // Use localhost for Web/Emulators, and Local IP for physical devices
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    // For Android Emulator, 10.0.2.2 points to host machine's localhost
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    // For iOS Simulator or other desktop environments (localhost)
    return 'http://localhost:8000';

    // Commented out physical IP testing for now
    // return 'http://192.168.1.46:8000';
  }
}
