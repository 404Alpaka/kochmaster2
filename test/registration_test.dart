import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:kochmaster/features/auth/data/create_auth_client.dart';
import 'package:kochmaster/features/auth/presentation/auth_messages.dart';

void main() {
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
