import 'package:flutter/foundation.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: kIsWeb ? null : dotenv.env['GOOGLE_WEB_CLIENT_ID'], 
  );

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Přihlášení přes Google (Nativní)
  Future<AuthResponse> signInWithGoogle() async {
    
    if (kIsWeb) {
      // Pro web spouštíme Supabase OAuth flow (spolehlivější v prohlížeči)
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google, // <--- OPRAVA: POUŽITÍ OAUTHPROVIDER
        redirectTo: kIsWeb ? null : 'io.supabase.flutterquickstart://login-callback/', 
      );
      throw 'Navigace probíhá přes Supabase callback.';
    }

    // --- Mobilní (iOS/Android) tok ---
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw 'Přihlášení zrušeno uživatelem.';
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (!kIsWeb && idToken == null) {
        throw 'Google ID Token nebyl nalezen. Zkontrolujte nativní konfiguraci.';
      }

      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google, // <--- OPRAVA: POUŽITÍ OAUTHPROVIDER
        idToken: idToken!,
        accessToken: accessToken,
      );
    } catch (e) {
      await _googleSignIn.signOut();
      rethrow;
    }
  }

  /// Registrace/Přihlášení emailem a heslem
  Future<AuthResponse> signUpWithEmail(String email, String password, String username) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': username},
    );
  }

  /// Přihlášení emailem
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Odhlášení
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
  }
}