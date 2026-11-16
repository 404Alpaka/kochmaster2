import 'package:material_ui/material_ui.dart';

import 'auth_messages.dart';

import 'package:supabase/supabase.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool register = false;
  bool busy = false;
  bool visible = false;
  String? message;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (register) {
        final result = await widget.client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
        );
        if (!mounted) return;
        if (result.session == null) {
          password.clear();
          confirmation.clear();
          setState(() {
            register = false;
            message = 'Bitte bestätige deine E-Mail-Adresse über die zugesandte Nachricht. Melde dich danach hier an.';
          });
        } else {
          Navigator.pop(context);
        }
      } else {
        await widget.client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
        if (mounted) Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => message = authErrorMessage(e));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => message =
              error is StateError && error.message == 'auth_storage_unavailable'
              ? 'Der Browser blockiert den benötigten Speicher. Bitte erlaube Website-Daten oder nutze ein normales Browserfenster.'
              : error is TypeError || error is AssertionError
              ? 'Die Anmeldung konnte wegen eines technischen Fehlers nicht gestartet werden. Bitte lade die Seite neu.'
              : 'Verbindung zu Supabase fehlgeschlagen. Bitte prüfe deine Internetverbindung und versuche es erneut.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(register ? 'Konto erstellen' : 'Anmelden')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: AutofillGroup(
          child: Form(
            key: form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  register ? 'Dein Kochmaster-Konto' : 'Willkommen zurück',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Speichere deinen Wochenplan und deine Einkaufsliste und verwende sie später weiter.',
                ),
                const SizedBox(height: 24),
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
                TextFormField(
                  controller: password,
                  enabled: !busy,
                  obscureText: !visible,
                  autofillHints: [
                    register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Passwort',
                    helperText: register ? 'Mindestens 8 Zeichen' : null,
                    suffixIcon: IconButton(
                      tooltip: visible
                          ? 'Passwort verbergen'
                          : 'Passwort anzeigen',
                      onPressed: () => setState(() => visible = !visible),
                      icon: Icon(
                        visible ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (v) => validatePassword(v, register: register),
                  onFieldSubmitted: (_) {
                    if (!busy && !register) submit();
                  },
                ),
                if (register)
                  TextFormField(
                    controller: confirmation,
                    enabled: !busy,
                    obscureText: true,
                    onFieldSubmitted: (_) {
                      if (!busy) submit();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Passwort wiederholen',
                    ),
                    validator: (v) => v == password.text
                        ? null
                        : 'Die Passwörter stimmen nicht überein.',
                  ),
                const SizedBox(height: 20),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(message!, semanticsLabel: message),
                  ),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Bitte warten …'
                        : register
                        ? 'Registrieren'
                        : 'Anmelden',
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          register = !register;
                          message = null;
                          password.clear();
                          confirmation.clear();
                          form.currentState?.reset();
                        }),
                  child: Text(
                    register
                        ? 'Ich habe bereits ein Konto'
                        : 'Neues Konto erstellen',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
