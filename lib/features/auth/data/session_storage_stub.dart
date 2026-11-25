import '../../../core/local_store.dart';

String? readSession(String key) => LocalStore.instance.read('preference:$key');
void writeSession(String key, String? session) =>
    LocalStore.instance.writeLater('preference:$key', session);

Future<void> removeSessionValues(Iterable<String> keys) async {
  for (final key in keys) {
    await LocalStore.instance.write('preference:$key', null);
  }
}

String? authCallbackCode() => null;
String? authCallbackError() => null;
void clearAuthCallback() {}
String? authRedirectUrl() => null;
