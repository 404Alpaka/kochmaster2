import 'package:material_ui/material_ui.dart';
import 'package:supabase/supabase.dart';

import '../data/session_storage.dart';
import 'auth_messages.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({
    super.key,
    required this.client,
    this.initialEmail = '',
    this.recovery = false,
    this.onComplete,
  });

  final SupabaseClient client;
  final String initialEmail;
  final bool recovery;
  final VoidCallback? onComplete;

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final form = GlobalKey<FormState>();
  late final email = TextEditingController(text: widget.initialEmail);
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  bool sent = false;
  String? message;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (widget.recovery) {
        if (widget.client.auth.currentSession == null) {
          setState(
            () => message =
                'Der Link ist abgelaufen. Bitte fordere einen neuen Link an.',
          );
          return;
        }
        await widget.client.auth.updateUser(
          UserAttributes(password: password.text),
        );
        password.clear();
        confirmation.clear();
        if (mounted) widget.onComplete?.call();
      } else {
        await widget.client.auth.resetPasswordForEmail(
          email.text.trim(),
          redirectTo: authRedirectUrl(),
        );
        if (mounted) {
          setState(() {
            sent = true;
            message = 'Falls für diese E-Mail-Adresse ein Konto besteht, erhältst du einen Link zum Zurücksetzen. Prüfe auch den Spam-Ordner. Öffne den Link in diesem Browser.';
          });
        }
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => message = authErrorMessage(error));
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Die Anfrage konnte nicht abgeschlossen werden. Bitte prüfe deine Verbindung und versuche es erneut.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.recovery ? 'Neues Passwort' : 'Passwort vergessen'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: AutofillGroup(
          child: Form(
            key: form,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  widget.recovery
                      ? 'Vergib ein neues Passwort'
                      : 'Zurück in dein Konto',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.recovery
                      ? 'Verwende mindestens 8 Zeichen. Dein Wochenplan bleibt erhalten.'
                      : 'Wir senden dir einen Link, mit dem du ein neues Passwort festlegen kannst.',
                ),
                const SizedBox(height: 24),
                if (!widget.recovery)
                  TextFormField(
                    controller: email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-Mail-Adresse',
                    ),
                    validator: validateEmail,
                  ),
                if (widget.recovery) ...[
                  TextFormField(
                    controller: password,
                    enabled: !busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Neues Passwort',
                      helperText: 'Mindestens 8 Zeichen',
                    ),
                    validator: (value) =>
                        validatePassword(value, register: true),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmation,
                    enabled: !busy,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Passwort wiederholen',
                    ),
                    validator: (value) => value == password.text
                        ? null
                        : 'Die Passwörter stimmen nicht überein.',
                  ),
                ],
                const SizedBox(height: 20),
                if (message != null) ...[
                  Text(message!, semanticsLabel: message),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: busy || sent ? null : submit,
                  child: Text(
                    busy
                        ? 'Bitte warten …'
                        : widget.recovery
                        ? 'Neues Passwort speichern'
                        : sent
                        ? 'Link angefordert'
                        : 'Link zum Zurücksetzen senden',
                  ),
                ),
                if (!widget.recovery)
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const Text('Zurück zur Anmeldung'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
