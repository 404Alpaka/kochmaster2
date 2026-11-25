part of 'planning_page.dart';

extension _OfflineViews on _PlanningPageState {
  void offlineEditMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Für diese Änderung ist eine Verbindung nötig. Deine gespeicherten Daten bleiben offline verfügbar.',
        ),
      ),
    );
  }

  Future<void> cacheAccountState() async {
    try {
      await offlineCache.saveAccount({
        'user_id': widget.user!.id,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'personal': personalCloudData,
        'personal_revision': personalRevision,
        'households': [
          for (final h in connectedHouseholds)
            {
              'id': h.id,
              'name': h.name,
              'role': h.role,
              'members': h.members,
              'invitations': h.invitations,
            },
        ],
        'active_household': activeHouseholdId,
        'shared': lastSharedData,
        'shared_revision': sharedRevision,
      });
    } catch (_) {
      /* LocalStore reports a failed cache without hiding online data. */
    }
  }

  bool restoreOfflineAccount() {
    try {
      final cached = offlineCache.readAccount();
      if (cached == null || cached['user_id'] != widget.user!.id) return false;
      final households = (cached['households'] as List)
          .map(
            (row) => ConnectedHousehold.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
      if (households.any(
        (h) => !['admin', 'editor', 'viewer'].contains(h.role),
      )) {
        return false;
      }
      final household = cached['active_household'] as String?;
      if (household != null && !households.any((h) => h.id == household)) {
        return false;
      }
      personalCloudData = Map<String, dynamic>.from(cached['personal'] as Map);
      personalRevision = (cached['personal_revision'] as num).toInt();
      connectedHouseholds = households;
      activeHouseholdId = household;
      lastSharedData = Map<String, dynamic>.from(cached['shared'] as Map);
      sharedRevision = (cached['shared_revision'] as num).toInt();
      applyPreferences({
        ...defaultAccountData,
        ...personalCloudData,
        if (household != null) ...lastSharedData,
      });
      sharedWeekRepository = household == null
          ? null
          : HouseholdWeeklyPlanRepository(widget.client!, household);
      if (household != null) householdName = activeHousehold!.name;
      accountOffline = true;
      accountError = null;
      accountReady = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cacheWeekSafely(WeeklyPlan value) async {
    try {
      await offlineCache.saveWeek(
        week,
        offlineScope,
        value,
        extras: pantryShoppingItems,
      );
    } catch (_) {
      /* LocalStore exposes the failure to the user. */
    }
  }

  Future<WeeklyPlan> loadAvailableWeek() async {
    final cached = offlineCache.readWeek(week, offlineScope);
    if (weekRepository == null) {
      weekOffline = false;
      return cached?.plan ?? localWeekCache[dateKey(week)] ?? WeeklyPlan();
    }
    if (accountOffline) {
      weekOffline = true;
      if (cached == null) throw StateError('No offline copy of this week');
      return cached.plan;
    }
    WeeklyPlan remote;
    try {
      remote = await weekRepository!.load(week, recipes);
    } catch (error) {
      if (!isConnectionFailure(error) || cached == null) rethrow;
      weekOffline = true;
      return cached.plan;
    }
    weekOffline = false;
    if (cached?.pending == true) {
      if (readOnlyShared) {
        offlineNotice = 'Lokale Einkaufshäkchen bleiben auf diesem Gerät. Dir fehlen aktuell die Rechte zum Synchronisieren.';
        return remote;
      }
      final (merged, ignored) = cached!.reconcile(remote, pantryShoppingItems);
      try {
        if (merged.checked.length != remote.checked.length ||
            !merged.checked.containsAll(remote.checked)) {
          await weekRepository!.save(week, merged);
        }
        remote = merged;
        offlineNotice = ignored == 0
            ? 'Deine offline gesetzten Einkaufshäkchen wurden synchronisiert.'
            : 'Einkaufshäkchen wurden abgeglichen. Bei $ignored Positionen hat sich der Bedarf geändert; bitte prüfe sie erneut.';
      } catch (_) {
        offlineNotice = 'Lokale Einkaufshäkchen konnten noch nicht synchronisiert werden. Sie bleiben gespeichert. Aktualisiere den Cloudstand erneut.';
        weekOffline = true;
        return cached.plan;
      }
    }
    await cacheWeekSafely(remote);
    return remote;
  }

  Future<bool> saveOfflineChecks(
    Map<int, PlannedMeal> meals,
    Set<(String, String)> nextChecked,
  ) async {
    final cached = offlineCache.readWeek(week, offlineScope);
    if (cached == null ||
        readOnlyShared ||
        jsonEncode(WeeklyPlan(meals: meals).toJson()['meals']) !=
            jsonEncode(cached.plan.toJson()['meals'])) {
      offlineEditMessage();
      return false;
    }
    try {
      await offlineCache.saveWeek(
        week,
        offlineScope,
        WeeklyPlan(meals: meals, checked: nextChecked),
        pending: true,
        extras: pantryShoppingItems,
      );
      if (!mounted) return false;
      update(() {
        checked
          ..clear()
          ..addAll(nextChecked);
        weekOffline = true;
        saved = true;
        saveError = null;
      });
      return true;
    } catch (_) {
      if (mounted) {
        update(
          () => saveError = 'Die Einkaufshäkchen konnten nicht lokal gespeichert werden. Bitte prüfe den Gerätespeicher.',
        );
      }
      return false;
    }
  }

  List<Widget> offlinePlanningFlow() => [
    title(activeHousehold?.name ?? 'Deine gespeicherten Daten'),
    gap(12),
    if (tab == 1) ...[
      weekPicker(),
      gap(16),
      for (final entry in plan.entries)
        ListTile(
          title: Text(_PlanningPageState.days[entry.key]),
          subtitle: Text(
            '${entry.value.recipe.name} · ${entry.value.servings} Portionen',
          ),
          trailing: const Icon(Icons.menu_book_outlined),
          onTap: () => details(entry.value.recipe),
        ),
      if (plan.isEmpty && loadError == null)
        const Text('In der gespeicherten Woche sind keine Gerichte geplant.'),
    ],
    if (tab == 2) ...[
      for (final item in pantry)
        ListTile(
          title: Text(item['name'] as String? ?? 'Vorrat'),
          subtitle: Text(item['amount'] as String? ?? ''),
        ),
      for (final item in preparedMeals)
        ListTile(
          title: Text(item['name'] as String? ?? 'Mahlzeit'),
          subtitle: Text('${item['portions']} Portionen'),
        ),
      if (pantry.isEmpty && preparedMeals.isEmpty)
        const Text('Im gespeicherten Stand ist kein Vorrat erfasst.'),
    ],
  ];
}
