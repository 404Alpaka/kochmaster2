part of 'planning_page.dart';

extension _PreparedMealViews on _PlanningPageState {
  Map<String, dynamic>? findPreparedMeal(String id) {
    for (final meal in preparedMeals) {
      if (meal['id'] == id) return meal;
    }
    return null;
  }

  Map<String, dynamic> reservationsFor(Map<String, dynamic> meal) =>
      Map<String, dynamic>.from(meal['reservations'] as Map? ?? {});
  int preparedReserved(Map<String, dynamic> meal, {String? exceptDate}) =>
      reservationsFor(meal).entries
          .where((e) => e.key != exceptDate)
          .fold<int>(0, (n, e) => n + (e.value as num).toInt());
  int preparedAvailable(Map<String, dynamic> meal, {String? exceptDate}) =>
      ((meal['portions'] as num).toInt() -
              preparedReserved(meal, exceptDate: exceptDate))
          .clamp(0, 9999)
          .toInt();
  Map<String, dynamic>? get selectedPreparedMeal =>
      selectedPreparedId == null ? null : findPreparedMeal(selectedPreparedId!);
  String preparedDateLabel(dynamic value) {
    final date = DateTime.tryParse(value as String? ?? '');
    return date == null ? 'Nicht angegeben' : displayDate(date);
  }

  void syncPreparedReservations(
    DateTime targetWeek,
    Map<int, PlannedMeal> meals,
  ) {
    for (final stored in preparedMeals) {
      final reservations = reservationsFor(stored);
      for (var day = 0; day < 7; day++) {
        reservations.remove(dateKey(targetWeek.add(Duration(days: day))));
      }
      for (final entry in meals.entries) {
        if (entry.value.preparedMealId == stored['id'] &&
            !entry.value.preparedConsumed)
          reservations[dateKey(targetWeek.add(Duration(days: entry.key)))] =
              entry.value.servings;
      }
      stored['reservations'] = reservations;
    }
    localWeekCache[dateKey(targetWeek)] = WeeklyPlan(
      meals: Map<int, PlannedMeal>.from(meals),
      checked: dateKey(targetWeek) == dateKey(week)
          ? Set<(String, String)>.from(checked)
          : localWeekCache[dateKey(targetWeek)]?.checked,
    );
  }

  void openPreparedMeals() {
    syncPreparedReservations(week, plan);
    update(() {
      tab = 2;
      pantryPage = 3;
      preparedError = null;
    });
    savePreferences();
  }

  void editPreparedMeal([Map<String, dynamic>? meal]) => update(() {
    selectedPreparedId = meal?['id'] as String?;
    preparedEditor = meal == null
        ? {
            'id': 'prepared-${DateTime.now().microsecondsSinceEpoch}',
            'name': '',
            'portions': 1,
            'location': 'Kühlschrank',
            'cookedOn': dateKey(pantryToday),
            'storedOn': dateKey(pantryToday),
          }
        : Map<String, dynamic>.from(meal);
    preparedError = null;
    pantryPage = 4;
  });
  void replanPreparedMeal(Map<String, dynamic> meal) => update(() {
    selectedPreparedId = meal['id'] as String;
    preparedPlanDate = week.add(Duration(days: selectedDay));
    preparedPlanPortions = preparedAvailable(
      meal,
      exceptDate: dateKey(preparedPlanDate!),
    ).clamp(1, servings).toInt();
    preparedError = null;
    pantryPage = 5;
  });

  List<Widget> preparedMealsView() => [
    title('Gutes bleibt übrig.'),
    gap(12),
    Text('Fertige Mahlzeiten in deinem Vorrat.', style: muted),
    gap(18),
    Row(
      children: [
        Expanded(
          child: recipeAction(
            'Zutaten',
            false,
            () => update(() => pantryPage = 0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: recipeAction('Mahlzeiten', true, () {})),
      ],
    ),
    gap(18),
    if (preparedMeals.isEmpty) ...[
      surveyCard(
        'Noch keine Mahlzeiten aufbewahrt.',
        'Speichere übrige Portionen nach dem Kochen oder erfasse eine Mahlzeit selbst.',
        color: AppColors.softGreen,
      ),
      gap(18),
    ],
    for (final meal in preparedMeals) ...[
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${meal['portions']} ${(meal['portions'] as num) == 1 ? 'Portion' : 'Portionen'} übrig',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            gap(10),
            Text(
              meal['name'] as String,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            gap(10),
            Text(
              '${meal['location']}\nGekocht am ${preparedDateLabel(meal['cookedOn'])}\n${meal['location'] == 'Gefrierfach' ? 'Eingefroren' : 'Gekühlt'} seit ${preparedDateLabel(meal['storedOn'] ?? meal['cookedOn'])}',
              style: muted,
            ),
            if (preparedReserved(meal) > 0) ...[
              gap(8),
              Text(
                '${preparedReserved(meal)} reserviert · ${preparedAvailable(meal)} frei',
                style: const TextStyle(fontSize: 13, color: AppColors.sage),
              ),
            ],
            gap(14),
            recipeAction(
              'Erneut einplanen',
              true,
              () => replanPreparedMeal(meal),
            ),
            gap(10),
            recipeAction(
              'Einfrieren oder Aufbewahrung ändern',
              false,
              () => editPreparedMeal(meal),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
      ),
      gap(18),
    ],
    surveyCard(
      'Nicht nur rohe Zutaten zählen.',
      'Fertige Gerichte werden nach Portionen, Kochdatum und Lagerort erfasst. Geplante Portionen bleiben bis zum Verzehr im Vorrat.',
      color: AppColors.softGreen,
    ),
    gap(14),
    Text(
      accountConnected
          ? activeHouseholdId == null
                ? 'Mahlzeiten und Reservierungen werden in deinem persönlichen Konto gespeichert.'
                : 'Mahlzeiten und Reservierungen werden im aktiven Haushalt gespeichert.'
          : 'Mahlzeiten und Reservierungen gehören zu deinem lokalen Planungsbereich.',
      style: muted,
    ),
  ];

  Widget preparedDateButton(String key, String label) => TextButton.icon(
    icon: const Icon(Icons.event_outlined),
    label: Text('$label: ${preparedDateLabel(preparedEditor[key])}'),
    onPressed: () async {
      final initial =
          DateTime.tryParse(preparedEditor[key] as String? ?? '') ??
          pantryToday;
      final picked = await showDatePicker(
        context: context,
        initialDate: initial.isAfter(pantryToday) ? pantryToday : initial,
        firstDate: DateTime(2000),
        lastDate: pantryToday,
      );
      if (picked != null && mounted)
        update(() => preparedEditor[key] = dateKey(picked));
    },
  );
  List<Widget> preparedStorageView() => [
    proposalBack('Fertige Mahlzeiten', () => update(() => pantryPage = 3)),
    gap(14),
    title(
      selectedPreparedId == null
          ? 'Mahlzeit erfassen.'
          : 'Mahlzeit aufbewahren.',
    ),
    gap(12),
    Text('Portionen für später – mit Datum und Lagerort.', style: muted),
    gap(18),
    TextFormField(
      key: ValueKey('prepared-editor-${preparedEditor['id']}'),
      initialValue: preparedEditor['name'] as String? ?? '',
      decoration: const InputDecoration(labelText: 'Mahlzeit'),
      onChanged: (v) => preparedEditor['name'] = v,
    ),
    gap(18),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('Übrige Portionen'),
          Row(
            children: [
              IconButton(
                onPressed: (preparedEditor['portions'] as int) > 1
                    ? () => update(
                        () => preparedEditor['portions'] =
                            (preparedEditor['portions'] as int) - 1,
                      )
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  '${preparedEditor['portions']} Portionen',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: (preparedEditor['portions'] as int) < 99
                    ? () => update(
                        () => preparedEditor['portions'] =
                            (preparedEditor['portions'] as int) + 1,
                      )
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
    ),
    gap(18),
    section('Wo bewahrst du es auf?'),
    Row(
      children: [
        for (final location in ['Kühlschrank', 'Gefrierfach']) ...[
          if (location == 'Gefrierfach') const SizedBox(width: 8),
          Expanded(
            child: recipeAction(
              location,
              preparedEditor['location'] == location,
              () => update(() {
                if (preparedEditor['location'] != location)
                  preparedEditor['storedOn'] = dateKey(pantryToday);
                preparedEditor['location'] = location;
              }),
            ),
          ),
        ],
      ],
    ),
    gap(18),
    preparedDateButton('cookedOn', 'Gekocht am'),
    gap(12),
    preparedDateButton(
      'storedOn',
      preparedEditor['location'] == 'Gefrierfach'
          ? 'Eingefroren am'
          : 'Gekühlt seit',
    ),
    gap(18),
    surveyCard(
      'Portionsweise und gut verpackt.',
      'Notiere Datum und Lagerort. Die Angaben sind keine automatische Haltbarkeits- oder Verträglichkeitsprüfung.',
      color: AppColors.cream,
    ),
    if (selectedPreparedId != null) ...[
      gap(14),
      TextButton(
        onPressed: deletePreparedMeal,
        child: const Text('Mahlzeit entfernen'),
      ),
    ],
    if (preparedError != null) ...[
      gap(14),
      Text(
        preparedError!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ],
  ];

  void savePreparedStorage() {
    final name = (preparedEditor['name'] as String? ?? '').trim();
    final cooked = DateTime.tryParse(
      preparedEditor['cookedOn'] as String? ?? '',
    );
    final stored = DateTime.tryParse(
      preparedEditor['storedOn'] as String? ??
          preparedEditor['cookedOn'] as String? ??
          '',
    );
    final existing = selectedPreparedMeal;
    if (name.isEmpty ||
        cooked == null ||
        stored == null ||
        stored.isBefore(cooked) ||
        cooked.isAfter(pantryToday) ||
        stored.isAfter(pantryToday)) {
      update(
        () => preparedError = 'Bitte Name und gültige Daten eingeben. Das Lagerdatum darf nicht vor dem Kochdatum liegen.',
      );
      return;
    }
    if (existing != null &&
        (preparedEditor['portions'] as int) < preparedReserved(existing)) {
      update(
        () => preparedError =
            'Es sind ${preparedReserved(existing)} Portionen reserviert. Ändere zuerst die zugehörigen Planplätze.',
      );
      return;
    }
    update(() {
      preparedEditor['name'] = name;
      if (existing == null) {
        preparedMeals.add(Map<String, dynamic>.from(preparedEditor));
      } else {
        existing.addAll(preparedEditor);
      }
      pantryPage = 3;
    });
    savePreferences();
  }

  Future<void> deletePreparedMeal() async {
    final meal = selectedPreparedMeal;
    if (meal == null) return;
    if (preparedReserved(meal) > 0) {
      update(
        () => preparedError =
            'Entferne zuerst die Reservierungen aus deinem Wochenplan.',
      );
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mahlzeit entfernen?'),
        content: Text('${meal['name']} aus dem Vorrat entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      update(() {
        preparedMeals.remove(meal);
        pantryPage = 3;
      });
      savePreferences();
    }
  }

  List<Widget> preparedReplanView() {
    final meal = selectedPreparedMeal;
    if (meal == null)
      return [
        proposalBack('Fertige Mahlzeiten', openPreparedMeals),
        title('Mahlzeit nicht mehr vorhanden.'),
      ];
    final date = preparedPlanDate ?? pantryToday;
    return [
      proposalBack('Fertige Mahlzeiten', () => update(() => pantryPage = 3)),
      gap(14),
      title('Mahlzeit wieder einplanen.'),
      gap(18),
      surveyCard(
        '${meal['portions']} Portionen ${meal['name']}',
        '${meal['location']} · gekocht am ${preparedDateLabel(meal['cookedOn'])}\n${preparedAvailable(meal, exceptDate: dateKey(date))} Portionen für diesen Tag verfügbar',
      ),
      gap(18),
      section('Welcher Tag passt?'),
      for (var i = 0; i < 14; i++) ...[
        surveyChoice(
          '${_PlanningPageState.days[i % 7]}, ${displayDate(week.add(Duration(days: i)))}',
          dateKey(date) == dateKey(week.add(Duration(days: i))),
          () => update(() {
            preparedPlanDate = week.add(Duration(days: i));
            preparedError = null;
          }),
          subtitle: i < 7
              ? plan[i] == null
                    ? 'Bisher frei'
                    : 'Ersetzt: ${plan[i]!.recipe.name}'
              : 'Nächste Woche · vorhandenen Plan vor Übernahme prüfen',
        ),
        gap(10),
      ],
      Row(
        children: [
          IconButton(
            onPressed: preparedPlanPortions > 1
                ? () => update(() => preparedPlanPortions--)
                : null,
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Text(
              '$preparedPlanPortions Portionen',
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed:
                preparedPlanPortions <
                    preparedAvailable(meal, exceptDate: dateKey(date))
                ? () => update(() => preparedPlanPortions++)
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      gap(18),
      surveyCard(
        'Kein zusätzlicher Einkauf nötig.',
        'Die Mahlzeit ist bereits gekocht. Ihre Rezeptzutaten werden nicht erneut auf die Einkaufsliste gesetzt.',
        color: AppColors.softGreen,
      ),
      gap(18),
      surveyCard(
        'Reserviert, noch nicht gegessen.',
        'Erst mit „Als gegessen markieren“ im Wochenplan werden die Portionen vom Vorrat abgezogen. Prüfe vor dem Verzehr Aufbewahrung und Eignung selbst.',
        color: AppColors.cream,
      ),
      if (preparedError != null) ...[
        gap(14),
        Text(
          preparedError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ];
  }

  Recipe preparedRecipe(Map<String, dynamic> meal) {
    final snapshot = meal['recipe'];
    if (snapshot is Map)
      return recipeFromSnapshot(Map<String, dynamic>.from(snapshot));
    return Recipe(
      id: 'prepared-${meal['id']}',
      name: meal['name'] as String,
      minutes: 0,
      servings: 1,
      ingredients: const [],
      steps: const [],
    );
  }

  Future<void> savePreparedReservation() async {
    if (preparedBusy) return;
    update(() => preparedBusy = true);
    try {
      await performPreparedReservation();
    } finally {
      if (mounted) update(() => preparedBusy = false);
    }
  }

  Future<void> performPreparedReservation() async {
    final meal = selectedPreparedMeal;
    final date = preparedPlanDate;
    if (meal == null ||
        date == null ||
        saving ||
        loading ||
        readOnlyPlanning ||
        dataActionBusy ||
        accountLoading ||
        weekConflict ||
        loadError != null ||
        (accountConnected && (!accountReady || accountError != null))) {
      return;
    }
    if (widget.client != null && widget.user == null) {
      await account();
      return;
    }
    final portions = preparedPlanPortions;
    final sourceWeek = week;
    final household = activeHouseholdId;
    final repository = weekRepository;
    final targetWeek = mondayOf(date);
    final day = date.weekday - 1;
    final currentWeek = dateKey(targetWeek) == dateKey(sourceWeek);
    bool sameScope() =>
        mounted &&
        activeHouseholdId == household &&
        identical(weekRepository, repository) &&
        dateKey(week) == dateKey(sourceWeek);
    bool enoughPortions() =>
        portions > 0 &&
        identical(findPreparedMeal(meal['id'] as String), meal) &&
        portions <= preparedAvailable(meal, exceptDate: dateKey(date));
    if (!enoughPortions()) {
      update(
        () => preparedError = 'Nicht genug freie Portionen für diesen Tag.',
      );
      return;
    }
    update(() => preparedError = null);
    final WeeklyPlan target;
    try {
      final loaded = currentWeek
          ? WeeklyPlan(meals: plan, checked: checked)
          : repository != null
          ? await repository.load(targetWeek, recipes)
          : localWeekCache[dateKey(targetWeek)] ?? WeeklyPlan();
      // Work on a copy: cancelling or failing must not alter a cached week.
      target = WeeklyPlan(
        meals: Map<int, PlannedMeal>.from(loaded.meals),
        checked: Set<(String, String)>.from(loaded.checked),
      );
    } catch (_) {
      if (sameScope()) {
        update(
          () => preparedError =
              'Zielwoche konnte nicht geladen werden. Bitte erneut versuchen.',
        );
      }
      return;
    }
    if (!mounted || !sameScope()) return;
    if (target.meals[day] != null) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Geplantes Gericht ersetzen?'),
          content: Text(
            '${target.meals[day]!.recipe.name} wird durch ${meal['name']} ersetzt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ersetzen'),
            ),
          ],
        ),
      );
      if (yes != true || !sameScope()) return;
    }
    if (!enoughPortions()) {
      update(
        () => preparedError = 'Dein Mahlzeitenvorrat hat sich geändert. Bitte prüfe die verfügbaren Portionen erneut.',
      );
      return;
    }
    final original = target.meals.values.toList();
    target.meals[day] = PlannedMeal(
      preparedRecipe(meal),
      portions,
      preparedMealId: meal['id'] as String,
    );
    final kept = retainCheckedItems(
      original,
      target.meals.values,
      target.checked,
      additionalItems: pantryShoppingItems,
    );
    if (currentWeek) {
      if (!await persist(target.meals, kept) || !mounted) return;
    } else {
      update(() => saving = true);
      try {
        await repository?.save(
          targetWeek,
          WeeklyPlan(meals: target.meals, checked: kept),
        );
        if (repository == null) {
          await offlineCache.saveWeek(
            targetWeek,
            offlineScope,
            WeeklyPlan(meals: target.meals, checked: kept),
            extras: pantryShoppingItems,
          );
        }
        if (!sameScope()) return;
        localWeekCache[dateKey(sourceWeek)] = WeeklyPlan(
          meals: Map<int, PlannedMeal>.from(plan),
          checked: Set<(String, String)>.from(checked),
        );
        update(() {
          week = targetWeek;
          plan
            ..clear()
            ..addAll(target.meals);
          checked
            ..clear()
            ..addAll(kept);
          saved = true;
          saveError = null;
          weekConflict = false;
          weekSaveUncertain = false;
        });
        // Sync after switching weeks so the target cache keeps its own checks.
        syncPreparedReservations(targetWeek, target.meals);
        savePreferences();
      } catch (error) {
        if (sameScope()) {
          update(
            () => preparedError = error is TimeoutException
                ? 'Ob die Reservierung gespeichert wurde, ist noch unklar. Bei einem erneuten Versuch wird die Zielwoche zuerst neu geladen.'
                : error is PostgrestException && error.code == '40001'
                ? 'Die Zielwoche wurde auf einem anderen Gerät geändert. Bitte versuche es erneut; der aktuelle Plan wird vorher neu geladen.'
                : 'Reservierung konnte nicht gespeichert werden. Bitte erneut versuchen.',
          );
        }
        return;
      } finally {
        if (mounted) update(() => saving = false);
      }
    }
    update(() {
      tab = 1;
      pantryPage = 3;
      selectedDay = day;
      draft = null;
      surveyStep = 0;
      proposalConfirmed = false;
    });
  }

  Future<void> consumePreparedMeal(int day) async {
    final planned = plan[day];
    if (planned == null ||
        planned.preparedConsumed ||
        planned.preparedMealId == null ||
        saving ||
        loading)
      return;
    final meal = findPreparedMeal(planned.preparedMealId!);
    if (meal == null || (meal['portions'] as num) < planned.servings) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Diese Portionen sind im lokalen Vorrat nicht verfügbar.',
          ),
        ),
      );
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Als gegessen markieren?'),
        content: Text(
          '${planned.servings} Portionen ${planned.recipe.name} werden vom Mahlzeitenvorrat abgezogen. Zutaten werden nicht verändert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gegessen'),
          ),
        ],
      ),
    );
    if (yes != true ||
        !mounted ||
        plan[day]?.preparedConsumed == true ||
        plan[day]?.preparedMealId != planned.preparedMealId)
      return;
    if (!await saveMeals({
          ...plan,
          day: PlannedMeal(
            planned.recipe,
            planned.servings,
            preparedMealId: planned.preparedMealId,
            preparedConsumed: true,
          ),
        }) ||
        !mounted)
      return;
    update(() {
      meal['portions'] = (meal['portions'] as num).toInt() - planned.servings;
      if ((meal['portions'] as int) == 0) preparedMeals.remove(meal);
    });
    savePreferences();
  }

  Widget preparedActionBar() {
    final label = pantryPage == 3
        ? 'Mahlzeit erfassen +'
        : pantryPage == 4
        ? 'Im ${preparedEditor['location']} speichern'
        : 'Für ${_PlanningPageState.days[(preparedPlanDate ?? pantryToday).weekday - 1]} einplanen';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                  onPressed: saving || loading || preparedBusy
                      ? null
                      : () {
                          if (pantryPage == 3) {
                            editPreparedMeal();
                          } else if (pantryPage == 4) {
                            savePreparedStorage();
                          } else {
                            savePreparedReservation();
                          }
                        },
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
              gap(8),
              Text(
                pantryPage == 5
                    ? '$preparedPlanPortions Portionen · erst reservieren, beim Verzehr abziehen.'
                    : 'Kochdatum und Lagerort bleiben nachvollziehbar.',
                textAlign: TextAlign.center,
                style: muted.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
