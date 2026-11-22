part of 'planning_page.dart';

extension _ProfileViews on _PlanningPageState {
  String get profileName {
    final metadata = widget.user?.userMetadata;
    final firstName = metadata?['first_name'];
    if (firstName is String && firstName.trim().isNotEmpty) {
      return firstName.trim();
    }
    final fullName = metadata?['full_name'];
    if (fullName is String && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    return widget.user?.email?.split('@').first ?? 'Gast';
  }

  bool get profileBusy =>
      accountPending > 0 ||
      accountLoading ||
      householdBusy ||
      saving ||
      loading;

  Future<void> editAccountProfile() async {
    if (widget.client == null || widget.user == null) return;
    final metadata = widget.user!.userMetadata;
    final firstName = TextEditingController(
      text: metadata?['first_name'] as String? ?? '',
    );
    final lastName = TextEditingController(
      text: metadata?['last_name'] as String? ?? '',
    );
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kontoprofil bearbeiten'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstName,
                decoration: const InputDecoration(labelText: 'Vorname'),
              ),
              gap(12),
              TextFormField(
                controller: lastName,
                decoration: const InputDecoration(labelText: 'Nachname'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client!.auth.updateUser(
        UserAttributes(
          data: {
            'first_name': firstName.text.trim(),
            'last_name': lastName.text.trim(),
          },
        ),
      );
      if (!mounted) return;
      await reloadAccountData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kontoprofil gespeichert.')));
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
      }
    } finally {
      firstName.dispose();
      lastName.dispose();
    }
  }

  Future<void> changeAccountEmail() async {
    if (widget.client == null || widget.user == null) return;
    final email = TextEditingController(text: widget.user!.email ?? '');
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('E-Mail-Adresse ändern'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'E-Mail-Adresse'),
            validator: validateEmail,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Änderung senden'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client!.auth.updateUser(
        UserAttributes(email: email.text.trim()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bestätige die Änderung über die E-Mail-Nachricht.'),
        ),
      );
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
      }
    } finally {
      email.dispose();
    }
  }

  Future<void> changeAccountPassword() async {
    if (widget.client == null || widget.user == null) return;
    final oldPassword = TextEditingController();
    final password = TextEditingController();
    final confirmation = TextEditingController();
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Passwort ändern'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('password-old'),
                controller: oldPassword,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Altes Passwort'),
              ),
              gap(12),
              TextFormField(
                key: const ValueKey('password-new'),
                controller: password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'Neues Passwort'),
              ),
              gap(12),
              TextFormField(
                key: const ValueKey('password-confirmation'),
                controller: confirmation,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Neues Passwort wiederholen',
                  errorText: null,
                ),
              ),
              if (error != null) ...[
                gap(12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                if (oldPassword.text.isEmpty) {
                  setDialogState(
                    () => error = 'Bitte gib dein altes Passwort ein.',
                  );
                  return;
                }
                final validation = validatePassword(
                  password.text,
                  register: true,
                );
                if (validation != null) {
                  setDialogState(() => error = validation);
                } else if (password.text != confirmation.text) {
                  setDialogState(
                    () => error =
                        'Die beiden neuen Passwörter stimmen nicht überein.',
                  );
                } else if (oldPassword.text == password.text) {
                  setDialogState(
                    () => error = 'Das neue Passwort muss sich vom alten Passwort unterscheiden.',
                  );
                } else {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Ändern'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client!.auth.signInWithPassword(
        email: widget.user!.email!,
        password: oldPassword.text,
      );
      await widget.client!.auth.updateUser(
        UserAttributes(password: password.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwort wurde geändert.')));
    } on AuthException catch (error) {
      if (mounted) {
        final message = error.code == 'invalid_credentials'
            ? 'Das alte Passwort ist nicht korrekt.'
            : authErrorMessage(error);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Das Passwort konnte nicht geändert werden. Bitte Verbindung prüfen und erneut versuchen.',
            ),
          ),
        );
      }
    } finally {
      oldPassword.dispose();
      password.dispose();
      confirmation.dispose();
    }
  }

  Future<void> exportLocalData() async {
    await Clipboard.setData(
      ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert(preferencesData()),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Einstellungen und lokale Daten in die Zwischenablage kopiert.',
        ),
      ),
    );
  }

  Future<void> clearLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lokale Daten löschen?'),
        content: const Text(
          'Favoriten, Rezepte, Planungsdaten und persönliche Einstellungen werden auf diesem Gerät zurückgesetzt. Bei einem verbundenen Konto wird die Synchronisation danach auf den leeren Stand gesetzt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB13727),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Daten löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    applyPreferences({});
    writeSession(preferencesKey, jsonEncode(preferencesData()));
    savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lokale Daten wurden zurückgesetzt.')),
    );
  }

  Future<void> profileRequiresAccount() async {
    if (widget.client != null && widget.user == null) {
      await account();
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Melde dich mit deinem Konto an, um einen Haushalt zu erstellen oder beizutreten.',
        ),
      ),
    );
  }

  Future<void> selectSharedProfile() async {
    if (!accountConnected) {
      await profileRequiresAccount();
      return;
    }
    if (profileBusy) return;
    if (activeHousehold != null) return;
    if (connectedHouseholds.length == 1) {
      await chooseAccountScope(connectedHouseholds.single.id);
      return;
    }
    if (connectedHouseholds.isEmpty) {
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_home_outlined),
                title: const Text('Haushalt erstellen'),
                onTap: () {
                  Navigator.pop(context);
                  createConnectedHousehold();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Einladung annehmen'),
                onTap: () {
                  Navigator.pop(context);
                  acceptConnectedInvitation();
                },
              ),
            ],
          ),
        ),
      );
      return;
    }
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Haushalt auswählen'),
        children: [
          for (final household in connectedHouseholds)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, household.id),
              child: Text(household.name),
            ),
        ],
      ),
    );
    if (id != null && mounted) await chooseAccountScope(id);
  }

  Widget profileSectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: AppColors.muted,
      ),
    ),
  );

  Widget profileMenuGroup(
    List<(IconData, String, VoidCallback?)> entries,
  ) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              color:
                  Theme.of(context).dividerTheme.color ??
                  Theme.of(context).colorScheme.outlineVariant,
            ),
          InkWell(
            onTap: entries[i].$3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    entries[i].$1,
                    color: entries[i].$3 == null
                        ? AppColors.muted
                        : AppColors.sage,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      entries[i].$2,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                        color: entries[i].$3 == null ? AppColors.muted : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.muted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget profileSummary() {
    final status = !accountConnected
        ? 'Lokal gespeichert'
        : accountError != null
        ? 'Nicht gespeichert'
        : profileBusy
        ? 'Speichert …'
        : 'Gespeichert';
    final statusIcon = accountError != null
        ? Icons.cloud_off_outlined
        : profileBusy
        ? Icons.sync
        : Icons.check;
    final statusColor = accountError != null
        ? AppColors.terracotta
        : AppColors.sage;
    Widget saved() => Tooltip(
      message: accountConnected
          ? 'Kontodaten aktualisieren'
          : 'Auf diesem Gerät gespeichert',
      child: InkWell(
        onTap: accountConnected && !profileBusy ? reloadAccountData : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 17),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            return Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.sage,
                  child: Text(
                    String.fromCharCode(profileName.runes.first).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      gap(2),
                      Text(
                        widget.user?.email ?? 'Nur auf diesem Gerät',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: muted.copyWith(fontSize: 13),
                      ),
                      gap(3),
                      Text(
                        widget.user == null
                            ? 'Kundennummer: nicht vergeben'
                            : 'Kundennummer: ${widget.user!.id}',
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted.copyWith(fontSize: 12),
                      ),
                      if (compact) ...[gap(4), saved()],
                    ],
                  ),
                ),
                if (!compact) ...[const SizedBox(width: 12), saved()],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget profilePlanningArea() => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(24),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                for (final shared in [false, true])
                  Expanded(
                    child: Material(
                      color: (activeHousehold != null) == shared
                          ? Theme.of(context).colorScheme.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: profileBusy
                            ? null
                            : shared
                            ? selectSharedProfile
                            : () async {
                                if (activeHousehold != null) {
                                  await chooseAccountScope(null);
                                }
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          child: Text(
                            shared ? 'Gemeinsam' : 'Privat',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: (activeHousehold != null) == shared
                                  ? AppColors.sage
                                  : AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          gap(14),
          Text(
            activeHousehold == null
                ? 'Wochenplan und Vorrat sind privat. Favoriten, eigene Rezepte und Ausschlüsse werden nie automatisch geteilt.'
                : 'Wochenplan und Vorrat gehören zu „${activeHousehold!.name}“. Favoriten, eigene Rezepte und persönliche Ausschlüsse bleiben privat.',
            style: muted.copyWith(fontSize: 14),
          ),
          gap(8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: profileBusy
                      ? null
                      : accountConnected
                      ? createConnectedHousehold
                      : profileRequiresAccount,
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.add_home_outlined, size: 21),
                  label: const Text(
                    'Haushalt erstellen',
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton.icon(
                  onPressed: profileBusy
                      ? null
                      : accountConnected
                      ? acceptConnectedInvitation
                      : profileRequiresAccount,
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.link, size: 21),
                  label: const Text(
                    'Einladung annehmen',
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ],
          ),
          if (activeHousehold != null) ...[
            gap(6),
            Text(
              'Deine Rolle: ${householdRoleLabel(activeHousehold!.role)}',
              style: muted,
            ),
            gap(8),
            profileMenuGroup([
              (
                Icons.people_outline,
                'Haushalt verwalten',
                () => householdGo(14),
              ),
              (Icons.tune, 'Mitessende & feste Regeln', editPlanningDiners),
            ]),
          ],
          if (householdError != null)
            Text(
              householdError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
  );

  List<Widget> profileView() => [
    Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Profil',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: AppColors.sage),
            ),
            gap(18),
            profileSummary(),
            profileSectionLabel('PLANUNGSBEREICH'),
            profilePlanningArea(),
            profileSectionLabel('MEINE EINSTELLUNGEN'),
            profileMenuGroup([
              (
                Icons.restaurant_outlined,
                'Essenspräferenzen',
                readOnlyShared ? null : () => editFoodPreferences(),
              ),
              (
                Icons.block_outlined,
                'Ausschlüsse & Abneigungen',
                readOnlyShared ? null : () => householdGo(7),
              ),
            ]),
            profileSectionLabel('MEHR'),
            profileMenuGroup([
              (
                Icons.bar_chart_outlined,
                'Wochenrückblick',
                readOnlyShared ? null : () => householdGo(11),
              ),
              (
                Icons.edit_note_outlined,
                admin ? 'Rezepte verwalten' : 'Meine Rezepte',
                () {
                  if (admin) {
                    manageRecipes();
                  } else {
                    selectTab(0);
                    showRecipeCollection();
                  }
                },
              ),
            ]),
            profileSectionLabel('MEIN KONTO'),
            profileMenuGroup([
              if (widget.user != null)
                (
                  Icons.person_outline,
                  'Kontoprofil bearbeiten',
                  profileBusy ? null : editAccountProfile,
                ),
              if (widget.user != null)
                (
                  Icons.email_outlined,
                  'E-Mail-Adresse ändern',
                  profileBusy ? null : changeAccountEmail,
                ),
              if (widget.user != null)
                (
                  Icons.password_outlined,
                  'Passwort ändern',
                  profileBusy ? null : changeAccountPassword,
                ),
              (
                Icons.palette_outlined,
                appThemeMode.value == ThemeMode.dark
                    ? 'Hellmodus verwenden'
                    : 'Dunkelmodus verwenden',
                () {
                  final dark = appThemeMode.value != ThemeMode.dark;
                  appThemeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
                  writeSession('mise-theme-mode', dark ? 'dark' : 'light');
                },
              ),
            ]),
            profileSectionLabel('DATEN & DATENSCHUTZ'),
            profileMenuGroup([
              (
                Icons.download_outlined,
                'Meine Daten exportieren',
                exportLocalData,
              ),
              (
                Icons.delete_sweep_outlined,
                'Lokale Daten löschen',
                profileBusy ? null : clearLocalData,
              ),
              if (!accountConnected && widget.client == null)
                (
                  Icons.people_outline,
                  'Haushalts-Demo ansehen',
                  () => householdGo(15),
                ),
            ]),
            gap(22),
            if (widget.user != null && widget.client != null)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB13727),
                  side: const BorderSide(color: Color(0xFFB13727)),
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: profileBusy
                    ? null
                    : () async {
                        if (!accountConnected || await flushAccountData()) {
                          await signOut();
                        }
                      },
                child: const Text('Abmelden'),
              )
            else if (widget.client != null)
              FilledButton(
                onPressed: account,
                child: const Text('Anmelden oder registrieren'),
              ),
            gap(12),
          ],
        ),
      ),
    ),
  ];
}
