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
              (
                Icons.calendar_today_outlined,
                'Planregeln',
                readOnlyShared ? null : editCommonRules,
              ),
              (
                Icons.payments_outlined,
                'Budget',
                readOnlyShared ? null : editBudget,
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
                'Rezepte verwalten',
                () {
                  if (admin) {
                    manageRecipes();
                  } else {
                    selectTab(0);
                    showRecipeCollection();
                  }
                },
              ),
              if (accountConnected &&
                  connectedHouseholds.isNotEmpty &&
                  activeHousehold == null)
                (
                  Icons.people_outline,
                  'Haushalte verwalten',
                  () => householdGo(14),
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
