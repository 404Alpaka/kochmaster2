import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/features/auth/data/auth_callback_uri.dart';

void main() {
  test(
    'Rückleitung behält Origin und Pfad, entfernt Callback und Fragment',
    () {
      expect(
        authReturnAddress(
          Uri.parse('http://localhost:8766/app/?code=secret#section'),
        ),
        'http://localhost:8766/app/',
      );
      expect(
        authReturnAddress(
          Uri.parse('https://example.com/app%20path/?code=private#section'),
        ),
        'https://example.com/app%20path/',
      );
    },
  );
  test('Erfolgreicher Code wird entfernt, übrige Parameter bleiben', () {
    final result = withoutAuthCallback(
      Uri.parse('https://example.com/?code=secret&lang=de#recipes'),
    );
    expect(result.queryParameters, {'lang': 'de'});
    expect(result.fragment, 'recipes');
    expect(
      withoutAuthCallback(Uri.parse('https://example.com/?code=secret'))
          .toString(),
      'https://example.com/',
    );
  });
  test(
    'Abgelaufene Links werden als Query und Fragment erkannt und bereinigt',
    () {
      for (final value in [
        '?error=access_denied&error_code=otp_expired&error_description=private',
        '#error=access_denied&error_code=otp_expired&error_description=private',
      ]) {
        final uri = Uri.parse('https://example.com/$value');
        expect(authErrorFromUri(uri), 'otp_expired');
        expect(withoutAuthCallback(uri).toString(), 'https://example.com/');
      }
      expect(
        authErrorFromUri(Uri.parse('https://example.com/?code=valid')),
        isNull,
      );
    },
  );
}
