import 'remote_config_service.dart';
import '../config/supabase_config.dart';

/// Simple API configuration service for chat and other API endpoints
/// No Supabase client initialization required - just stores URL and key
class ApiConfigService {
  static String? _apiUrl;
  static String? _apiKey;

  /// Get API URL (Supabase functions URL)
  static String? get apiUrl => _apiUrl;

  /// Get API Key (Supabase anon key)
  static String? get apiKey => _apiKey;

  /// Initialize API configuration
  /// Matches web app: VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY
  /// Can be called with direct values or will try to get from Remote Config
  /// Falls back to default values (same as web app) if not configured
  static Future<void> initialize({
    String? url,
    String? key,
  }) async {
    // If provided directly, use those (from environment variables)
    if (url != null && key != null && url.isNotEmpty && key.isNotEmpty) {
      _apiUrl = url;
      _apiKey = key;
      print('[ApiConfig] ✅ Configured from environment variables');
      return;
    }

    // Otherwise, try to get from Remote Config (matching web app behavior)
    // Web app uses: VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY
    // Flutter Remote Config uses: supabase_url and supabase_anon_key
    try {
      if (RemoteConfigService.isInitialized) {
        // Fetch and activate to ensure we have latest values
        await RemoteConfigService.fetchAndActivate();
        
        final remoteUrl = RemoteConfigService.getString('supabase_url');
        final remoteKey = RemoteConfigService.getString('supabase_anon_key');
        
        if (remoteUrl.isNotEmpty && remoteKey.isNotEmpty) {
          _apiUrl = remoteUrl;
          _apiKey = remoteKey;
          print('[ApiConfig] ✅ Configured from Remote Config');
          return;
        } else {
          print('[ApiConfig] ⚠️ Remote Config keys are empty, using defaults');
        }
      } else {
        print('[ApiConfig] ⚠️ Remote Config not initialized, using defaults');
      }
    } catch (e) {
      // Remote Config not available or not initialized - that's okay
      print('[ApiConfig] ⚠️ Error getting API config from Remote Config: $e');
      print('[ApiConfig] ⚠️ Using default values');
    }

    // Fallback to default values (matching web app's Supabase project)
    // Web app project ID: kqhufomrgvpagbziwwok (from supabase/config.toml)
    // Web app uses: VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY from .env
    if (_apiUrl == null || _apiUrl!.isEmpty) {
      // Try config file first, then fallback to web app's project URL
      _apiUrl = SupabaseConfig.supabaseUrl.isNotEmpty 
          ? SupabaseConfig.supabaseUrl 
          : 'https://kqhufomrgvpagbziwwok.supabase.co';
      print('[ApiConfig] ✅ Using web app Supabase URL (matches web app project)');
    }
    
    // The anon key must match the web app's VITE_SUPABASE_PUBLISHABLE_KEY
    // Priority: Environment > Remote Config > Config File
    if (_apiKey == null || _apiKey!.isEmpty) {
      // Try config file as last resort
      if (SupabaseConfig.supabaseAnonKey.isNotEmpty) {
        _apiKey = SupabaseConfig.supabaseAnonKey;
        print('[ApiConfig] ✅ Using anon key from config file');
      } else {
        print('[ApiConfig] ❌ Supabase anon key not configured!');
        print('[ApiConfig]    Options:');
        print('[ApiConfig]    1. Set VITE_SUPABASE_PUBLISHABLE_KEY environment variable');
        print('[ApiConfig]    2. Configure supabase_anon_key in Firebase Remote Config');
        print('[ApiConfig]    3. Update lib/config/supabase_config.dart');
        print('[ApiConfig]    Get the key from web app .env file or Supabase Dashboard');
      }
    }
  }

  /// Check if API is configured
  static bool get isConfigured => 
      _apiUrl != null && _apiKey != null && 
      _apiUrl!.isNotEmpty && _apiKey!.isNotEmpty;
}
