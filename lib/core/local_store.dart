import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret app data. Authentication tokens keep using the secure auth store.
class LocalStore {
  LocalStore({this.preferences});

  static LocalStore instance = LocalStore();
  static const _prefix = 'kochmaster-local-v1:';
  SharedPreferencesAsync? preferences;
  final _values = <String, String>{};
  final _dirty = <String, String?>{};
  final issue = ValueNotifier<String?>(null);
  Future<void>? _tail;
  Future<void>? _initializing;
  bool initialized = false;
  bool readable = false;

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      preferences ??= SharedPreferencesAsync();
      final all = await preferences!.getAll();
      for (final entry in all.entries) {
        if (entry.key.startsWith(_prefix) && entry.value is String) {
          final key = entry.key.substring(_prefix.length);
          if (!_dirty.containsKey(key)) _values[key] = entry.value! as String;
        }
      }
      readable = true;
    } catch (_) {
      issue.value = 'Der lokale Speicher konnte nicht geladen werden. Änderungen sind auf diesem Gerät vorerst nicht dauerhaft verfügbar.';
    } finally {
      initialized = true;
    }
  }

  String? read(String key) => _values[key];
  Iterable<String> get keys => _values.keys.toList();

  Future<void> write(String key, String? value, {bool optimistic = true}) {
    if (optimistic) {
      if (value == null) {
        _values.remove(key);
      } else {
        _values[key] = value;
      }
    }
    _dirty[key] = value;
    Future<void> commit() async {
      if (!initialized) await initialize();
      // Never overwrite unseen on-disk data following a failed initial read.
      if (!readable) throw StateError('Local storage unavailable');
      if (value == null) {
        await preferences!.remove('$_prefix$key');
      } else {
        await preferences!.setString('$_prefix$key', value);
      }
      if (_dirty.containsKey(key) && _dirty[key] == value) {
        if (!optimistic) {
          if (value == null) {
            _values.remove(key);
          } else {
            _values[key] = value;
          }
        }
        _dirty.remove(key);
      }
      if (_dirty.isEmpty) issue.value = null;
    }

    final operation = _tail == null ? commit() : _tail!.then((_) => commit());
    _tail = operation.catchError((Object _) {
      issue.value = 'Änderungen konnten nicht dauerhaft auf diesem Gerät gespeichert werden. Bitte prüfe den Gerätespeicher.';
    });
    return operation;
  }

  void writeLater(String key, String? value) {
    unawaited(write(key, value).catchError((Object _) {}));
  }

  Future<void> flush() async {
    await _tail;
    if (_dirty.isNotEmpty) throw StateError('Local writes are pending');
  }

  Future<void> removePrefix(String prefix) async {
    for (final key in keys.where((key) => key.startsWith(prefix))) {
      await write(key, null);
    }
  }
}
