import 'package:web/web.dart' as web;

import 'auth_callback_uri.dart';
import '../../../core/local_store.dart';

String? readSession(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void writeSession(String key, String? session) {
  try {
    if (session == null) {
      web.window.localStorage.removeItem(key);
    } else {
      web.window.localStorage.setItem(key, session);
    }
  } catch (_) {
    LocalStore.instance.issue.value = 'Änderungen konnten nicht im Browser gespeichert werden. Bitte prüfe die Website-Daten.';
  }
}

String? authCallbackCode() => Uri.base.queryParameters['code'];

// Destructive actions must surface a storage failure instead of claiming success.
Future<void> removeSessionValues(Iterable<String> keys) async {
  for (final key in keys) {
    web.window.localStorage.removeItem(key);
  }
}

String? authCallbackError() => authErrorFromUri(Uri.base);
String? authRedirectUrl() => authReturnAddress(Uri.base);
void clearAuthCallback() {
  web.window.history.replaceState(
    null,
    '',
    withoutAuthCallback(Uri.base).toString(),
  );
}
