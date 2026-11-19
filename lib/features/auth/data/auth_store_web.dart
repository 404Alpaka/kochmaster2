import 'package:web/web.dart' as web;

import 'auth_store.dart';

class BrowserAuthStore implements AuthStore {
  @override
  Future<String?> read(String key) async =>
      web.window.localStorage.getItem(key);
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      web.window.localStorage.removeItem(key);
    } else {
      web.window.localStorage.setItem(key, value);
      if (web.window.localStorage.getItem(key) != value) {
        throw StateError('auth_storage_unavailable');
      }
    }
  }
}

AuthStore createStore() => OrderedAuthStore(BrowserAuthStore());
