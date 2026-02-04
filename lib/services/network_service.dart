import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to check network connectivity and show "No internet" when needed.
class NetworkService {
  static final Connectivity _connectivity = Connectivity();

  /// Check if device has internet (connected to wifi or mobile).
  static Future<bool> get isConnected async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet,
      );
    } catch (e) {
      if (kDebugMode) print('[NetworkService] Error checking connectivity: $e');
      return false;
    }
  }

  /// Call before an API call. If no internet, returns false (caller should show dialog).
  static Future<bool> ensureConnected() async {
    return await isConnected;
  }
}
