part of 'planning_page.dart';

extension _PlanningSurvey on _PlanningPageState {
  Widget surveyCard(
    String heading,
    String body, {
    Color color = Colors.white,
  }) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        gap(7),
        Text(body, style: muted),
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
    if (proposalConfirmed) return confirmedProposalView();
    if (plan.isNotEmpty) return planView();
    return [
      title('Deine Woche'),
      gap(5),
      Text('Ein guter Plan beginnt mit deinem Geschmack.', style: muted),
      gap(18),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GUT ESSEN. AUF DEINE ART.',
              style: TextStyle(color: Color(0xFFD5E3C8), fontSize: 13),
            ),
            gap(10),
            const Text(
              'Was schmeckt dir\ndiese Woche?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            gap(10),
            const Text(
              'Entdecke erst in Ruhe Rezepte. Deinen Plan erstellen wir, wenn du bereit bist.',
              style: TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
            ),
          ],
        ),
        color: AppColors.sage,
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
      if (recipes.isNotEmpty)
        panel(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                child: recipePhoto(recipes.first, height: 70),
              ),
            ),
            title: Text(recipes.first.name),
            subtitle: Text(
              '${recipes.first.minutes} Min. · Rezept kennenlernen →',
            ),
            onTap: () {
              selectTab(0);
              details(recipes.first);
            },
          ),
        ),
      gap(18),
      surveyCard(
        'Beim ersten Mal: 4 kurze Fragen',
        'Allergien, Ernährung, Personen & Tage, Kochzeit. Danach bestätigst du vor dem Vorschlag dein Planbudget.',
        color: AppColors.softGreen,
      ),
      gap(18),
      weekPicker(),
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

  bool get showPlanningAction => tab == 1 &&
      (surveyStep > 0 || (draft == null && !proposalConfirmed && plan.isEmpty));

  void startPlanning() {
    if (saving || loading || loadError != null) return;
    if (!planBudgetInitialized) {
      planBudget = budget;
      planBudgetInitialized = true;
    }
    update(() => surveyStep = surveyCompleted ? 5 : 1);
  }

  Widget planningActionBar() {
    final label = switch (surveyStep) {
      1 => 'Weiter: Ernährungsweise',
      2 => 'Weiter: Personen & Tage',
      3 => 'Weiter: Kochzeit',
      4 => 'Weiter: Planbudget',
      5 => planBudget != null && planBudget! < 62.40 ? 'Budgetkonflikt ansehen · Demo' : 'Wochenvorschlag erstellen',
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
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: double.infinity, child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            onPressed: saving || loading || loadError != null || (surveyStep == 7 && !canApplyBudgetDemo) ? null : () {
              if (surveyStep == 0) { startPlanning(); return; }
              if (surveyStep < 5) {
                if (surveyStep == 4 && !planBudgetInitialized) {
                  planBudget = budget;
                  planBudgetInitialized = true;
                }
                update(() => surveyStep++);
                return;
              }
              if (surveyStep == 5 && planBudget != null && planBudget! < 62.40) {
                update(() { budgetDemoSelections.addAll([0, 1, 2, 3]); surveyStep = 6; });
                return;
              }
              if (surveyStep == 6) { update(() => surveyStep = 7); return; }
              if (surveyStep == 7) { applyBudgetDemo(); return; }
              surveyCompleted = true;
              savePreferences();
              createProposal();
            },
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(label, textAlign: TextAlign.center),
          )),
          gap(8),
          Text(hint, textAlign: TextAlign.center, style: muted.copyWith(fontSize: 12)),
        ]),
      ),
    ));
  }

  List<Widget> planBudgetView() => [
    Align(alignment: Alignment.centerLeft, child: TextButton.icon(
      onPressed: () => update(() => surveyStep = 4),
      icon: const Icon(Icons.arrow_back, size: 18),
      label: const Text('Zurück zur Kochzeit'),
    )),
    gap(18),
    title('Was darf dein Plan kosten?'),
    gap(12),
    Text('Vor dem Vorschlag · $planningDays Abendessen für $servings ${servings == 1 ? 'Person' : 'Personen'}', style: muted.copyWith(fontSize: 15)),
    gap(18),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('DEIN PLANBUDGET', style: muted.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
      gap(12),
      Text(planBudget == null ? 'Kein Limit' : euro(planBudget!), textAlign: TextAlign.center, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w600)),
      gap(12),
      Row(children: [
        IconButton.filledTonal(tooltip: 'Planbudget verringern', onPressed: planBudget != null && planBudget! > 5 ? () => update(() => planBudget = (planBudget! - 5).clamp(5, 10000).toDouble()) : null, icon: const Icon(Icons.remove)),
        const SizedBox(width: 10),
        Expanded(child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.softGreen, borderRadius: BorderRadius.circular(16)), child: const Text('für diese Woche', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600)))),
        const SizedBox(width: 10),
        IconButton.filledTonal(tooltip: 'Planbudget erhöhen', onPressed: () => update(() => planBudget = ((planBudget ?? budget) + 5).clamp(5, 10000).toDouble()), icon: const Icon(Icons.add)),
      ]),
      gap(14),
      Row(children: [
        for (final amount in <double?>[55, 75, null]) ...[
          if (amount != 55) const SizedBox(width: 6),
          Expanded(child: recipeAction(amount == null ? 'Kein Limit' : '${amount.toInt()} €', planBudget == amount, () => update(() => planBudget = amount))),
        ],
      ]),
    ])),
    gap(18),
    surveyCard('Dein Budget gilt für die geplanten Abendessen.', 'Eigene Zusatzartikel, Frühstück, Mittagessen und Snacks gehören nicht zu diesem Planbudget. Dein allgemeines Wochenbudget bleibt unverändert.', color: AppColors.softGreen),
    gap(18),
    surveyCard('Budgetablauf ausprobieren · Demo', 'Wähle 55 €, um den Budgetkonflikt und günstigere Alternativen aus Figma durchzuspielen. Das Beispiel zeigt 7 Abendessen für 2 Personen mit 62,40 € Ausgangskosten. Es ist unabhängig von deinem Katalog; echte Produktpreise fehlen noch.', color: AppColors.cream),
    gap(18),
    surveyCard('Deine Vorgaben bleiben deine Vorgaben.', 'Allergien und feste Ausschlüsse gelten unabhängig vom Budget. Der Wochenplan wird erst nach deiner Bestätigung übernommen.', color: AppColors.softGreen),
    gap(14),
    TextButton(
      onPressed: saving || loading || loadError != null ? null : () {
        surveyCompleted = true;
        savePreferences();
        createProposal();
      },
      child: const Text('Katalogvorschlag ohne Kostenprüfung erstellen'),
    ),
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
              for (final count in ([...{3, 5, 7, planningDays}]..sort()))
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
    final activeExclusions = {...exclusions, if (includePersonal) ...personalExclusions};
    if (hiddenRecipes.contains(recipe.id)) return false;
    if (maxMinutes > 0 && recipe.minutes > maxMinutes) return false;
    if (recipe.ingredients.isEmpty) return false;
    return matchesVerifiedRestrictions(recipe, diet, activeExclusions);
  }

  List<Recipe> get eligibleRecipes => recipes.where((r) => recipeMatchesPlanning(r)).toList();

  void createProposal() {
    final eligible = eligibleRecipes;
    int preferenceRank(Recipe recipe) => favoriteRecipes.contains(recipe.id) ? 0 : rememberedRecipes.contains(recipe.id) ? 1 : 2;
    final catalogOrder = {for (var i = 0; i < recipes.length; i++) recipes[i].id: i};
    eligible.sort((a, b) {
      final aversion = dislikeScore(a).compareTo(dislikeScore(b));
      if (aversion != 0) return aversion;
      final rank = preferenceRank(a).compareTo(preferenceRank(b));
      return rank != 0 ? rank : catalogOrder[a.id]!.compareTo(catalogOrder[b.id]!);
    });
    update(() {
      surveyStep = 0;
      editingPlan = false;
      acceptedDays.clear();
      changedProposalDays.clear();
      swappingDay = null;
      selectedReplacement = null;
      proposalConfirmed = false;
      draft = {
        for (var i = 0; i < planningDays && i < eligible.length; i++)
          startDay + i: PlannedMeal(eligible[i], servings),
      };
    });
  }

  void editExistingPlan() {
    if (saving || loading || loadError != null) return;
    update(() {
      surveyStep = 0;
      editingPlan = true;
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
