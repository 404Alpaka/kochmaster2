import 'package:web/web.dart' as web;
import 'auth_callback_uri.dart';

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
    /* Private browsing may disable storage; login still works. */
  }
}

String? authCallbackCode() => Uri.base.queryParameters['code'];
String? authCallbackError() => authErrorFromUri(Uri.base);
String? authRedirectUrl() =>
    authReturnAddress(Uri.base);
void clearAuthCallback() {
  web.window.history.replaceState(
    null,
    '',
    withoutAuthCallback(Uri.base).toString(),
  );
}
