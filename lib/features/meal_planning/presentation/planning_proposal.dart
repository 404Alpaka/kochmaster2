part of 'planning_page.dart';

extension _PlanningProposal on _PlanningPageState {
  Future<bool> editPlannerResources() async {
    var useStock = usePlanningStock;
    String? costClass =
        const {'low', 'medium', 'high'}.contains(budgetCostClass)
        ? budgetCostClass
        : null;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Vorräte & Budgetpassung'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vorhandene Vorräte bevorzugen'),
                  subtitle: const Text(
                    'Nur zugeordnete Zutaten mit vergleichbaren Mengen. Bestände werden beim Vorschlag nicht verändert.',
                  ),
                  value: useStock,
                  onChanged: (v) => setDialog(() => useStock = v),
                ),
                gap(12),
                DropdownButtonFormField<String>(
                  initialValue: costClass,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Gewünschte Kostenklasse',
                  ),
                  items: const [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('Keine Vorgabe'),
                    ),
                    DropdownMenuItem(value: 'low', child: Text('Günstig')),
                    DropdownMenuItem(value: 'medium', child: Text('Mittel')),
                    DropdownMenuItem(value: 'high', child: Text('Flexibel')),
                  ],
                  onChanged: (v) => setDialog(() => costClass = v),
                ),
                gap(12),
                const Text(
                  'Das Planbudget wird anhand deiner Kostenschätzungen pro Portion bewertet. Du kannst diese bei den Rezeptdetails eintragen. Fehlende Angaben bleiben neutral; Kostenklassen sind keine Preiszusagen.',
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
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted || readOnlyShared) return false;
    update(() {
      usePlanningStock = useStock;
      budgetCostClass = costClass;
    });
    savePreferences();
    return true;
  }

  Future<void> editRecipeCost(Recipe recipe) async {
    if (readOnlyShared) return;
    var value =
        recipeCostEstimates[recipe.id]
            ?.toStringAsFixed(2)
            .replaceAll('.', ',') ??
        '';
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eigene Kostenschätzung'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Geschätzte Rezeptkosten pro Portion in Euro. Keine Live-Preise; Packungsgrößen und vorhandene Vorräte werden nicht vom Betrag abgezogen. Im gemeinsamen Haushalt wird die Schätzung geteilt.',
              ),
              gap(12),
              TextFormField(
                initialValue: value,
                decoration: const InputDecoration(
                  labelText: 'Euro pro Portion · leer = unbekannt',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) => value = v,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = double.tryParse(v.trim().replaceAll(',', '.'));
                  return n != null && n.isFinite && n >= 0
                      ? null
                      : 'Bitte einen gültigen Betrag eingeben.';
                },
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
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted || readOnlyShared) return;
    update(() {
      if (value.trim().isEmpty) {
        recipeCostEstimates.remove(recipe.id);
      } else {
        recipeCostEstimates[recipe.id] = double.parse(
          value.trim().replaceAll(',', '.'),
        );
      }
    });
    savePreferences();
  }

  bool get showProposalAction => tab == 1 && surveyStep == 0 && draft != null;
  String recipeOrigin(Recipe recipe) => favoriteRecipes.contains(recipe.id)
      ? 'Favorit · magst du besonders'
      : rememberedRecipes.contains(recipe.id)
      ? 'Gemerkt · wolltest du mal kochen'
      : recipeWasCooked(recipe.id) ||
            cookingHistory.any((h) => h['recipeId'] == recipe.id)
      ? 'Schon als gekocht erfasst'
      : 'Neu für dich · bringt Abwechslung';

  String mealDescription(Recipe recipe, int portions) {
    final dietLabel = recipe.verifiedDiets?.contains('Vegan') == true
        ? 'vegan'
        : recipe.verifiedDiets?.contains('Vegetarisch') == true
        ? 'vegetarisch'
        : null;
    return '${recipe.minutes} Min. · $portions ${portions == 1 ? 'Person' : 'Personen'}${dietLabel == null ? '' : ' · $dietLabel'}';
  }

  Widget proposalBack(String label, VoidCallback action) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: saving ? null : action,
      icon: const Icon(Icons.arrow_back, size: 18),
      label: Text(label),
    ),
  );

  Widget proposalActionBar() {
    final replacing = swappingDay != null && draft != null;
    final confirmed = draft == null && proposalConfirmed;
    final label = replacing
        ? 'Dieses Gericht übernehmen'
        : confirmed
        ? 'Einkaufsliste öffnen'
        : 'Wochenplan bestätigen';
    final hint = replacing
        ? 'Heute keine Lust ≠ grundsätzlich nicht mögen.'
        : confirmed
        ? 'Nur aus deinem bestätigten Plan.'
        : 'Alle angezeigten Gerichte werden übernommen. Freie Tage bleiben frei.';
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
                          loadError != null ||
                          (replacing && selectedReplacement == null)
                      ? null
                      : () {
                          if (replacing) {
                            applyReplacement();
                          } else if (confirmed) {
                            selectTab(3);
                          } else {
                            confirmProposal();
                          }
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

  List<Widget> proposalView() => [
    Row(
      children: [
        Expanded(
          child: proposalBack('Präferenzen ändern', () async {
            if (await editFoodPreferences() && mounted && !editingPlan) {
              createProposal();
            }
          }),
        ),
        Text('Vorschlag', style: muted),
      ],
    ),
    if (editingPlan)
      proposalBack(
        'Bearbeiten abbrechen',
        () => update(() {
          draft = null;
          swappingDay = null;
        }),
      ),
    gap(14),
    title('Deine Woche. Dein Mix.'),
    gap(5),
    Text(
      '${displayDate(week)} – ${displayDate(week.add(const Duration(days: 6)))} · ${draft!.length} Abendessen',
      style: muted,
    ),
    gap(14),
    surveyCard(
      '$diet · $servings Personen · ${maxMinutes == 0 ? 'flexible Kochzeit' : 'bis $maxMinutes Min.'}',
      exclusions.isEmpty
          ? 'Keine festen Ausschlüsse angegeben.'
          : '${exclusions.join(', ')} ausgeschlossen.\nNur Rezepte mit geprüften Zutaten- und Allergendaten.',
      color: AppColors.softGreen,
    ),
    gap(14),
    if (activeHousehold != null)
      TextButton(
        onPressed: () async {
          await editPlanningDiners();
          if (mounted && !readOnlyShared) {
            createProposal(allowRepeats: allowPlanRepeats);
          }
        },
        child: const Text('Mitessende & feste Regeln'),
      ),
    TextButton(
      onPressed: readOnlyShared
          ? null
          : () async {
              if (await editPlannerResources() && mounted) {
                createProposal(allowRepeats: allowPlanRepeats);
              }
            },
      child: const Text('Vorräte & Budgetpassung'),
    ),
    TextButton(
      onPressed: () {
        plannerSeed++;
        createProposal(allowRepeats: allowPlanRepeats);
      },
      child: const Text('Neue Kombination · passende Tage behalten'),
    ),
    Text(
      'Schon passend? Mit „Passt“ bleibt der Tag bei einer neuen Kombination fixiert. Ansonsten tausche das Gericht oder lass den Tag frei.',
      style: muted,
    ),
    gap(14),
    for (final warning in plannerResult?.warnings ?? <String>[]) ...[
      surveyCard('Hinweis zur Auswahl', warning, color: AppColors.cream),
      gap(10),
    ],
    if (!editingPlan && draft!.length < planningDays) ...[
      TextButton(
        onPressed: () => createProposal(allowRepeats: true),
        child: const Text('30-Tage-Pause nur für diesen Plan aufheben'),
      ),
      TextButton(
        onPressed: () => editFoodPreferences(),
        child: const Text('Kochzeit und Vorgaben ändern'),
      ),
      surveyCard(
        'Freie Tage bleiben flexibel.',
        'Nicht jeder Tag hat einen Vorschlag. Du kannst ein Gericht auswählen oder den Tag frei lassen. Deine festen Ausschlüsse bleiben bestehen.',
        color: AppColors.cream,
      ),
      gap(14),
    ],
    for (
      var day = editingPlan ? 0 : startDay;
      day < (editingPlan ? 7 : startDay + planningDays);
      day++
    ) ...[proposalDay(day), gap(14)],
    surveyCard(
      'Warum gerade diese Gerichte?',
      'Feste Ausschlüsse, Bewertungen, Kochzeit und 30-Tage-Pause zuerst. Anschließend vergleichen wir mehrere Wochenkombinationen nach persönlicher Passung und Abwechslung. Preis- und Vorratsdaten werden nur bei verlässlichen Angaben berücksichtigt.',
      color: AppColors.cream,
    ),
  ];

  Widget proposalDay(int day) {
    final meal = draft![day];
    final accepted = acceptedDays.contains(day);
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${_PlanningPageState.days[day]} · ${displayDate(week.add(Duration(days: day)))}',
                  style: muted.copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                meal == null
                    ? 'Frei'
                    : accepted
                    ? '✓ Passt'
                    : 'Offen',
                style: TextStyle(
                  fontSize: 13,
                  color: accepted ? AppColors.sage : AppColors.muted,
                ),
              ),
            ],
          ),
          gap(8),
          Text(
            meal?.recipe.name ?? 'Tag bleibt frei',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (meal != null) ...[
            gap(8),
            Text(mealDescription(meal.recipe, meal.servings), style: muted),
            if (plannerResult?.recipes[day]?.id == meal.recipe.id) ...[
              gap(6),
              Text(
                plannerResult!.reasons[day]!.join(' · '),
                style: muted.copyWith(fontSize: 12),
              ),
            ],
            gap(6),
            Text(
              recipeOrigin(meal.recipe),
              style: const TextStyle(fontSize: 13, color: AppColors.sage),
            ),
          ],
          gap(10),
          DropdownButtonFormField<int>(
            initialValue:
                dayTimeLimits[dateKey(week.add(Duration(days: day)))] ??
                maxMinutes,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kochzeit für diesen Tag',
            ),
            items: [
              for (final limit in <int>{
                maxMinutes,
                0,
                15,
                30,
                45,
                60,
              }.toList()..sort())
                DropdownMenuItem(
                  value: limit,
                  child: Text(limit == 0 ? 'Flexibel' : 'Bis $limit Min.'),
                ),
            ],
            onChanged: (v) {
              update(
                () =>
                    dayTimeLimits[dateKey(week.add(Duration(days: day)))] = v!,
              );
              savePreferences();
            },
          ),
          gap(10),
          Row(
            children: [
              if (meal != null) ...[
                Expanded(
                  child: dayAction(
                    'Passt',
                    accepted,
                    () => update(() {
                      if (!acceptedDays.add(day)) acceptedDays.remove(day);
                    }),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: dayAction(
                  meal == null ? 'Gericht wählen' : 'Anderes Gericht',
                  false,
                  () => swapProposal(day),
                ),
              ),
              if (meal != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey('proposal-free-$day'),
                    child: dayAction(
                      'Tag freilassen',
                      false,
                      () => update(() {
                        draft!.remove(day);
                        acceptedDays.remove(day);
                        changedProposalDays.add(day);
                      }),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
    );
  }

  Widget dayAction(String label, bool selected, VoidCallback action) =>
      TextButton(
        onPressed: saving ? null : action,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 64),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          backgroundColor: selected ? AppColors.sage : AppColors.softGreen,
          foregroundColor: selected ? Colors.white : AppColors.lightText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13),
        ),
      );

  List<Recipe> get replacementRecipes {
    if (draft == null) return [];
    final used = draft!.values.map((m) => m.recipe.id).toSet();
    final pool = <String, Recipe>{
      for (final r in recipes) r.id: r,
      // Keep demo recipes available for the demo flow without adding them to the live catalogue.
      if (draft!.values.any((m) => m.recipe.id.startsWith('budget-demo-')))
        for (final r in budgetDemoRecipes) r.id: r,
    };
    final profile = plannerProfile;
    final history = plannerHistory;
    final target = swappingDay ?? startDay;
    final day = PlannerDay(
      week.add(Duration(days: target)),
      servings: draft?[target]?.servings ?? servings,
      maxMinutes:
          dayTimeLimits[dateKey(week.add(Duration(days: target)))] ??
          maxMinutes,
    );
    final alternatives = pool.values
        .where(
          (r) =>
              !used.contains(r.id) &&
              const WeeklyPlanner().eligible(
                r,
                day,
                profile,
                history,
                allowRepeats: allowPlanRepeats,
              ),
        )
        .toList();
    final scores = <String, double>{};
    for (final r in alternatives) {
      final meals = {
        for (final e in draft!.entries)
          if (e.key != target) e.key: e.value.recipe,
        target: r,
      };
      final schedule = {
        for (final e in draft!.entries)
          e.key: (week.add(Duration(days: e.key)), e.value.servings),
        target: (day.date, day.servings),
      };
      final pantryFit = profile.resources.pantryScores(meals, schedule)[target];
      scores[r.id] = const WeeklyPlanner().score(
        r,
        day,
        profile,
        pantryScore: pantryFit,
        plannedServings: planningDays * servings,
      );
    }
    alternatives.sort((a, b) {
      final score = scores[b.id]!.compareTo(scores[a.id]!);
      return score == 0 ? a.id.compareTo(b.id) : score;
    });
    return alternatives;
  }

  void swapProposal(int day) {
    if (saving || draft == null) return;
    update(() {
      swappingDay = day;
      selectedReplacement = null;
      replacementReason = 'Diese Woche nicht';
    });
    final alternatives = replacementRecipes;
    if (alternatives.isNotEmpty) {
      update(() => selectedReplacement = alternatives.first);
    }
  }

  List<Widget> replacementView() {
    final day = swappingDay!;
    final current = draft![day];
    final alternatives = replacementRecipes;
    return [
      proposalBack(
        'Zurück zum Wochenvorschlag',
        () => update(() {
          swappingDay = null;
          selectedReplacement = null;
        }),
      ),
      gap(14),
      title('Heute lieber etwas anderes.'),
      gap(8),
      Text(
        '${_PlanningPageState.days[day]}, ${displayDate(week.add(Duration(days: day)))} · ${current?.servings ?? servings} Personen',
        style: muted,
      ),
      gap(14),
      surveyCard(
        'BISHER VORGESCHLAGEN',
        current == null
            ? 'Tag bleibt frei'
            : '${current.recipe.name} · ${current.recipe.minutes} Min.',
      ),
      gap(14),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Was passt gerade nicht?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            gap(8),
            DropdownButtonFormField<String>(
              initialValue: replacementReason,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Austauschgrund'),
              items: [
                for (final reason in [
                  'Diese Woche nicht',
                  'Zu aufwendig',
                  'Mag ich nicht',
                ])
                  DropdownMenuItem(value: reason, child: Text(reason)),
              ],
              onChanged: (v) => update(() => replacementReason = v!),
            ),
            gap(8),
            Text(
              '„Diese Woche nicht“ gilt nur für diesen Entwurf. „Zu aufwendig“ beeinflusst nur die Aufwandspassung. „Mag ich nicht“ wertet das Rezept ab. Erst beim Übernehmen speichern wir den Grund.',
              style: muted,
            ),
            if (current != null)
              TextButton(
                onPressed: () => excludeCurrentProposal(current.recipe),
                child: const Text('Nicht mehr vorschlagen →'),
              ),
          ],
        ),
        padding: const EdgeInsets.all(16),
      ),
      gap(18),
      section('Passende Alternativen'),
      if (alternatives.isEmpty)
        surveyCard(
          'Gerade keine weitere Alternative',
          'Im Katalog sind keine weiteren Gerichte verfügbar, die deine Vorgaben erfüllen und noch nicht im Plan stehen. Du kannst zurückgehen und den Tag freilassen.',
          color: AppColors.cream,
        ),
      for (final recipe in alternatives) ...[
        surveyChoice(
          recipe.name,
          selectedReplacement?.id == recipe.id,
          () => update(() => selectedReplacement = recipe),
          subtitle:
              '${mealDescription(recipe, current?.servings ?? servings)}\n${recipeOrigin(recipe)}',
        ),
        gap(14),
      ],
    ];
  }

  Future<void> excludeCurrentProposal(Recipe recipe) async {
    final excluded = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nicht mehr vorschlagen?'),
        content: Text(
          '„${recipe.name}“ wird aus künftigen Vorschlägen ausgeblendet. Du kannst das in deiner Rezeptsammlung rückgängig machen. Dies ist kein Allergieausschluss.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Nicht vorschlagen'),
          ),
        ],
      ),
    );
    if (excluded != true || !mounted || swappingDay == null || draft == null) {
      return;
    }
    update(() {
      hiddenRecipes.add(recipe.id);
      draft!.remove(swappingDay!);
      acceptedDays.remove(swappingDay!);
      changedProposalDays.add(swappingDay!);
    });
    savePreferences();
  }

  void applyReplacement() {
    if (draft == null || swappingDay == null || selectedReplacement == null) {
      return;
    }
    if (!replacementRecipes.any((r) => r.id == selectedReplacement!.id)) return;
    final day = swappingDay!;
    final previous = draft![day]?.recipe;
    if (previous != null) {
      deferredRecipes.add(previous.id);
      if (replacementReason == 'Zu aufwendig') {
        effortFeedback[previous.id] = (effortFeedback[previous.id] ?? 0) + 1;
      }
      if (replacementReason == 'Mag ich nicht') {
        dislikeFeedback[previous.id] = (dislikeFeedback[previous.id] ?? 0) + 1;
      }
    }
    selfChosenRecipes.add(selectedReplacement!.id);
    update(() {
      draft![day] = PlannedMeal(
        selectedReplacement!,
        draft![day]?.servings ?? servings,
      );
      changedProposalDays.add(day);
      acceptedDays.add(day);
      swappingDay = null;
      selectedReplacement = null;
    });
    savePreferences();
  }

  Future<void> confirmProposal() async {
    if (saving || loading || loadError != null || draft == null) return;
    if (widget.client != null && widget.user == null) {
      await account();
      return;
    }
    final next = Map<int, PlannedMeal>.from(draft!);
    final proposedDraft = draft;
    final scope = activeHouseholdId;
    final targetWeek = dateKey(week);
    if (accountConnected && !await flushAccountData()) return;
    if (!mounted) return;
    update(() => loading = true);
    try {
      await refreshPlanningHousehold();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Die aktuellen Haushaltsregeln konnten nicht geprüft werden. Der Vorschlag wurde nicht gespeichert.',
            ),
          ),
        );
      }
      return;
    } finally {
      if (mounted) update(() => loading = false);
    }
    if (!mounted ||
        !identical(draft, proposedDraft) ||
        activeHouseholdId != scope ||
        dateKey(week) != targetWeek) {
      return;
    }
    final profile = plannerProfile;
    final history = plannerHistory;
    final conflicts = <String>[];
    for (final entry in next.entries) {
      if (editingPlan && !changedProposalDays.contains(entry.key)) continue;
      final date = week.add(Duration(days: entry.key));
      final relevantHistory = history.where(
        (h) =>
            !(plan[entry.key]?.recipe.id == entry.value.recipe.id &&
                h.recipeId == entry.value.recipe.id &&
                calendarDay(h.date) == calendarDay(date)),
      );
      if (!const WeeklyPlanner().eligible(
        entry.value.recipe,
        PlannerDay(
          date,
          maxMinutes: dayTimeLimits[dateKey(date)] ?? maxMinutes,
          servings: entry.value.servings,
        ),
        profile,
        relevantHistory,
        allowRepeats: allowPlanRepeats,
      )) {
        conflicts.add(entry.value.recipe.name);
      }
    }
    if (conflicts.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vorschlag bitte anpassen'),
          content: Text(
            'Diese Gerichte erfüllen die aktuellen Vorgaben nicht mehr: ${conflicts.join(', ')}. Bitte austauschen oder den jeweiligen Tag freilassen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zurück zum Vorschlag'),
            ),
          ],
        ),
      );
      return;
    }
    if (!await saveMeals(next) || !mounted) return;
    update(() {
      draft = null;
      swappingDay = null;
      selectedReplacement = null;
      proposalConfirmed = true;
    });
    savePreferences();
  }
}
