import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class SupabaseService {
  static bool _isInitialized = false;
  static final StreamController<bool> _initController =
      StreamController<bool>.broadcast();
  
  static bool get isInitialized => _isInitialized;
  static Stream<bool> get initStream => _initController.stream;
  
  static SupabaseClient get client {
    if (!_isInitialized) {
      throw Exception(
        'Supabase is not initialized. Please ensure Supabase credentials are configured.',
      );
    }
    return Supabase.instance.client;
  }
  
  static String? _url;
  static String? _anonKey;
  
  static String? get url => _url;
  static String? get anonKey => _anonKey;
  
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    _url = url;
    _anonKey = anonKey;
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );
    _isInitialized = true;
    _initController.add(true);
  }
  
  // Auth methods
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }
  
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  static User? get currentUser => client.auth.currentUser;
  
  static Stream<AuthState> get authStateChanges => 
      client.auth.onAuthStateChange;
}
