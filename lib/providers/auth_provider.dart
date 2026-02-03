import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/supabase_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  Session? _session;
  bool _loading = true;
  String? _error;
  StreamSubscription<bool>? _supabaseInitSub;

  User? get user => _user;
  Session? get session => _session;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _init();
  }

  void _init() {
    // Check if Supabase is initialized before trying to access it
    if (!SupabaseService.isInitialized) {
      // If Supabase initializes later (we now do it after first frame),
      // re-run initialization then.
      _supabaseInitSub ??= SupabaseService.initStream.listen((ready) {
        if (ready) {
          _init();
        }
      });
      _loading = false;
      notifyListeners();
      return;
    }
    
    // Supabase is ready; no need to keep listening.
    _supabaseInitSub?.cancel();
    _supabaseInitSub = null;

    // Get initial session
    try {
      _session = SupabaseService.currentUser != null
          ? SupabaseService.client.auth.currentSession
          : null;
      _user = SupabaseService.currentUser;
      
      // Listen to auth state changes
      SupabaseService.authStateChanges.listen((data) {
        _session = data.session;
        _user = data.session?.user;
        notifyListeners();
      });
    } catch (e) {
      print('Error initializing auth: $e');
    }
    
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _supabaseInitSub?.cancel();
    _supabaseInitSub = null;
    super.dispose();
  }

  Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      _error = null;
      _loading = true;
      notifyListeners();

      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (response.user != null) {
        _user = response.user;
        _session = response.session;
      } else if (response.user == null) {
        // Email confirmation required - error will be set by caller with localization
        _error = 'Email confirmation required';
      }

      _loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return null;
    }
  }

  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _error = null;
      _loading = true;
      notifyListeners();

      final response = await SupabaseService.signIn(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _user = response.user;
        _session = response.session;
      }

      _loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      _error = null;
      await SupabaseService.signOut();
      _user = null;
      _session = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
