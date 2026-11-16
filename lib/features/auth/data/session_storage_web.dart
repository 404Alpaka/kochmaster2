import 'package:web/web.dart' as web;

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
String? authRedirectUrl() =>
    Uri.base.replace(query: '', fragment: '').toString();
void clearAuthCallback() {
  final query = Map<String, String>.from(Uri.base.queryParameters)
    ..remove('code');
  web.window.history.replaceState(
    null,
    '',
    Uri.base.replace(queryParameters: query).toString(),
  );
}
