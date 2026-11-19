import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/features/auth/data/create_auth_client.dart';
import 'package:kochmaster/features/auth/presentation/auth_messages.dart';
import 'package:kochmaster/features/auth/presentation/account_page.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'Registrierung verlangt Namen und sendet alle Angaben ohne Kundennummer',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        Map<String, dynamic>? signup;
        var resends = 0;
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: kochmasterAuthOptions('https://example.supabase.co'),
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/resend')) {
              final body = jsonDecode(request.body) as Map;
              expect(body['email'], 'test@example.com');
              expect(body['type'], 'signup');
              expect(body['code_challenge'], isNotEmpty);
              resends++;
              return http.Response(
                '{}',
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            expect(request.url.path, '/auth/v1/signup');
            signup = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'id': '12345678-1234-4234-8234-123456789012',
                'aud': 'authenticated',
                'email': 'test@example.com',
                'app_metadata': {},
                'user_metadata': signup!['data'],
                'created_at': '2026-11-18T12:00:00Z',
              }),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        await tester.pumpWidget(MaterialApp(home: AccountPage(client: client)));
        await tester.tap(find.text('Neues Konto erstellen'));
        await tester.pumpAndSettle();
        final button = find.widgetWithText(FilledButton, 'Registrieren');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('Bitte gib deinen Vornamen ein.'), findsOneWidget);
        expect(find.text('Bitte gib deinen Nachnamen ein.'), findsOneWidget);
        expect(signup, isNull);
        final values = [
          '  Élodie  ',
          ' O’Connor-Müller ',
          ' test@example.com ',
          'test-password',
          'test-password',
        ];
        for (var i = 0; i < values.length; i++) {
          await tester.ensureVisible(find.byType(TextFormField).at(i));
          await tester.enterText(find.byType(TextFormField).at(i), values[i]);
        }
        await tester.ensureVisible(button);
        await tester.tap(button);
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (find.textContaining('Bitte bestätige').evaluate().isEmpty &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
        expect(signup!['email'], 'test@example.com');
        expect(signup!['password'], 'test-password');
        expect(signup!['data'], {
          'first_name': 'Élodie',
          'last_name': 'O’Connor-Müller',
        });
        expect(signup!.containsKey('customer_number'), isFalse);
        expect(find.textContaining('Bitte bestätige'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));
        await tester.ensureVisible(find.text('Bestätigungsmail erneut senden'));
        await tester.tap(find.text('Bestätigungsmail erneut senden'));
        final resendDeadline = DateTime.now().add(const Duration(seconds: 5));
        while (find.textContaining('Falls dein Konto').evaluate().isEmpty &&
            DateTime.now().isBefore(resendDeadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
        expect(resends, 1);
        expect(find.textContaining('Falls dein Konto'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await client.dispose();
      });
    },
  );
  test('Registrierung erreicht mit PKCE-Speicher den Server und verarbeitet Bestätigung', () async {
    var signupReached = false;
    final options = kochmasterAuthOptions('https://example.supabase.co');
    final transport = MockClient((request) async {
      expect(request.url.path, '/auth/v1/signup');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['code_challenge_method'], 's256');
      expect(body['code_challenge'], isNotEmpty);
      signupReached = true;
      return http.Response(
        jsonEncode({
          'id': '12345678-1234-4234-8234-123456789012',
          'aud': 'authenticated',
          'email': 'test@example.com',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-11-16T12:00:00Z',
        }),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: options,
      httpClient: transport,
    );
    try {
      final response = await client.auth.signUp(
        email: 'test@example.com',
        password: 'test-password',
      );
      expect(signupReached, isTrue);
      expect(response.session, isNull);
      expect(response.user!.email, 'test@example.com');
      expect(
        await options.pkceAsyncStorage!.getItem(
          key: 'supabase.auth.token-code-verifier',
        ),
        isNotEmpty,
      );
    } finally {
      await client.dispose();
      transport.close();
    }
  });
  test('Konkrete Validierung und Serverfehler', () {
    expect(validateName('  ', 'Vornamen'), isNotNull);
    expect(validateName('a' * 101, 'Nachnamen'), isNotNull);
    expect(validateName('李', 'Vornamen'), isNull);
    expect(validateEmail(''), contains('gib deine'));
    expect(validateEmail('abc'), contains('gültige'));
    expect(validateEmail(' person@example.com '), isNull);
    expect(validatePassword('abc', register: true), contains('mindestens 8'));
    expect(validatePassword('abc', register: false), isNull);
    expect(
      authErrorMessage(
        const AuthException('invalid', code: 'invalid_credentials'),
      ),
      contains('Passwort ist falsch'),
    );
    expect(
      authErrorMessage(
        const AuthException('invalid', code: 'email_address_not_authorized'),
      ),
      contains('SMTP'),
    );
    expect(
      authErrorMessage(
        const AuthException('invalid', code: 'over_email_send_rate_limit'),
      ),
      contains('Versandlimit'),
    );
  });
}
