import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/features/auth/data/create_auth_client.dart';
import 'package:kochmaster/features/auth/presentation/account_scope.dart';
import 'package:kochmaster/features/auth/presentation/password_reset_page.dart';

void main() {
  testWidgets('Reset-Mail, PKCE-Recovery und neues Passwort', (tester) async {
    final requests = <http.Request>[];
    final user = {
      'id': '12345678-1234-4234-8234-123456789012',
      'aud': 'authenticated',
      'email': 'test@example.com',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-11-16T12:00:00Z',
    };
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final expiry =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    final token =
        '${part({'alg': 'HS256'})}.${part({'sub': user['id'], 'exp': expiry})}.signature';
    final transport = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/recover')) {
        final body = jsonDecode(request.body) as Map;
        expect(body['email'], 'test@example.com');
        expect(body['code_challenge'], isNotEmpty);
        return http.Response('{}', 200);
      }
      if (request.url.path.endsWith('/token')) {
        expect(request.url.queryParameters['grant_type'], 'pkce');
        expect((jsonDecode(request.body) as Map)['code_verifier'], isNotEmpty);
        return http.Response(
          jsonEncode({
            'access_token': token,
            'token_type': 'bearer',
            'refresh_token': 'refresh',
            'expires_in': 3600,
            'expires_at': expiry,
            'user': user,
          }),
          200,
        );
      }
      if (request.method == 'PUT' && request.url.path.endsWith('/user')) {
        expect(
          (jsonDecode(request.body) as Map)['password'],
          'new-test-password',
        );
        return http.Response(jsonEncode(user), 200);
      }
      return http.Response('{}', 400);
    });
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: transport,
      authOptions: kochmasterAuthOptions('https://example.supabase.co'),
    );
    addTearDown(() => tester.runAsync(client.dispose));
    await tester.pumpWidget(
      MaterialApp(home: PasswordResetPage(client: client)),
    );
    await tester.tap(find.text('Link zum Zurücksetzen senden'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await tester.enterText(find.byType(TextFormField), 'test@example.com');
    await tester.tap(find.text('Link zum Zurücksetzen senden'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Falls für diese'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: AccountScope(
          client: client,
          storageKey: 'test-reset',
          builder: (_) => const Scaffold(body: Text('App bereit')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => client.auth.exchangeCodeForSession('test-recovery-code'));
    await tester.pumpAndSettle();
    expect(find.text('Vergib ein neues Passwort'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'short');
    await tester.tap(find.text('Neues Passwort speichern'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'PUT'), isEmpty);
    await tester.enterText(
      find.byType(TextFormField).first,
      'new-test-password',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'new-test-password',
    );
    await tester.tap(find.text('Neues Passwort speichern'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'PUT'), hasLength(1));
    expect(find.text('App bereit'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

