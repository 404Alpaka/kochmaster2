import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:supabase/supabase.dart';

import '../data/session_storage.dart';

class AccountScope extends StatefulWidget {
  const AccountScope({
    super.key,
    required this.client,
    required this.storageKey,
    required this.builder,
  });
  final SupabaseClient client;
  final String storageKey;
  final Widget Function(User?) builder;
  @override
  State<AccountScope> createState() => _AccountScopeState();
}

class _AccountScopeState extends State<AccountScope> {
  StreamSubscription<AuthState>? subscription;
  bool ready = false;
  String? error;
  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    subscription = widget.client.auth.onAuthStateChange.listen(
      (event) {
        if (event.session != null) {
          writeSession(widget.storageKey, jsonEncode(event.session!.toJson()));
        } else if (event.event == AuthChangeEvent.signedOut) {
          writeSession(widget.storageKey, null);
        }
        if (mounted) {
          setState(() {
            error = null;
          });
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
    final saved = readSession(widget.storageKey);
    if (saved != null) {
      try {
        await widget.client.auth.recoverSession(saved);
      } on AuthException {
        writeSession(widget.storageKey, null);
      } catch (_) {
        error = 'Sitzung konnte nicht wiederhergestellt werden. Bitte erneut anmelden.';
      }
    }
    final code = authCallbackCode();
    if (code != null) {
      try {
        await widget.client.auth.exchangeCodeForSession(code);
      } catch (_) {
        error = 'Die automatische Anmeldung über den Bestätigungslink ist fehlgeschlagen. Bitte melde dich mit E-Mail und Passwort an.';
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
