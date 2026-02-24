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

    // Direct Ubuntu Server testing URL for all platforms
    return 'http://192.168.1.58:8000';
  }
}
