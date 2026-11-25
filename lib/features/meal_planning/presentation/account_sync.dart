part of 'planning_page.dart';

extension _AccountSync on _PlanningPageState {
  Map<String, dynamic> copyAccountData(Map<String, dynamic> data) =>
      jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

  String accountFailure(Object error) {
    if (error is PostgrestException) {
      if (error.message.contains('Private data cannot be shared'))
        return 'Für die gemeinsamen Planerregeln fehlt die Datenbankmigration 202611190006_planner_household_resources.sql. Bitte anwenden und den Cloudstand erneut laden.';
      var code = error.code;
      if (code == '404' || code == '400') {
        try {
          final value = jsonDecode(error.message);
          if (value is Map && value['code'] is String) {
            code = value['code'] as String;
          }
        } catch (_) {
          /* Preserve the original code for non-JSON errors. */
        }
      }
      if (['42P01', 'PGRST202', 'PGRST205', '42883'].contains(code)) {
        return 'Die Datenbank-Erweiterung für Kontodaten und Haushalte fehlt. Bitte die Migration 202611170003_account_data_and_households.sql ausführen.';
      }
      if (code == '40001') {
        return 'Diese Daten wurden auf einem anderen Gerät geändert. Lade den Cloudstand, bevor du weiterbearbeitest. Deine ungespeicherten Änderungen sind hier noch sichtbar.';
      }
      if (code == '42501') {
        return 'Deinem Konto fehlen die Rechte oder eine Einladung ist ungültig, abgelaufen oder für ein anderes Konto bestimmt. Bitte Haushalt und Anmeldung prüfen.';
      }
    }
    return 'Kontodaten konnten nicht synchronisiert werden. Prüfe die Verbindung und versuche es erneut.';
  }

  Future<void> initializeAccountData({bool restoreProgress = true}) async {
    update(() {
      accountLoading = true;
      accountError = null;
      offlineNotice = null;
    });
    try {
      if (widget.client!.auth.currentSession?.isExpired == true) {
        await widget.client!.auth.refreshSession();
      }
      accountRepository ??= AccountDataRepository(
        widget.client!,
        widget.user!.id,
      );
      householdRepository ??= HouseholdRepository(widget.client!);
      final document = await accountRepository!.load();
      if (!mounted) return;
      if (document == null) {
        personalCloudData = copyAccountData(
          privateAccountData(
            preferencesData(),
            personalCloudData,
            householdActive: activeHouseholdId != null,
          ),
        );
        personalRevision = await accountRepository!.save(personalCloudData, 0);
      } else {
        personalCloudData = copyAccountData({
          ...defaultAccountData,
          ...document.data,
        });
        personalRevision = document.revision;
      }
      final households = await householdRepository!.list();
      if (!mounted) return;
      connectedHouseholds = households;
      activeHouseholdId = personalCloudData['activeHouseholdId'] as String?;
      if (activeHousehold == null) activeHouseholdId = null;
      applyPreferences({...defaultAccountData, ...personalCloudData});
      sharedWeekRepository = null;
      if (activeHousehold != null) await loadSharedAccountState();
      if (!mounted) return;
      draft = null;
      cookingTicker?.cancel();
      cookingRecipe = null;
      cookingPage = 0;
      unawaited(CookingRuntime.disableKeepScreenOn());
      localWeekCache.clear();
      plan.clear();
      checked.clear();
      accountReady = true;
      accountOffline = false;
      writeSession(preferencesKey, jsonEncode(personalCloudData));
      await cacheAccountState();
      if (restoreProgress) {
        await restoreCookingProgress();
      }
      if (!mounted) return;
      if (weekRepository != null) await loadWeek();
    } catch (error) {
      if (mounted && isConnectionFailure(error) && restoreOfflineAccount()) {
        if (restoreProgress) await restoreCookingProgress();
        if (mounted) await loadWeek();
      } else if (mounted) {
        update(() => accountError = accountFailure(error));
      }
    } finally {
      if (mounted) update(() => accountLoading = false);
    }
  }

  Future<void> loadSharedAccountState() async {
    final household = activeHousehold!;
    final document = await householdRepository!.loadState(household.id);
    if (!mounted) return;
    sharedRevision = document.revision;
    lastSharedData = {
      ...sharedAccountData(defaultAccountData),
      ...document.data,
    };
    applyPreferences({...personalCloudData, ...lastSharedData});
    householdName = household.name;
    sharedWeekRepository = HouseholdWeeklyPlanRepository(
      widget.client!,
      household.id,
    );
  }

  void queueAccountSave(Map<String, dynamic> snapshot) {
    final personal = copyAccountData(
      privateAccountData(
        snapshot,
        personalCloudData,
        householdActive: activeHouseholdId != null,
      ),
    );
    final shared = activeHouseholdId == null
        ? null
        : copyAccountData(sharedAccountData(snapshot));
    final household = activeHouseholdId;
    writeSession(preferencesKey, jsonEncode(personal));
    update(() => accountPending++);
    accountSaveTail = accountSaveTail
        .then((_) async {
          if (!mounted || accountError != null) return;
          try {
            personalRevision = await accountRepository!.save(
              personal,
              personalRevision,
            );
            personalCloudData = personal;
            if (shared != null &&
                household != null &&
                jsonEncode(shared) != jsonEncode(lastSharedData)) {
              sharedRevision = await householdRepository!.saveState(
                household,
                shared,
                sharedRevision,
              );
              lastSharedData = shared;
            }
            await cacheAccountState();
          } catch (error) {
            if (mounted) update(() => accountError = accountFailure(error));
          }
        })
        .whenComplete(() {
          if (mounted) update(() => accountPending--);
        });
  }

  Future<bool> flushAccountData() async {
    while (mounted && accountPending > 0) {
      await accountSaveTail;
    }
    return mounted && accountError == null;
  }

  Future<void> chooseAccountScope(String? id) async {
    if (cloudOffline) {
      offlineEditMessage();
      return;
    }
    if (accountLoading || saving || loading || householdBusy || preparedBusy)
      return;
    update(() {
      accountLoading = true;
      householdError = null;
    });
    if (!await flushAccountData()) {
      if (mounted) update(() => accountLoading = false);
      return;
    }
    if (!mounted) return;
    try {
      final oldPrivate = copyAccountData(personalCloudData);
      final oldId = activeHouseholdId;
      // Load target before replacing visible data; private data never becomes a household seed.
      final target = id == null
          ? null
          : await householdRepository!.loadState(id);
      if (!mounted) return;
      personalCloudData = oldPrivate;
      activeHouseholdId = id;
      if (id != null && activeHousehold == null) {
        activeHouseholdId = oldId;
        throw StateError('Haushalt nicht verfügbar');
      }
      applyPreferences({...defaultAccountData, ...personalCloudData});
      sharedWeekRepository = null;
      if (target != null) {
        sharedRevision = target.revision;
        lastSharedData = {
          ...sharedAccountData(defaultAccountData),
          ...target.data,
        };
        applyPreferences({...personalCloudData, ...lastSharedData});
        householdName = activeHousehold!.name;
        sharedWeekRepository = HouseholdWeeklyPlanRepository(
          widget.client!,
          id!,
        );
      }
      cookingTicker?.cancel();
      cookingRecipe = null;
      cookingPage = 0;
      cookingTimers.clear();
      unawaited(CookingRuntime.disableKeepScreenOn());
      draft = null;
      surveyStep = 0;
      householdPage = 0;
      localWeekCache.clear();
      plan.clear();
      checked.clear();
      personalCloudData['activeHouseholdId'] = id;
      personalRevision = await accountRepository!.save(
        personalCloudData,
        personalRevision,
      );
      writeSession(preferencesKey, jsonEncode(personalCloudData));
      await cacheAccountState();
      await restoreCookingProgress();
      if (!mounted) return;
      if (weekRepository != null) await loadWeek();
    } catch (error) {
      if (mounted) update(() => accountError = accountFailure(error));
    } finally {
      if (mounted) update(() => accountLoading = false);
    }
  }

  Future<void> reloadAccountData() async {
    if (saving || householdBusy || preparedBusy) return;
    await accountSaveTail;
    if (!mounted) return;
    if (accountError != null && accountReady) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cloudstand laden?'),
          content: const Text(
            'Ungespeicherte Änderungen auf diesem Gerät werden durch den gespeicherten Cloudstand ersetzt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cloudstand laden'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await initializeAccountData();
  }

  Widget accountDataScaffold() {
    if (accountLoading || (!accountReady && accountError == null)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!accountReady) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dein Konto')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                gap(18),
                Text(accountError ?? 'Kontodaten werden geladen.'),
                gap(18),
                FilledButton(
                  onPressed: initializeAccountData,
                  child: const Text('Erneut versuchen'),
                ),
                TextButton(onPressed: signOut, child: const Text('Abmelden')),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        if (cloudOffline || offlineNotice != null)
          MaterialBanner(
            content: Text(
              cloudOffline
                  ? 'Offline: gespeicherter Stand. Einkaufshäkchen werden auf diesem Gerät gesichert. Für weitere Änderungen bitte verbinden.${offlineNotice == null ? '' : '\n$offlineNotice'}'
                  : offlineNotice!,
            ),
            actions: [
              TextButton(
                onPressed: profileBusy ? null : reloadAccountData,
                child: const Text('Cloudstand aktualisieren'),
              ),
              if (!cloudOffline)
                TextButton(
                  onPressed: () => update(() => offlineNotice = null),
                  child: const Text('Schließen'),
                ),
            ],
          ),
        if (accountPending > 0) const LinearProgressIndicator(),
        if (accountError != null)
          MaterialBanner(
            content: Text(accountError!),
            actions: [
              TextButton(
                onPressed: () async {
                  await accountSaveTail;
                  if (!mounted) return;
                  update(() => accountError = null);
                  queueAccountSave(preferencesData());
                },
                child: const Text('Erneut speichern'),
              ),
              TextButton(
                onPressed: reloadAccountData,
                child: const Text('Cloudstand laden'),
              ),
            ],
          ),
        Expanded(
          child: AbsorbPointer(
            absorbing: accountError != null,
            child: miseScaffold(),
          ),
        ),
      ],
    );
  }

  List<Widget> sharedReadOnlyFlow() => [
    title(activeHousehold!.name),
    gap(12),
    surveyCard(
      'Nur ansehen',
      'Du kannst den gemeinsamen Plan, Einkauf und Vorrat lesen. Zum Bearbeiten ist die Rolle Mitglied oder Verwaltung nötig.',
    ),
    gap(16),
    if (tab == 1) ...[
      weekPicker(),
      gap(16),
      for (final entry in plan.entries)
        surveyCard(
          _PlanningPageState.days[entry.key],
          '${entry.value.recipe.name} · ${entry.value.servings} Portionen',
        ),
      if (plan.isEmpty) const Text('Diese Woche ist noch frei.'),
    ],
    if (tab == 2) ...[
      for (final item in pantry)
        ListTile(
          title: Text(item['name'] as String? ?? 'Vorrat'),
          subtitle: Text('${item['amount'] ?? ''} ${item['unit'] ?? ''}'),
        ),
      for (final item in preparedMeals)
        ListTile(
          title: Text(item['name'] as String? ?? 'Vorbereitete Mahlzeit'),
        ),
      if (pantry.isEmpty && preparedMeals.isEmpty)
        const Text('Noch kein Vorrat erfasst.'),
    ],
    if (tab == 3) ...[
      for (final item in buildShoppingList(plan.values))
        ListTile(
          leading: Icon(
            checked.contains((item.ingredientId, item.unit))
                ? Icons.check_circle_outline
                : Icons.circle_outlined,
          ),
          title: Text('${amountLabel(item.quantity, item.unit)} ${item.name}'),
        ),
    ],
  ];
}
