import 'package:flutter/foundation.dart';

import 'remote_config_service.dart';
import 'storage_service.dart';

/// Service for handling app startup initialization tasks
class StartupService {
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  /// Check if startup service has completed initialization
  static bool get isInitialized => _isInitialized;

  /// Start all startup initialization tasks
  /// This should be called early in the app lifecycle
  static Future<void> start() async {
    if (_isInitialized || _isInitializing) {
      if (kDebugMode) {
        print('[StartupService] ✅ Already initialized or initializing');
      }
      return;
    }

    _isInitializing = true;

    try {
      if (kDebugMode) {
        print('[StartupService] 🔄 Starting initialization...');
      }

      // Initialize StorageService first (needed by other services)
      await StorageService.initialize();

      // Initialize RemoteConfigService (non-blocking, can fail gracefully)
      try {
        await RemoteConfigService.initialize();
        if (kDebugMode) {
          print('[StartupService] ✅ RemoteConfigService initialized');
        }
      } catch (e) {
        if (kDebugMode) {
          print(
            '[StartupService] ⚠️ RemoteConfigService initialization failed: $e',
          );
        }
        // Continue even if RemoteConfig fails - it will use defaults
      }

      _isInitialized = true;
      if (kDebugMode) {
        print('[StartupService] ✅ Startup initialization complete');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[StartupService] ❌ Startup initialization error: $e');
      }
      // Don't mark as initialized if there was an error
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Reset initialization state (useful for testing)
  static void reset() {
    _isInitialized = false;
    _isInitializing = false;
  }
}
