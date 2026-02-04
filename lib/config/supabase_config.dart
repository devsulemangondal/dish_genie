/// Supabase configuration for the DishGenie app.
///
/// This file is used as a last‑resort fallback by `ApiConfigService`
/// when environment variables and Remote Config are not set.
///
/// IMPORTANT:
/// - For production, you should **NOT** hard‑code real keys here.
/// - Prefer setting:
///   1) Environment variables (e.g. via --dart-define),
///   2) or Firebase Remote Config values: `supabase_url` and `supabase_anon_key`.
/// - If you do put values here, treat this file as **secret** and never commit
///   real keys to a public repository.
class SupabaseConfig {
  /// Supabase project URL (matches web app VITE_SUPABASE_URL).
  static const String supabaseUrl = 'https://kqhufomrgvpagbziwwok.supabase.co';

  /// Supabase anon (public) key (matches web app VITE_SUPABASE_PUBLISHABLE_KEY).
  /// For production builds, consider using Firebase Remote Config instead.
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtxaHVmb21yZ3ZwYWdieml3d29rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4Njc3NjAsImV4cCI6MjA4MDQ0Mzc2MH0.HI2iJoM1tsrJewbEdKIUEpQ5CkLFOwv--aS0L8vZ0j4';
}
