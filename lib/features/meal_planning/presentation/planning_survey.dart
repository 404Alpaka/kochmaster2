part of 'planning_page.dart';

extension _PlanningSurvey on _PlanningPageState {
  Widget surveyCard(String heading, String body, {Color? color}) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        gap(7),
        Text(
          body,
          style: muted.copyWith(
            color: color != null && color.computeLuminance() > .5
                ? AppTheme.light.colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
    color: color,
  );

  Widget surveyChoice(
    String label,
    bool selected,
    VoidCallback onTap, {
    String? subtitle,
  }) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.sage : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${selected ? '✓' : '○'}  $label',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.lightText,
              ),
            ),
            if (subtitle != null) ...[
              gap(5),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  List<Widget> planningFlow() {
    if (surveyStep == 6) return budgetConflictView();
    if (surveyStep == 7) return budgetAlternativesView();
    if (surveyStep == 5) return planBudgetView();
    if (surveyStep > 0) return surveyView();
    if (draft != null && swappingDay != null) return replacementView();
    if (draft != null) return proposalView();
    if (proposalConfirmed) return planView();
    if (plan.isNotEmpty) return planView();
    return [
      title('Deine Woche'),
      gap(5),
      Text('Ein guter Plan beginnt mit deinem Geschmack.', style: muted),
      gap(12),
      weekActionCard(),
      TextButton.icon(
        onPressed: loading || saving || readOnlyShared
            ? null
            : reusePreviousWeek,
        icon: const Icon(Icons.history),
        label: const Text('Vorwoche als Entwurf verwenden'),
      ),
      gap(18),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            section('Von der Idee auf deinen Teller'),
            for (final text in [
              '1   Rezepte kennenlernen',
              '2   Vorlieben merken',
              '3   Wochenplan vorschlagen lassen',
              '4   Einzelne Gerichte austauschen',
            ]) ...[Text(text, style: const TextStyle(fontSize: 14)), gap(12)],
          ],
        ),
      ),
      gap(18),
      section('Diese könnten dir schmecken'),
      if (dinnerRecipes.isNotEmpty)
        panel(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                child: recipePhoto(dinnerRecipes.first, height: 70),
              ),
            ),
            title: Text(dinnerRecipes.first.name),
            subtitle: Text(
              '${dinnerRecipes.first.minutes} Min. · Rezept kennenlernen →',
            ),
            onTap: () {
              selectTab(0);
              details(dinnerRecipes.first);
            },
          ),
        ),
      gap(18),
      surveyCard(
        'Deine Wünsche einmal festlegen',
        'Ernährung, Ausschlüsse, Personen, Tage, Kochzeit und Budget – alles auf einer Seite.',
        color: AppColors.softGreen,
      ),
    ];
  }

  List<Widget> surveyView() => [
    Row(
      children: [
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(alignment: Alignment.centerLeft),
            onPressed: () => update(() => surveyStep--),
            child: Text(surveyStep == 1 ? '←  Wochenplan' : '←  Zurück'),
          ),
        ),
        Text('$surveyStep von 4', style: muted),
      ],
    ),
    Row(
      children: [
        for (var i = 1; i <= 4; i++)
          Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
              decoration: BoxDecoration(
                color: i <= surveyStep ? AppColors.sage : AppColors.softGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    ),
    gap(22),
    ...switch (surveyStep) {
      1 => allergyQuestion(),
      2 => dietQuestion(),
      3 => scopeQuestion(),
      _ => timeQuestion(),
    },
  ];

  bool get showPlanningAction => tab == 1 && surveyStep > 0;

  Future<void> startPlanning() async {
    if (saving || loading) return;
    if (!surveyCompleted) {
      final accepted = await editFoodPreferences();
      if (!accepted || !mounted) return;
    }
    if (saving || loading) return;
    deferredRecipes.clear();
    createProposal();
  }

  Widget planningActionBar() {
    final label = switch (surveyStep) {
      1 => 'Weiter: Ernährungsweise',
      2 => 'Weiter: Personen & Tage',
      3 => 'Weiter: Kochzeit',
      4 => 'Weiter: Planbudget',
      5 =>
        planBudget != null && planBudget! < 62.40
            ? 'Budgetkonflikt ansehen · Demo'
            : 'Wochenvorschlag erstellen',
      6 => 'Günstigere Alternativen prüfen',
      7 => 'Änderungen für ${euro(budgetDemoTotal)} übernehmen',
      _ => 'Wochenplan erstellen',
    };
    final hint = switch (surveyStep) {
      4 => 'Bestätige im nächsten Schritt dein Planbudget.',
      5 => 'Beispielkosten für die Demo · keine Live-Preise.',
      6 => 'Du entscheidest, welche Änderungen übernommen werden.',
      7 => 'Demo · Erst beim Bestätigen wird dein Wochenplan gespeichert.',
      0 => 'Den Vorschlag kannst du danach frei bearbeiten.',
      _ => 'Deine Antworten kannst du später ändern.',
    };
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
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                  onPressed:
                      saving ||
                          loading ||
                          (surveyStep == 7 && !canApplyBudgetDemo)
                      ? null
                      : () {
                          if (surveyStep == 0) {
                            startPlanning();
                            return;
                          }
                          if (surveyStep < 5) {
                            if (surveyStep == 4 && !planBudgetInitialized) {
                              planBudget = budget;
                              planBudgetInitialized = true;
                            }
                            update(() => surveyStep++);
                            return;
                          }
                          if (surveyStep == 5 &&
                              planBudget != null &&
                              planBudget! < 62.40) {
                            update(() {
                              budgetDemoSelections.addAll([0, 1, 2, 3]);
                              surveyStep = 6;
                            });
                            return;
                          }
                          if (surveyStep == 6) {
                            update(() => surveyStep = 7);
                            return;
                          }
                          if (surveyStep == 7) {
                            applyBudgetDemo();
                            return;
                          }
                          surveyCompleted = true;
                          savePreferences();
                          createProposal();
                        },
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(label, textAlign: TextAlign.center),
                ),
              ),
              gap(8),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: muted.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> planBudgetView() => [
    title('Essenspräferenzen'),
    gap(12),
    primary('Essenspräferenzen bearbeiten', () => editFoodPreferences()),
  ];

  List<Widget> allergyQuestion() => [
    title('Was müssen wir\nausschließen?'),
    gap(8),
    Text(
      'Damit wir wissen, welche Rezepte für dich nicht infrage kommen. Mehrfachauswahl möglich.',
      style: muted,
    ),
    gap(18),
    section('Allergien & feste Ausschlüsse'),
    for (final pair in [
      ['Milch', 'Eier'],
      ['Erdnüsse', 'Schalenfrüchte'],
      ['Gluten', 'Soja'],
    ]) ...[
      Row(
        children: [
          for (var i = 0; i < pair.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: surveyChoice(
                pair[i],
                exclusions.contains(pair[i]),
                () => update(() {
                  if (!exclusions.add(pair[i])) exclusions.remove(pair[i]);
                }),
              ),
            ),
          ],
        ],
      ),
      gap(10),
    ],
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            onPressed: addExclusion,
            child: const Text('Weitere feste Ausschlüsse hinzufügen  +'),
          ),
          for (final item in exclusions.where(
            (e) => ![
              'Milch',
              'Eier',
              'Erdnüsse',
              'Schalenfrüchte',
              'Gluten',
              'Soja',
            ].contains(e),
          ))
            InputChip(
              label: Text(item),
              onDeleted: () => update(() => exclusions.remove(item)),
            ),
          TextButton(
            onPressed: () => update(exclusions.clear),
            child: Text(
              '${exclusions.isEmpty ? '✓' : '○'}  Keine festen Ausschlüsse',
            ),
          ),
        ],
      ),
    ),
    gap(18),
    surveyCard(
      'Allergien sind keine Geschmackssache.',
      'Feste Ausschlüsse gelten immer. Bei Ausschlüssen werden nur Rezepte mit geprüften Zutaten- und Allergendaten vorgeschlagen.',
      color: const Color(0xFFF6E9CF),
    ),
    gap(12),
    Text(
      'Bitte prüfe zusätzlich die Produktkennzeichnung. Bloße Abneigungen kannst du später separat angeben.',
      style: muted,
    ),
  ];

  Future<void> addExclusion() async {
    var value = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fester Ausschluss'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Zutat oder Allergen'),
          onChanged: (text) => value = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, value.trim()),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      update(() => exclusions.add(result));
    }
  }

  List<Widget> dietQuestion() => [
    title('Wie möchtest\ndu essen?'),
    gap(8),
    Text(
      'Wähle, was zu deinem Alltag passt. Deine festen Ausschlüsse gelten immer zusätzlich.',
      style: muted,
    ),
    gap(18),
    for (final (label, subtitle) in [
      ('Ohne Einschränkung', 'Pflanzlich, Fisch und Fleisch'),
      ('Vegetarisch', 'Ohne Fleisch und Fisch'),
      ('Vegan', 'Rein pflanzlich, ohne tierische Zutaten'),
    ]) ...[
      surveyChoice(
        label,
        diet == label,
        () => update(() => diet = label),
        subtitle: subtitle,
      ),
      gap(12),
    ],
    surveyCard(
      '$diet für euren Wochenplan',
      'Wir berücksichtigen deine Auswahl und alle festen Ausschlüsse.',
      color: AppColors.softGreen,
    ),
    gap(18),
    Text(
      'Du möchtest nur bestimmte Zutaten nicht? Das kannst du später freiwillig ergänzen.',
      style: muted,
    ),
  ];

  List<Widget> scopeQuestion() => [
    title('Für wen und\nfür wie lange?'),
    gap(8),
    Text(
      'Wir passen die Zutatenmengen an. Du kannst später jeden Tag einzeln ändern oder freilassen.',
      style: muted,
    ),
    gap(18),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('Für wie viele Personen?'),
          Row(
            children: [
              IconButton(
                tooltip: 'Weniger Personen',
                onPressed: servings > 1 ? () => update(() => servings--) : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$servings ${servings == 1 ? 'Person' : 'Personen'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Mehr Personen',
                onPressed: servings < 20
                    ? () => update(() => servings++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    ),
    gap(18),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('Wie viele Tage möchtest du planen?'),
          Wrap(
            spacing: 8,
            children: [
              for (final count in ([
                ...{3, 5, 7, planningDays},
              ]..sort()))
                ChoiceChip(
                  label: Text('$count Tage'),
                  selected: planningDays == count,
                  onSelected: (_) => update(() {
                    planningDays = count;
                    if (startDay + count > 7) startDay = 7 - count;
                  }),
                ),
            ],
          ),
          gap(12),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: startDay,
            decoration: const InputDecoration(labelText: 'Starttag'),
            items: [
              for (var i = 0; i <= 7 - planningDays; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${_PlanningPageState.days[i]} · ${displayDate(week.add(Duration(days: i)))}',
                  ),
                ),
            ],
            onChanged: (value) => update(() => startDay = value!),
          ),
        ],
      ),
    ),
    gap(18),
    surveyCard(
      '$planningDays Abendessen für $servings Personen',
      '${displayDate(week.add(Duration(days: startDay)))} – ${displayDate(week.add(Duration(days: startDay + planningDays - 1)))}\nEin Gericht pro Tag. Freie Tage sind jederzeit möglich.',
      color: AppColors.softGreen,
    ),
    gap(18),
    Text(
      'Die Einkaufsliste berechnen wir erst aus dem Plan, den du am Ende bestätigst.',
      style: muted,
    ),
  ];

  List<Widget> timeQuestion() => [
    title('Wie viel Zeit\nhast du zum Kochen?'),
    gap(8),
    Text(
      'So lange darf ein Gericht normalerweise dauern – inklusive Vorbereiten und Garen.',
      style: muted,
    ),
    gap(18),
    for (final (minutes, label, subtitle) in [
      (15, 'Bis 15 Minuten', 'Schnell auf dem Tisch'),
      (30, 'Bis 30 Minuten', 'Entspannt im Alltag'),
      (45, 'Bis 45 Minuten', 'Etwas mehr Zeit zum Kochen'),
      (0, 'Ich bin flexibel', 'Auch längere Gerichte sind okay'),
    ]) ...[
      surveyChoice(
        label,
        maxMinutes == minutes,
        () => update(() => maxMinutes = minutes),
        subtitle: subtitle,
      ),
      gap(10),
    ],
    surveyCard(
      'Mehr Vorlieben? Nur, wenn du möchtest.',
      'Lieblingsküchen, ungeliebte Zutaten und Resteverwertung bleiben freiwillig. Dein Planbudget bestätigst du direkt vor dem Vorschlag.',
      color: AppColors.cream,
    ),
    gap(18),
    Text(
      'Dein Vorschlag berücksichtigt Favoriten, gemerkte Rezepte und neue Ideen – ohne doppelte Gerichte.',
      style: muted,
    ),
  ];

  bool recipeMatchesPlanning(Recipe recipe, {bool includePersonal = true}) {
    if (!isDinnerRecipe(recipe)) return false;
    final activeExclusions = {
      ...exclusions,
      if (includePersonal) ...personalExclusions,
    };
    if (hiddenRecipes.contains(recipe.id) || recipeRatings[recipe.id] == 1) {
      return false;
    }
    if (maxMinutes > 0 && recipe.minutes > maxMinutes) return false;
    if (recipe.ingredients.isEmpty) return false;
    return matchesVerifiedRestrictions(recipe, diet, activeExclusions) &&
        planningDiners
            .where((d) => d.participates)
            .every((d) => d.allows(recipe));
  }

  List<Recipe> get eligibleRecipes =>
      recipes.where((r) => recipeMatchesPlanning(r)).toList();

  Map<String, String> get planningIngredientOptions => {
    for (final r in recipes)
      for (final i in r.ingredients) i.ingredientId: i.name,
  };

  PlanningResources get planningResources {
    final stock = <PlanningStock>[];
    if (usePlanningStock) {
      final options = planningIngredientOptions;
      for (final item in pantry) {
        final amount = pantryAmount(item);
        if (amount == null) continue;
        var id = item['ingredientId'] as String?;
        if (id == null) {
          final matches = options.entries
              .where(
                (i) =>
                    i.value.trim().toLowerCase() ==
                    (item['name'] as String? ?? '').trim().toLowerCase(),
              )
              .toList();
          if (matches.length == 1) id = matches.single.key;
        }
        if (id == null) continue;
        final rawExpiry = item['expires'] as String?;
        final expires = rawExpiry == null ? null : DateTime.tryParse(rawExpiry);
        if (rawExpiry != null && expires == null) continue;
        stock.add(
          PlanningStock(
            ingredientId: id,
            quantity: amount.$1,
            unit: amount.$2,
            expires: expires,
          ),
        );
      }
    }
    return PlanningResources(
      stock: stock,
      costPerServing: recipeCostEstimates,
      budget: planBudget,
      costClass: budgetCostClass,
    );
  }

  PlannerProfile get plannerProfile => PlannerProfile(
    resources: planningResources,
    diners: planningDiners,
    diet: diet,
    exclusions: {...exclusions, ...personalExclusions},
    hidden: {...hiddenRecipes, ...deferredRecipes},
    ratings: recipeRatings,
    favorites: favoriteRecipes,
    effortPenalties: {
      for (final e in effortFeedback.entries)
        e.key: (e.value * 12.0).clamp(0, 60),
    },
    cooked: {for (final h in cookingHistory) h['recipeId'] as String},
    tasteAdjustments: {
      for (final r in recipes)
        r.id:
            -dislikeScore(r) * 12.0 -
            ((dislikeFeedback[r.id] ?? 0) * 10).clamp(0, 40) +
            (selfChosenRecipes.contains(r.id)
                ? ((recipeRatings[r.id] ?? 0) >= 4 ? 4 : 2)
                : 0) +
            const WeeklyPlanner().learnedTaste(
              r,
              recipes,
              PlannerProfile(
                ratings: {
                  ...recipeRatings,
                  for (final e in dislikeFeedback.entries)
                    if (!recipeRatings.containsKey(e.key)) e.key: 2,
                },
              ),
            ),
    },
  );

  List<PlanningOccurrence> get plannerHistory {
    final result = <PlanningOccurrence>[];
    for (final key in cookedEntries) {
      if (key.length > 11 && key[10] == ':') {
        final date = DateTime.tryParse(key.substring(0, 10));
        if (date != null) {
          result.add(PlanningOccurrence(key.substring(11), date));
        }
      }
    }
    for (final h in cookingHistory) {
      final date = DateTime.tryParse(h['date'] as String? ?? '');
      if (date != null) {
        result.add(PlanningOccurrence(h['recipeId'] as String, date));
      }
    }
    for (final entry in {
      ...localWeekCache,
      dateKey(week): WeeklyPlan(meals: plan),
    }.entries) {
      final monday = DateTime.parse(entry.key);
      final statuses = weeklyReviews[entry.key]?['statuses'] as Map? ?? {};
      for (final meal in entry.value.meals.entries) {
        if (meal.value.preparedMealId != null) continue;
        result.add(
          PlanningOccurrence(
            meal.value.recipe.id,
            monday.add(Duration(days: meal.key)),
            skipped: statuses['${meal.key}'] == 'notCooked',
          ),
        );
      }
    }
    return result;
  }

  Future<void> refreshPlanningHousehold() async {
    final scope = activeHouseholdId;
    if (scope == null || householdRepository == null) return;
    final seed = plannerSeed;
    final deferred = {...deferredRecipes};
    final households = await householdRepository!.list();
    if (!mounted || activeHouseholdId != scope) {
      throw StateError('Planungsbereich geändert');
    }
    connectedHouseholds = households;
    if (activeHousehold == null || activeHousehold!.members.isEmpty) {
      throw StateError('Mitgliederliste nicht verfügbar');
    }
    final state = await householdRepository!.loadState(scope);
    if (!mounted || activeHouseholdId != scope) {
      throw StateError('Planungsbereich geändert');
    }
    sharedRevision = state.revision;
    lastSharedData = {...sharedAccountData(defaultAccountData), ...state.data};
    applyPreferences({...personalCloudData, ...lastSharedData});
    plannerSeed = seed;
    deferredRecipes
      ..clear()
      ..addAll(deferred);
  }

  Future<void> createProposal({bool allowRepeats = false}) async {
    if (saving || loading || loadError != null) return;
    final targetScope = activeHouseholdId;
    final targetWeek = dateKey(week);
    final targetRepository = weekRepository;
    if (accountConnected && !await flushAccountData()) return;
    if (!mounted ||
        activeHouseholdId != targetScope ||
        dateKey(week) != targetWeek) {
      return;
    }
    // Load both sides of the target period; an unseen future booking also blocks.
    if (targetRepository != null) {
      update(() => loading = true);
      try {
        await refreshPlanningHousehold();
        final weeks = await Future.wait([
          for (var offset = -5; offset <= 5; offset++)
            if (offset != 0)
              () async {
                final target = week.add(Duration(days: offset * 7));
                return MapEntry(
                  dateKey(target),
                  await targetRepository.load(target, recipes),
                );
              }(),
        ]);
        if (!mounted ||
            activeHouseholdId != targetScope ||
            dateKey(week) != targetWeek) {
          return;
        }
        localWeekCache.addEntries(weeks);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Der Planungsverlauf konnte nicht vollständig geladen werden. Bitte erneut versuchen.',
              ),
            ),
          );
        }
        return;
      } finally {
        if (mounted) update(() => loading = false);
      }
    }
    if (!mounted) return;
    final result = const WeeklyPlanner().generate(
      catalog: recipes,
      days: {
        for (var day = startDay; day < startDay + planningDays; day++)
          day: PlannerDay(
            week.add(Duration(days: day)),
            servings: acceptedDays.contains(day)
                ? (draft?[day]?.servings ?? servings)
                : servings,
            maxMinutes:
                dayTimeLimits[dateKey(week.add(Duration(days: day)))] ??
                maxMinutes,
          ),
      },
      profile: plannerProfile,
      history: plannerHistory,
      seed: plannerSeed,
      fixed: {
        for (final day in acceptedDays)
          if (draft?[day] != null &&
              day >= startDay &&
              day < startDay + planningDays)
            day: draft![day]!.recipe,
      },
      allowRepeats: allowRepeats,
    );
    update(() {
      allowPlanRepeats = allowRepeats;
      plannerResult = result;
      surveyStep = 0;
      editingPlan = false;
      acceptedDays.removeWhere((day) => !result.recipes.containsKey(day));
      changedProposalDays.clear();
      swappingDay = null;
      selectedReplacement = null;
      proposalConfirmed = false;
      draft = {
        for (final e in result.recipes.entries)
          e.key: PlannedMeal(
            e.value,
            acceptedDays.contains(e.key)
                ? (draft?[e.key]?.servings ?? servings)
                : servings,
          ),
      };
    });
    savePreferences();
  }

  void editExistingPlan() {
    if (saving || loading || loadError != null) return;
    update(() {
      surveyStep = 0;
      editingPlan = true;
      allowPlanRepeats = false;
      deferredRecipes.clear();
      plannerResult = null;
      changedProposalDays.clear();
      swappingDay = null;
      selectedReplacement = null;
      draft = Map<int, PlannedMeal>.from(plan);
      acceptedDays
        ..clear()
        ..addAll(plan.keys);
    });
  }
}
