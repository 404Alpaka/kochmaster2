import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:supabase/supabase.dart';

import '../data/session_storage.dart';
import '../data/auth_store.dart';
import 'password_reset_page.dart';

class AccountScope extends StatefulWidget {
  const AccountScope({
    super.key,
    required this.client,
    required this.storageKey,
    required this.builder,
    this.sessionStore,
  });
  final SupabaseClient client;
  final String storageKey;
  final Widget Function(User?) builder;
  final AuthStore? sessionStore;
  @override
  State<AccountScope> createState() => _AccountScopeState();
}

class _AccountScopeState extends State<AccountScope> {
  StreamSubscription<AuthState>? subscription;
  bool ready = false;
  String? error;
  bool recovery = false;
  late final AuthStore store = OrderedAuthStore(
    widget.sessionStore ?? createAuthStore(),
  );
  String get recoveryKey => '${widget.storageKey}-recovery';
  @override
  void initState() {
    super.initState();
    restore();
  }

  void persistSession(String key, String? value) {
    unawaited(
      store.write(key, value).catchError((Object _) {
        if (mounted) {
          setState(
            () => error = 'Die Anmeldung konnte nicht dauerhaft gespeichert werden. Bitte prüfe den Gerätespeicher oder die Website-Daten und melde dich bei Bedarf erneut an.',
          );
        }
      }),
    );
  }

  Future<void> restore() async {
    String? saved;
    try {
      saved = await store.read(widget.storageKey);
      recovery = await store.read(recoveryKey) == 'true';
    } catch (_) {
      error = 'Die gespeicherte Anmeldung konnte nicht gelesen werden. Bitte erneut anmelden.';
    }
    if (!mounted) return;
    subscription = widget.client.auth.onAuthStateChange.listen(
      (event) {
        if (event.event == AuthChangeEvent.passwordRecovery) {
          recovery = true;
          persistSession(recoveryKey, 'true');
        } else if (event.event == AuthChangeEvent.signedOut) {
          recovery = false;
          persistSession(recoveryKey, null);
        }
        if (event.session != null) {
          persistSession(
            widget.storageKey,
            jsonEncode(event.session!.toJson()),
          );
        } else if (event.event == AuthChangeEvent.signedOut) {
          persistSession(widget.storageKey, null);
        }
        if (mounted) {
          setState(() {});
        }
      },
      onError: (Object e) {
        if (mounted) {
          setState(
            () => error = 'Die Sitzung konnte nicht aktualisiert werden. Bitte erneut anmelden.',
          );
        }
      },
    );
    if (saved != null) {
      try {
        await widget.client.auth.recoverSession(saved);
      } on AuthRetryableFetchException {
        error = 'Die Sitzung konnte wegen eines Verbindungsfehlers nicht erneuert werden. Deine gespeicherte Anmeldung bleibt erhalten.';
      } on AuthException {
        persistSession(widget.storageKey, null);
        persistSession(recoveryKey, null);
        recovery = false;
      } on FormatException {
        persistSession(widget.storageKey, null);
        persistSession(recoveryKey, null);
        recovery = false;
        error =
            'Die gespeicherte Anmeldung ist ungültig. Bitte erneut anmelden.';
      } catch (_) {
        error = 'Sitzung konnte nicht wiederhergestellt werden. Bitte erneut anmelden.';
      }
    }
    final code = authCallbackCode();
    if (authCallbackError() != null) {
      error = 'Der E-Mail-Link ist ungültig oder abgelaufen. Bitte fordere einen neuen Bestätigungslink oder über „Passwort vergessen?“ einen neuen Reset-Link an.';
      clearAuthCallback();
    } else if (code != null) {
      try {
        await widget.client.auth.exchangeCodeForSession(code);
      } catch (_) {
        error = 'Der E-Mail-Link konnte nicht eingelöst werden. Er ist möglicherweise abgelaufen oder wurde in einem anderen Browser geöffnet. Bitte fordere bei Bedarf über „Passwort vergessen?“ einen neuen Link an.';
      } finally {
        clearAuthCallback();
      }
    }
    if (mounted) setState(() => ready = true);
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (recovery && widget.client.auth.currentSession != null) {
      return PasswordResetPage(
        client: widget.client,
        recovery: true,
        onComplete: () {
          persistSession(recoveryKey, null);
          setState(() => recovery = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dein neues Passwort wurde gespeichert.'),
            ),
          );
        },
      );
    }
    return Column(
      children: [
        if (error != null)
          MaterialBanner(
            content: Text(error!),
            actions: [
              TextButton(
                onPressed: () => setState(() => error = null),
                child: const Text('Schließen'),
              ),
            ],
          ),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(widget.client.auth.currentUser?.id),
            child: widget.builder(widget.client.auth.currentUser),
          ),
        ),
      ],
    );
  }
}
