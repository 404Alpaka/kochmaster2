part of 'planning_page.dart';

extension _ConnectedHouseholdViews on _PlanningPageState {
  List<PlanningDiner> get planningDiners => activeHousehold == null ? [] : [
    for(final member in activeHousehold!.members) PlanningDiner.fromJson(member['user_id'] as String, member['email'] as String? ?? 'Mitglied', householdDinerRules[member['user_id']] ?? {}),
    for(final entry in householdDinerRules.entries.where((e)=>e.key.startsWith('guest:'))) PlanningDiner.fromJson(entry.key,entry.value['name'] as String? ?? 'Weitere Person',entry.value),
  ];

  Future<void> editPlanningDiners() async {
    if(activeHousehold == null) return;
    final target = activeHouseholdId;
    final result = await Navigator.of(context).push<List<PlanningDiner>>(MaterialPageRoute(builder:(_)=>HouseholdDinersPage(initial:planningDiners,readOnly:readOnlyShared)));
    if(result == null || !mounted || readOnlyShared || activeHouseholdId != target) return;
    update(() { householdDinerRules..clear()..addAll({for(final d in result) d.id:d.toJson()}); });
    savePreferences();
  }

  Future<String?> householdText(
    String title,
    String label, {
    String initial = '',
    bool email = false,
  }) async {
    var value = initial;
    final key = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: key,
          child: TextFormField(
            initialValue: initial,
            autofocus: true,
            keyboardType: email
                ? TextInputType.emailAddress
                : TextInputType.text,
            decoration: InputDecoration(labelText: label),
            onChanged: (v) => value = v,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Bitte ausfüllen.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(context, value.trim());
              }
            },
            child: const Text('Weiter'),
          ),
        ],
      ),
    );
  }

  Future<void> householdOperation(Future<void> Function() operation) async {
    if (householdBusy ||
        saving ||
        loading ||
        !await flushAccountData() ||
        !mounted) {
      return;
    }
    update(() {
      householdBusy = true;
      householdError = null;
    });
    try {
      await operation();
      final rows = await householdRepository!.list();
      if (mounted) update(() => connectedHouseholds = rows);
    } catch (error) {
      if (mounted) {
        update(
          () => householdError =
              error is PostgrestException &&
                  (error.message.contains('Last admin') ||
                      error.message.contains('Transfer administration'))
              ? 'Die letzte Verwaltung kann nicht austreten oder ihre Rolle abgeben. Ernenne zuerst eine weitere Verwaltung.'
              : accountFailure(error),
        );
      }
    } finally {
      if (mounted) update(() => householdBusy = false);
    }
  }

  Future<void> createConnectedHousehold() async {
    final name = await householdText('Neuer Haushalt', 'Haushaltsname');
    if (name == null || !mounted) return;
    String? id;
    await householdOperation(() async {
      id = await householdRepository!.create(name);
    });
    if (id != null && mounted && householdError == null) {
      await chooseAccountScope(id);
    }
  }

  Future<void> acceptConnectedInvitation() async {
    final value = await householdText(
      'Einladung annehmen',
      'Einladungslink oder Code',
      initial:
          readSession('mise-pending-household-invite') ??
          Uri.base.queryParameters['household_invite'] ??
          '',
    );
    if (value == null || !mounted) return;
    final token =
        Uri.tryParse(value)?.queryParameters['household_invite'] ?? value;
    String? id;
    await householdOperation(() async {
      id = await householdRepository!.accept(token);
      writeSession('mise-pending-household-invite', null);
    });
    if (id != null && mounted && householdError == null) {
      await chooseAccountScope(id);
    }
  }

  Future<void> inviteConnectedMember() async {
    final household = activeHousehold;
    if (household == null || !household.isAdmin) return;
    final email = await householdText(
      'Person einladen',
      'E-Mail-Adresse',
      email: true,
    );
    if (email == null || !mounted) return;
    final role = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Rechte nach Annahme'),
        children: [
          for (final role in ['editor', 'viewer'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, role),
              child: Text(householdRoleLabel(role)),
            ),
        ],
      ),
    );
    if (role == null || !mounted) return;
    String? token;
    await householdOperation(() async {
      token = await householdRepository!.invite(household.id, email, role);
    });
    if (token == null || !mounted) return;
    final link = Uri.base
        .replace(queryParameters: {'household_invite': token!}, fragment: '')
        .toString();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Einladung erstellt'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Für $email · 7 Tage gültig. Nur dieses bestätigte Konto kann die Einladung annehmen.',
              ),
              gap(12),
              const Text(
                'Teile diesen Link mit der Person. Es wird keine E-Mail automatisch versendet.',
              ),
              gap(12),
              SelectableText(link),
              gap(12),
              const Text(
                'Der Link wird nur jetzt angezeigt. Eine neue Einladung ersetzt eine frühere Einladung an diese Adresse.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
            },
            child: const Text('Link kopieren'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token!));
            },
            child: const Text('Code kopieren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fertig'),
          ),
        ],
      ),
    );
  }

  Future<void> changeConnectedRole(Map<String, dynamic> member) async {
    final household = activeHousehold!;
    final role = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Rolle für ${member['email']}'),
        children: [
          for (final role in ['admin', 'editor', 'viewer'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, role),
              child: Text(householdRoleLabel(role)),
            ),
        ],
      ),
    );
    if (role == null || !mounted) return;
    await householdOperation(
      () => householdRepository!.changeRole(
        household.id,
        member['user_id'] as String,
        role,
      ),
    );
  }

  Future<void> leaveConnectedHousehold() async {
    final household = activeHousehold!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Haushalt verlassen?'),
        content: Text(
          'Dein Zugriff auf „${household.name}“ endet. Gemeinsame Daten bleiben für die anderen Mitglieder bestehen. Deine privaten Daten bleiben bei dir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Haushalt verlassen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await householdOperation(() => householdRepository!.leave(household.id));
    if (mounted && householdError == null) await chooseAccountScope(null);
  }

  List<Widget> connectedHouseholdView() => [
    title('Zusammen isst’s besser.'),
    gap(12),
    recipeAction('Essenspräferenzen', false, () => editFoodPreferences()),
    gap(12),
    Text('Dein Konto. Eure gemeinsame Küche.', style: muted),
    gap(20),
    if (readSession('mise-pending-household-invite') != null) ...[
      surveyCard(
        'Du hast eine Einladung',
        'Melde dich mit der eingeladenen und bestätigten E-Mail-Adresse an und nimm die Einladung an.',
      ),
      gap(12),
    ],
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section('Planungsbereich', action: IconButton(
            tooltip: 'Kontodaten aktualisieren',
            onPressed: accountPending > 0 || saving || loading || householdBusy
                ? null
                : reloadAccountData,
            icon: const Icon(Icons.refresh, size: 20),
          )),
          DropdownButtonFormField<String>(
            key: ValueKey('account-scope-${activeHouseholdId ?? 'private'}'),
            initialValue: activeHouseholdId ?? 'private',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Privat oder gemeinsam',
            ),
            items: [
              const DropdownMenuItem(
                value: 'private',
                child: Text('Privat · nur für dich'),
              ),
              for (final household in connectedHouseholds)
                DropdownMenuItem(
                  value: household.id,
                  child: Text(household.name),
                ),
            ],
            onChanged: householdBusy
                ? null
                : (value) {
                    if (value != null) {
                      chooseAccountScope(value == 'private' ? null : value);
                    }
                  },
          ),
          gap(12),
          Text(
            activeHousehold == null
                ? 'Dein Wochenplan und Vorrat sind privat. Favoriten, eigene Rezepte und persönliche Ausschlüsse werden nie automatisch geteilt.'
                : 'Plan, Einkaufsliste, Vorrat und Planregeln gehören zu diesem Haushalt. Persönliche Rezepte, Favoriten und Ausschlüsse bleiben privat.',
            style: muted,
          ),
        ],
      ),
    ),
    gap(18),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: householdBusy ? null : createConnectedHousehold,
          icon: const Icon(Icons.add_home_outlined),
          label: const Text('Haushalt erstellen'),
        ),
        OutlinedButton.icon(
          onPressed: householdBusy ? null : acceptConnectedInvitation,
          icon: const Icon(Icons.link),
          label: const Text('Einladung annehmen'),
        ),
      ],
    ),
    gap(20),
    if (householdBusy) const LinearProgressIndicator(),
    if (householdError != null) ...[
      Text(
        householdError!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      gap(16),
    ],
    if (activeHousehold != null) ...[
      recipeAction('Mitessende & feste Regeln',false,editPlanningDiners), gap(16),
      section(activeHousehold!.name),
      Text(
        'Deine Rolle: ${householdRoleLabel(activeHousehold!.role)}',
        style: muted,
      ),
      gap(12),
      for (final member in activeHousehold!.members) ...[
        panel(
          Row(
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member['email'] as String? ?? 'Mitglied',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      householdRoleLabel(member['role'] as String),
                      style: muted,
                    ),
                  ],
                ),
              ),
              if (activeHousehold!.isAdmin)
                IconButton(
                  tooltip: 'Rolle ändern',
                  onPressed: householdBusy
                      ? null
                      : () => changeConnectedRole(member),
                  icon: const Icon(Icons.manage_accounts_outlined),
                ),
            ],
          ),
        ),
        gap(12),
      ],
      if (activeHousehold!.isAdmin) ...[
        recipeAction('Person einladen', false, inviteConnectedMember),
        gap(18),
        section('Offene Einladungen'),
        if (activeHousehold!.invitations.isEmpty)
          Text('Keine offenen Einladungen.', style: muted),
        for (final invitation in activeHousehold!.invitations)
          panel(
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(invitation['email'] as String),
              subtitle: Text(
                '${householdRoleLabel(invitation['role'] as String)} · 7 Tage ab Erstellung',
              ),
              trailing: IconButton(
                tooltip: 'Einladung widerrufen',
                onPressed: householdBusy
                    ? null
                    : () => householdOperation(
                        () => householdRepository!.revoke(
                          invitation['id'] as String,
                        ),
                      ),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        gap(18),
      ],
      if (activeHousehold!.canEdit) ...[
        recipeAction(
          'Gemeinsame Planregeln bearbeiten',
          false,
          editCommonRules,
        ),
        gap(12),
        recipeAction('Gemeinsames Budget bearbeiten', false, editBudget),
        gap(12), recipeAction('Ausschlüsse & Abneigungen', false, () => householdGo(7)),
        gap(12), recipeAction('Gemeinsamer Wochenrückblick', false, () => householdGo(11)),
        gap(18),
      ],
      recipeAction('Gemeinsamen Wochenplan öffnen', false, () => selectTab(1)),
      gap(12),
      recipeAction('Haushalt verlassen', false, leaveConnectedHousehold),
      gap(20),
      surveyCard(
        'Deine Daten bleiben deine Daten',
        'Persönliche Regeln bleiben privat. Zusätzlich gelten die ausdrücklich erfassten Regeln aller aktiven Mitessenden. Diese gemeinsamen Angaben sind im Haushalt sichtbar; Bewertungen und Notizen werden nicht übernommen.',
      ),
      gap(20),
    ] else ...[
      recipeAction(
        'Essenspräferenzen & Planung',
        false,
        editFoodPreferences,
      ),
      gap(12),
      recipeAction(
        'Ausschlüsse & Abneigungen',
        false,
        () => householdGo(7),
      ),
      gap(12),
      recipeAction('Wochenrückblick', false, () => householdGo(11)),
      gap(20),
    ],
    section('Dein Konto'),
    Text(widget.user!.email ?? '', style: muted),
    gap(12),
    recipeAction('Abmelden', false, () async {
      if (await flushAccountData()) await signOut();
    }),
    if (admin)
      TextButton.icon(
        onPressed: manageRecipes,
        icon: const Icon(Icons.edit_note),
        label: const Text('Rezepte verwalten'),
      ),
  ];
}
