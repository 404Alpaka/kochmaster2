import 'auth_store_stub.dart'
    if (dart.library.io) 'auth_store_native.dart'
    if (dart.library.js_interop) 'auth_store_web.dart'
    as platform;

abstract interface class AuthStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

AuthStore createAuthStore() => platform.createStore();

/// Keeps token refreshes and logout in order, including slow native writes.
class OrderedAuthStore implements AuthStore {
  OrderedAuthStore(this.delegate);
  final AuthStore delegate;
  Future<void> _pending = Future<void>.value();

  @override
  Future<String?> read(String key) async {
    await _pending;
    return delegate.read(key);
  }

  @override
  Future<void> write(String key, String? value) {
    final operation = _pending.then((_) => delegate.write(key, value));
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}
