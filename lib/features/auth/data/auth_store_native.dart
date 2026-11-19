import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_store.dart';
import 'auth_store_stub.dart';

class MobileAuthStore implements AuthStore {
  MobileAuthStore({FlutterSecureStorage? storage})
    : storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  final FlutterSecureStorage storage;

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String? value) => value == null
      ? storage.delete(key: key)
      : storage.write(key: key, value: value);
}

AuthStore createStore() => Platform.isAndroid || Platform.isIOS
    ? OrderedAuthStore(MobileAuthStore())
    : TransientAuthStore();
