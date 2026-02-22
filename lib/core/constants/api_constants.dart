import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConstants {
  // MED-5: Production URL injected at build time via --dart-define=API_URL=https://api.yourdomain.com
  // Dev builds fall back to localhost automatically.
  static const String _productionUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    // Production override — set via --dart-define at build/run time
    if (_productionUrl.isNotEmpty) return _productionUrl;

    // Development fallbacks
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000'; // iOS Simulator / macOS
  }
}
