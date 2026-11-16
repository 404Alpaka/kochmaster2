import 'package:supabase/supabase.dart';

import 'session_storage.dart';

/// PKCE needs a verifier store even for email/password registration.
class KochmasterAuthStorage extends GotrueAsyncStorage {
  KochmasterAuthStorage(this.projectUrl);
  final String projectUrl;
  final _memory = <String, String>{};
  String scoped(String key) => 'kochmaster-$projectUrl-pkce-$key';
  @override
  Future<String?> getItem({required String key}) async =>
      readSession(scoped(key)) ?? _memory[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    writeSession(scoped(key), value);
    if (const bool.fromEnvironment('dart.library.js_interop')) {
      if (readSession(scoped(key)) != value) {
        throw StateError('auth_storage_unavailable');
      }
    }
    _memory[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _memory.remove(key);
    writeSession(scoped(key), null);
  }
}

AuthClientOptions kochmasterAuthOptions(String url) => AuthClientOptions(
  authFlowType: AuthFlowType.pkce,
  pkceAsyncStorage: KochmasterAuthStorage(url),
);

SupabaseClient createAuthClient(String url, String key) =>
    SupabaseClient(url, key, authOptions: kochmasterAuthOptions(url));
