import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/features/auth/data/auth_store.dart';
import 'package:kochmaster/features/auth/data/auth_store_native.dart';
import 'package:kochmaster/features/auth/data/create_auth_client.dart';
import 'package:kochmaster/features/auth/presentation/account_scope.dart';

class DelayedStore implements AuthStore {
  final gate = Completer<void>();
  String? value;
  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write(String key, String? next) async {
    if (next != null) await gate.future;
    value = next;
  }
}

class FailingStore implements AuthStore {
  @override
  Future<String?> read(String key) async =>
      throw StateError('storage unavailable');
  @override
  Future<void> write(String key, String? value) async =>
      throw StateError('storage unavailable');
}

Future<T> runReal<T>(Future<T> Function() callback) => callback();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Logout folgt auch auf einen noch laufenden Schreibzugriff', () async {
    final slow = DelayedStore();
    final store = OrderedAuthStore(slow);
    final login = store.write('session', 'token');
    final logout = store.write('session', null);
    slow.gate.complete();
    await Future.wait([login, logout]);
    expect(await store.read('session'), isNull);
  });

  test(
    'PKCE bleibt nach Neuerstellung erhalten und ist projektbezogen',
    () async {
      final first = KochmasterAuthStorage(
        'project-a',
        store: MobileAuthStore(),
      );
      await first.setItem(key: 'verifier', value: 'secret');
      final restarted = KochmasterAuthStorage(
        'project-a',
        store: MobileAuthStore(),
      );
      expect(await restarted.getItem(key: 'verifier'), 'secret');
      final other = KochmasterAuthStorage(
        'project-b',
        store: MobileAuthStore(),
      );
      expect(await other.getItem(key: 'verifier'), isNull);
      await restarted.removeItem(key: 'verifier');
      expect(await first.getItem(key: 'verifier'), isNull);
    },
  );

  testWidgets('Nicht lesbarer Speicher blockiert den App-Start nicht', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final client = SupabaseClient('https://example.supabase.co', 'test-key');
      await tester.pumpWidget(
        MaterialApp(
          home: AccountScope(
            client: client,
            storageKey: 'unreadable',
            sessionStore: FailingStore(),
            builder: (_) => const Scaffold(body: Text('App bereit')),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await tester.pumpAndSettle();
      expect(find.text('App bereit'), findsOneWidget);
      expect(
        find.textContaining('konnte nicht gelesen werden'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await client.dispose();
    });
  });

  for (final expired in [false, true]) {
    testWidgets('Sitzung nach Neustart wiederherstellen, abgelaufen=$expired', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const key = 'mobile-session-test';
        final store = MobileAuthStore();
        var refreshed = false;
        final user = {
          'id': '12345678-1234-4234-8234-123456789012',
          'aud': 'authenticated',
          'email': 'test@example.com',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-11-18T12:00:00Z',
        };
        Map<String, dynamic> session(int expiry) {
          String part(Object value) => base64Url
              .encode(utf8.encode(jsonEncode(value)))
              .replaceAll('=', '');
          return {
            'access_token':
                '${part({'alg': 'HS256'})}.${part({'sub': user['id'], 'exp': expiry})}.signature',
            'token_type': 'bearer',
            'refresh_token': 'refresh-token',
            'expires_in': 3600,
            'expires_at': expiry,
            'user': user,
          };
        }

        final expiry =
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;
        final transport = MockClient((request) async {
          if (request.url.path.endsWith('/logout')) {
            return http.Response('', 204, request: request);
          }
          expect(request.url.path, '/auth/v1/token');
          if (request.url.queryParameters['grant_type'] == 'refresh_token') {
            refreshed = true;
            expect(
              (jsonDecode(request.body) as Map)['refresh_token'],
              'refresh-token',
            );
          }
          return http.Response(
            jsonEncode(session(expiry)),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        });
        SupabaseClient client() => SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          httpClient: transport,
        );
        final first = client();
        Widget app(SupabaseClient auth) => MaterialApp(
          home: AccountScope(
            key: ValueKey(auth),
            client: auth,
            storageKey: key,
            sessionStore: store,
            builder: (user) => Scaffold(
              body: Text(user == null ? 'Abgemeldet' : 'Angemeldet'),
            ),
          ),
        );
        await tester.pumpWidget(app(first));
        await tester.pumpAndSettle();
        await runReal(
          () => first.auth.signInWithPassword(
            email: 'test@example.com',
            password: 'test-password',
          ),
        );
        await tester.pumpAndSettle();
        final saved = await runReal(() => store.read(key));
        expect(saved, isNotNull);
        expect(saved, isNot(contains('test-password')));
        await tester.pumpWidget(const SizedBox());
        await runReal(first.dispose);
        if (expired) {
          await runReal(() => store.write(key, jsonEncode(session(1))));
        }
        final second = client();
        await runReal(() async {
          await tester.pumpWidget(app(second));
          // Native reads and token refresh use real asynchronous work.
          final deadline = DateTime.now().add(const Duration(seconds: 5));
          while (find.text('Angemeldet').evaluate().isEmpty &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
          }
        });
        await tester.pumpAndSettle();
        expect(find.text('Angemeldet'), findsOneWidget);
        expect(refreshed, expired);
        await runReal(() => second.auth.signOut());
        await tester.pumpAndSettle();
        expect(await runReal(() => store.read(key)), isNull);
        expect(await runReal(() => store.read('$key-recovery')), isNull);
        expect(find.text('Abgemeldet'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await runReal(second.dispose);
      });
    });
  }
}
