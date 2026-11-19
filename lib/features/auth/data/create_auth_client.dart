import 'package:supabase/supabase.dart';

import 'auth_store.dart';

/// PKCE needs a verifier store even for email/password registration.
class KochmasterAuthStorage extends GotrueAsyncStorage {
  KochmasterAuthStorage(this.projectUrl, {AuthStore? store})
    : store = store ?? createAuthStore();
  final String projectUrl;
  final AuthStore store;
  String scoped(String key) => 'kochmaster-$projectUrl-pkce-$key';
  @override
  Future<String?> getItem({required String key}) async =>
      store.read(scoped(key));
  @override
  Future<void> setItem({required String key, required String value}) async {
    await store.write(scoped(key), value);
  }

  @override
  Future<void> removeItem({required String key}) async {
    await store.write(scoped(key), null);
  }
}

AuthClientOptions kochmasterAuthOptions(String url) => AuthClientOptions(
  authFlowType: AuthFlowType.pkce,
  pkceAsyncStorage: KochmasterAuthStorage(url),
);

SupabaseClient createAuthClient(String url, String key) =>
    SupabaseClient(url, key, authOptions: kochmasterAuthOptions(url));
