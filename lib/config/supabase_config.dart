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
  /// Supabase project URL (e.g. https://xxxx.supabase.co).
  ///
  /// Leave empty to fall back to the default project URL used in
  /// `ApiConfigService` (matches the web app project).
  static const String supabaseUrl = '';

  /// Supabase anon (public) key.
  ///
  /// Leave empty during development if you don't want to hard‑code keys.
  /// In that case, configure:
  /// - Environment variable `VITE_SUPABASE_PUBLISHABLE_KEY` equivalent, or
  /// - Firebase Remote Config key `supabase_anon_key`.
  static const String supabaseAnonKey = '';
}
