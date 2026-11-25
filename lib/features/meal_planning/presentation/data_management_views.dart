part of 'planning_page.dart';

class _DataActionConfirmation extends StatefulWidget {
  const _DataActionConfirmation({
    required this.title,
    required this.description,
    required this.button,
    this.phrase,
    this.passwordRequired = false,
  });

  final String title, description, button;
  final String? phrase;
  final bool passwordRequired;

  @override
  State<_DataActionConfirmation> createState() =>
      _DataActionConfirmationState();
}

class _DataActionConfirmationState extends State<_DataActionConfirmation> {
  String phrase = '';
  String password = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.description),
          if (widget.phrase != null) ...[
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('data-action-phrase'),
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Zur Bestätigung: ${widget.phrase}',
              ),
              onChanged: (value) => setState(() => phrase = value),
            ),
          ],
          if (widget.passwordRequired) ...[
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('data-action-password'),
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Aktuelles Passwort',
              ),
              onChanged: (value) => setState(() => password = value),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed:
            (widget.phrase == null || phrase.trim() == widget.phrase) &&
                (!widget.passwordRequired || password.isNotEmpty)
            ? () => Navigator.pop(context, password)
            : null,
        child: Text(widget.button),
      ),
    ],
  );
}

extension _DataManagementViews on _PlanningPageState {
  AccountDataManagementRepository get dataManagement =>
      AccountDataManagementRepository(widget.client!);

  void dataMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String dataActionFailure(Object error) {
    if (error is TimeoutException) {
      return 'Der Server hat nicht rechtzeitig geantwortet. Ob die Aktion bereits ausgeführt wurde, ist unklar. Prüfe den Anmeldestatus und lade den Cloudstand vor einem erneuten Versuch.';
    }
    if (error is AuthException) return authErrorMessage(error);
    if (error is PostgrestException) {
      if (['PGRST202', '42883'].contains(error.code)) {
        return 'Die Datenverwaltung ist noch nicht freigeschaltet. Bitte aktualisiere die Datenbank mit 202611250001_account_data_management.sql.';
      }
      if (error.code == '40001') {
        return 'Deine Daten wurden zwischenzeitlich geändert. Lade den aktuellen Cloudstand und prüfe ihn vor dem Zurücksetzen.';
      }
      if (error.message.contains('Transfer household administration first')) {
        return 'Du bist noch die einzige Verwaltung eines gemeinsamen Haushalts. Ernenne dort zuerst eine andere Person zur Verwaltung.';
      }
      if (error.message.contains('Account owns storage objects')) {
        return 'Zu deinem Konto gehören noch hochgeladene Rezeptbilder. Lass diese vor der Kontolöschung übertragen oder entfernen. Dein Konto wurde nicht gelöscht.';
      }
    }
    return 'Die Aktion konnte nicht abgeschlossen werden. Prüfe die Verbindung und lade den aktuellen Cloudstand, bevor du es erneut versuchst.';
  }

  Future<void> performDataAction(Future<void> Function() action) async {
    if (profileBusy) return;
    update(() => dataActionBusy = true);
    try {
      await action();
    } catch (error) {
      dataMessage(dataActionFailure(error));
      if (mounted && cookingSession.recipe != null) startCookingTicker();
    } finally {
      if (mounted) update(() => dataActionBusy = false);
    }
  }

  Future<bool> removeCopiesAfterCloudChange() async {
    try {
      await removeLocalAccountCopies();
      return true;
    } catch (_) {
      dataMessage(
        'Die Cloud-Aktion wurde ausgeführt. Die lokale Kopie konnte nicht vollständig entfernt werden. Bitte entferne die lokalen App-Daten erneut, sobald der Gerätespeicher verfügbar ist.',
      );
      return false;
    }
  }

  Future<void> removeLocalAccountCopies() async {
    // Let earlier cooking writes finish before removing every scope's copy.
    cookingSession.ticker?.cancel();
    await cookingProgressWrite;
    final prefix = 'kochmaster-cooking-progress-${widget.user?.id ?? 'guest'}-';
    final keys = (await cookingProgressStore.getKeys())
        .where((key) => key.startsWith(prefix))
        .toSet();
    if (keys.isNotEmpty) await cookingProgressStore.clear(allowList: keys);
    await removeSessionValues([
      preferencesKey,
      'mise-pending-household-invite',
    ]);
    await offlineCache.clear();
  }

  void resetVisiblePersonalData() {
    update(() {
      applyPreferences(copyAccountData(defaultAccountData));
      localWeekCache.clear();
      plan.clear();
      checked.clear();
      cookingSession.recipe = null;
      cookingSession.page = 0;
      cookingSession.timers.clear();
      cookingSession.uses.clear();
      openedRecipe = null;
      draft = null;
      activeHouseholdId = null;
      sharedWeekRepository = null;
      pantryPage = 0;
      shoppingPage = 0;
      shoppingExample = false;
      householdPage = 0;
      saved = false;
      weekConflict = false;
      weekSaveUncertain = false;
      loadError = null;
      saveError = null;
    });
    unawaited(CookingRuntime.disableKeepScreenOn());
  }

  Future<void> exportAccountData() async {
    if (profileBusy) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    await performDataAction(() async {
      final data = accountConnected
          ? await dataManagement.exportData()
          : <String, dynamic>{
              'format': 'mise-account-export',
              'version': 1,
              'exported_at': DateTime.now().toUtc().toIso8601String(),
              'scope': 'guest',
              'preferences': preferencesData(),
              'week_plans': [
                for (final entry in {
                  ...localWeekCache,
                  dateKey(week): WeeklyPlan(
                    meals: Map<int, PlannedMeal>.from(plan),
                    checked: Set<(String, String)>.from(checked),
                  ),
                }.entries)
                  {'week_start': entry.key, ...entry.value.toJson()},
              ],
            };
      if (!mounted) return;
      await widget.dataExporter.save(data, origin);
    });
  }

  Future<void> clearLocalData() async {
    if (profileBusy) return;
    final confirmed = await showDialog<String>(
      context: context,
      builder: (_) => _DataActionConfirmation(
        title: 'Lokale App-Daten entfernen?',
        description: accountConnected
            ? 'Die lokale Kopie deiner Daten und dein Kochfortschritt werden auf diesem Gerät entfernt. Du wirst hier abgemeldet. Deine Cloud-Daten und sämtliche Haushaltsdaten bleiben erhalten. Beim nächsten Anmelden werden deine Cloud-Daten wieder geladen.'
            : 'Deine Gastdaten, Favoriten, eigenen Rezepte, Vorräte, Wochenpläne und der Kochfortschritt werden auf diesem Gerät entfernt. Exportiere sie vorher, wenn du sie behalten möchtest.',
        button: 'Vom Gerät entfernen',
      ),
    );
    if (confirmed == null || !mounted) return;
    await performDataAction(() async {
      // Deliberately do not call savePreferences or a cloud reset here.
      await removeLocalAccountCopies();
      if (!mounted) return;
      resetVisiblePersonalData();
      if (accountConnected) {
        await widget.client!.auth.signOut(scope: SignOutScope.local);
      } else {
        dataMessage('Lokale App-Daten wurden entfernt.');
      }
    });
  }

  Future<void> resetCloudData() async {
    if (!accountConnected || profileBusy) return;
    final confirmed = await showDialog<String>(
      context: context,
      builder: (_) => const _DataActionConfirmation(
        title: 'Persönliche Cloud-Daten zurücksetzen?',
        description: 'Deine persönlichen Favoriten, eigenen Rezepte, Vorräte, Einstellungen, Rückblicke und alle privaten Wochenpläne werden auf allen Geräten zurückgesetzt. Dein Konto, dein Kontoprofil und gemeinsame Haushaltsdaten bleiben erhalten. Diese Aktion lässt sich nicht rückgängig machen. Exportiere deine Daten bei Bedarf vorher.',
        phrase: 'ZURÜCKSETZEN',
        button: 'Cloud-Daten zurücksetzen',
      ),
    );
    if (confirmed == null || !mounted) return;
    await performDataAction(() async {
      await dataManagement.resetPersonalData(personalRevision);
      final localCleared = await removeCopiesAfterCloudChange();
      if (!mounted) return;
      resetVisiblePersonalData();
      await initializeAccountData(restoreProgress: false);
      if (localCleared && accountError == null && loadError == null) {
        dataMessage('Deine persönlichen Cloud-Daten wurden zurückgesetzt.');
      }
    });
  }

  Future<void> deleteOwnAccount() async {
    if (!accountConnected || profileBusy) return;
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DataActionConfirmation(
        title: 'Konto endgültig löschen?',
        description: 'Dein Konto, dein Kontoprofil und alle persönlichen Cloud-Daten einschließlich deiner privaten Wochenpläne werden unwiderruflich gelöscht. Du verlässt deine gemeinsamen Haushalte; deren Daten bleiben für die anderen Mitglieder bestehen. Haushalte, in denen nur du Mitglied bist, werden ebenfalls gelöscht. Bestätige die Löschung mit deinem aktuellen Passwort.',
        phrase: 'LÖSCHEN',
        passwordRequired: true,
        button: 'Konto endgültig löschen',
      ),
    );
    if (password == null || !mounted) return;
    await performDataAction(() async {
      await widget.client!.auth.signInWithPassword(
        email: widget.user!.email!,
        password: password,
      );
      await dataManagement.deleteAccount();
      await removeCopiesAfterCloudChange();
      if (mounted) resetVisiblePersonalData();
      await widget.client!.auth.signOut(scope: SignOutScope.local);
    });
  }
}
