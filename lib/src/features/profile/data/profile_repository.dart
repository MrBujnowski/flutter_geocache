import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:image_picker/image_picker.dart'; // XFile
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  /// Získá profilová data z tabulky 'profiles'
  Future<Map<String, dynamic>?> getProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      return data;
    } catch (e) {
      // Pokud profil neexistuje (chyba triggeru?), vrátíme null
      return null;
    }
  }

  /// Aktualizuje profil (jméno, avatar)
  Future<void> updateProfile({String? username, String? avatarUrl}) async {
    final uid = currentUser?.id;
    if (uid == null) return;

    final updates = {
      'id': uid,
      'updated_at': DateTime.now().toIso8601String(),
      if (username != null) 'username': username,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };

    await _supabase.from('profiles').upsert(updates);
  }

  /// Nahraje avatar do Storage a vrátí veřejnou URL
  /// [imageFile] typu XFile (z image_picker) funguje pro mobil i web.
  Future<String> uploadAvatar(XFile imageFile) async {
    final uid = currentUser?.id;
    if (uid == null) throw Exception('User not logged in');

    // Jedinečný název souboru
    final fileExt = imageFile.name.split('.').last; 
    final fileName = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    if (kIsWeb) {
      // Na webu musíme nahrát binární data (Blob/Bytes)
      final bytes = await imageFile.readAsBytes();
      await _supabase.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
    } else {
      // Na mobilu můžeme použít File z dart:io (ale musíme ho vytvořit z cesty)
      await _supabase.storage.from('avatars').upload(
            fileName,
            File(imageFile.path),
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
    }

    final imageUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
    return imageUrl;
  }

  /// Získá počet nalezených kešek pro daného uživatele (nebo přihlášeného)
  Future<int> getUserFindsCount({String? userId}) async {
    final uid = userId ?? currentUser?.id;
    if (uid == null) return 0;

    final response = await _supabase
        .from('logs')
        .select('*')
        .eq('user_id', uid)
        .count(CountOption.exact); 

    return response.count;
  }

  /// Odhlášení
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
