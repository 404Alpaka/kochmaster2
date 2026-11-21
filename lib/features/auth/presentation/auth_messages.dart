import 'package:supabase/supabase.dart';

String? validateName(String? input, String label) {
  final value = input?.trim() ?? '';
  if (value.isEmpty) return 'Bitte gib deinen $label ein.';
  if (value.runes.length > 100) return 'Bitte verwende höchstens 100 Zeichen.';
  return null;
}

String? validateEmail(String? input) {
  final value = input?.trim() ?? '';
  if (value.isEmpty) return 'Bitte gib deine E-Mail-Adresse ein.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
    return 'Bitte gib eine gültige E-Mail-Adresse ein, z. B. name@anbieter.de.';
  }
  return null;
}

String? validatePassword(String? value, {required bool register}) {
  if (value == null || value.isEmpty) return 'Bitte gib dein Passwort ein.';
  if (register) {
    if (value.runes.length < 8) {
      return 'Das Passwort benötigt mindestens 8 Zeichen.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Das Passwort benötigt mindestens einen Großbuchstaben.';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Das Passwort benötigt mindestens einen Kleinbuchstaben.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Das Passwort benötigt mindestens eine Zahl.';
    }
  }
  return null;
}

String authErrorMessage(AuthException error) => switch (error.code) {
  'invalid_credentials' =>
    'E-Mail-Adresse oder Passwort ist falsch. Bitte prüfe beide Angaben.',
  'email_not_confirmed' => 'Bitte bestätige zuerst deine E-Mail-Adresse über den Link in der Bestätigungsmail.',
  'weak_password' => 'Das Passwort ist zu schwach. Verwende mindestens 8 Zeichen mit Groß- und Kleinbuchstaben sowie mindestens einer Zahl.',
  'email_address_invalid' || 'validation_failed' => 'Die E-Mail-Adresse oder andere Angaben sind ungültig. Bitte überprüfe sie.',
  'email_address_not_authorized' => 'An diese Adresse kann Supabase noch keine Bestätigungsmail senden. Für weitere Empfänger muss ein eigener E-Mail-Versand (SMTP) eingerichtet werden.',
  'user_already_exists' || 'email_exists' =>
    'Für diese E-Mail-Adresse besteht bereits ein Konto. Bitte melde dich an.',
  'signup_disabled' =>
    'Neue Registrierungen sind im Projekt derzeit deaktiviert.',
  'email_provider_disabled' =>
    'Die Anmeldung per E-Mail ist im Projekt derzeit deaktiviert.',
  'over_email_send_rate_limit' => 'Das Versandlimit für Bestätigungsmails ist erreicht. Bitte warte und prüfe auch deinen Spam-Ordner.',
  'over_request_rate_limit' =>
    'Zu viele Anmeldeversuche. Bitte warte etwas und versuche es erneut.',
  'captcha_failed' =>
    'Die Sicherheitsprüfung ist fehlgeschlagen. Bitte versuche es erneut.',
  'unexpected_failure' => 'Supabase konnte die Anfrage nicht verarbeiten. Bitte versuche es später erneut.',
  _ =>
    'Die Anfrage wurde abgelehnt${error.code == null ? '' : ' (${error.code})'}. Bitte versuche es erneut.',
};
