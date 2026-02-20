class TimeoutConstants {
  // Network timeouts
  static const connectionTimeout = Duration(seconds: 60);
  static const receiveTimeout = Duration(seconds: 120);
  static const streamTimeout = Duration(seconds: 60);

  // UI timeouts
  static const noteDisplayDuration = Duration(milliseconds: 1500);
  static const debounceDelay = Duration(milliseconds: 300);

  // Retry configuration
  static const maxRetries = 3;
  static const retryDelay = Duration(seconds: 1);

  // Error handling
  static const maxMalformedChunks = 3;
}
