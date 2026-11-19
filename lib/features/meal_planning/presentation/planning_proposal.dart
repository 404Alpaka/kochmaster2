part of 'planning_page.dart';

extension _PlanningProposal on _PlanningPageState {
  bool get showProposalAction => tab == 1 && surveyStep == 0 && draft != null;
  String recipeOrigin(Recipe recipe) => favoriteRecipes.contains(recipe.id)
      ? 'Favorit · magst du besonders'
      : rememberedRecipes.contains(recipe.id)
      ? 'Gemerkt · wolltest du mal kochen'
      : 'Neu für dich · bringt Abwechslung';

  String mealDescription(Recipe recipe, int portions) {
    final dietLabel = recipe.verifiedDiets?.contains('Vegan') == true ? 'vegan'
        : recipe.verifiedDiets?.contains('Vegetarisch') == true ? 'vegetarisch' : null;
    return '${recipe.minutes} Min. · $portions ${portions == 1 ? 'Person' : 'Personen'}${dietLabel == null ? '' : ' · $dietLabel'}';
  }

  Widget proposalBack(String label, VoidCallback action) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(onPressed: saving ? null : action, icon: const Icon(Icons.arrow_back, size: 18), label: Text(label)),
  );

  Widget proposalActionBar() {
    final replacing = swappingDay != null && draft != null;
    final confirmed = draft == null && proposalConfirmed;
    final label = replacing ? 'Dieses Gericht übernehmen' : confirmed ? 'Einkaufsliste öffnen' : 'Wochenplan bestätigen';
    final hint = replacing ? 'Heute keine Lust ≠ grundsätzlich nicht mögen.'
        : confirmed ? 'Nur aus deinem bestätigten Plan.'
        : 'Alle angezeigten Gerichte werden übernommen. Freie Tage bleiben frei.';
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: double.infinity, child: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
          onPressed: saving || loading || loadError != null || (replacing && selectedReplacement == null) ? null : () {
            if (replacing) { applyReplacement(); }
            else if (confirmed) { selectTab(3); }
            else { confirmProposal(); }
          },
          icon: const Icon(Icons.arrow_forward, size: 18), label: Text(label, textAlign: TextAlign.center),
        )),
        gap(8), Text(hint, textAlign: TextAlign.center, style: muted.copyWith(fontSize: 12)),
      ]),
    )));
  }

  List<Widget> proposalView() => [
    Row(children: [
      Expanded(child: proposalBack('Antworten ändern', () => update(() => surveyStep = 1))),
      Text('Vorschlag', style: muted),
    ]),
    if (editingPlan) proposalBack('Bearbeiten abbrechen', () => update(() { draft = null; swappingDay = null; })),
    gap(14), title('Deine Woche. Dein Mix.'), gap(5),
    Text('${displayDate(week)} – ${displayDate(week.add(const Duration(days: 6)))} · ${draft!.length} Abendessen', style: muted),
    gap(14),
    surveyCard('$diet · $servings Personen · ${maxMinutes == 0 ? 'flexible Kochzeit' : 'bis $maxMinutes Min.'}',
      exclusions.isEmpty ? 'Keine festen Ausschlüsse angegeben.' : '${exclusions.join(', ')} ausgeschlossen.\nNur Rezepte mit geprüften Zutaten- und Allergendaten.', color: AppColors.softGreen),
    if (planBudgetInitialized) ...[
      gap(14), surveyCard(planBudget == null ? 'Planbudget: kein Limit' : 'Planbudget: ${euro(planBudget!)}',
        'Preisvorschau noch nicht berechnet. Nach einem Tausch sind frühere Demo-Preise nicht übertragbar.', color: AppColors.softGreen),
    ],
    gap(14),
    Text('Schon passend? Tippe auf „Passt“. Ansonsten tausche das Gericht oder lass den Tag frei.', style: muted),
    gap(14),
    if (!editingPlan && draft!.length < planningDays) ...[
      surveyCard('Freie Tage bleiben flexibel.', 'Nicht jeder Tag hat einen Vorschlag. Du kannst ein Gericht auswählen oder den Tag frei lassen. Deine festen Ausschlüsse bleiben bestehen.', color: AppColors.cream), gap(14),
    ],
    for (var day = editingPlan ? 0 : startDay; day < (editingPlan ? 7 : startDay + planningDays); day++) ...[proposalDay(day), gap(14)],
    surveyCard('Warum gerade diese Gerichte?', 'Feste Ausschlüsse und Kochzeit zuerst. Favoriten und gemerkte Rezepte werden bevorzugt; doppelte Gerichte werden vermieden. Eine echte Preisprüfung folgt mit den Produktpreisen.', color: AppColors.cream),
  ];

  Widget proposalDay(int day) {
    final meal = draft![day];
    final accepted = acceptedDays.contains(day);
    return panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text('${_PlanningPageState.days[day]} · ${displayDate(week.add(Duration(days: day)))}', style: muted.copyWith(fontSize: 13))),
        const SizedBox(width: 8),
        Text(meal == null ? 'Frei' : accepted ? '✓ Passt' : 'Offen', style: TextStyle(fontSize: 13, color: accepted ? AppColors.sage : AppColors.muted)),
      ]),
      gap(8), Text(meal?.recipe.name ?? 'Tag bleibt frei', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      if (meal != null) ...[
        gap(8), Text(mealDescription(meal.recipe, meal.servings), style: muted),
        gap(6), Text(recipeOrigin(meal.recipe), style: const TextStyle(fontSize: 13, color: AppColors.sage)),
      ],
      gap(10),
      Row(children: [
        if (meal != null) ...[
          Expanded(child: dayAction('Passt', accepted, () => update(() { if (!acceptedDays.add(day)) acceptedDays.remove(day); }))),
          const SizedBox(width: 6),
        ],
        Expanded(child: dayAction(meal == null ? 'Gericht wählen' : 'Anderes Gericht', false, () => swapProposal(day))),
        if (meal != null) ...[
          const SizedBox(width: 6),
          Expanded(child: dayAction('Tag freilassen', false, () => update(() {
            draft!.remove(day); acceptedDays.remove(day); changedProposalDays.add(day);
          }))),
        ],
      ]),
    ]), padding: const EdgeInsets.all(16));
  }

  Widget dayAction(String label, bool selected, VoidCallback action) => TextButton(
    onPressed: saving ? null : action,
    style: TextButton.styleFrom(minimumSize: const Size(0, 64), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      backgroundColor: selected ? AppColors.sage : AppColors.softGreen, foregroundColor: selected ? Colors.white : AppColors.lightText,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
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
    return pool.values.where((r) => !used.contains(r.id) && recipeMatchesPlanning(r)).toList();
  }

  void swapProposal(int day) {
    if (saving || draft == null) return;
    update(() { swappingDay = day; selectedReplacement = null; });
    final alternatives = replacementRecipes;
    if (alternatives.isNotEmpty) update(() => selectedReplacement = alternatives.first);
  }

  List<Widget> replacementView() {
    final day = swappingDay!;
    final current = draft![day];
    final alternatives = replacementRecipes;
    return [
      proposalBack('Zurück zum Wochenvorschlag', () => update(() { swappingDay = null; selectedReplacement = null; })),
      gap(14), title('Heute lieber etwas anderes.'), gap(8),
      Text('${_PlanningPageState.days[day]}, ${displayDate(week.add(Duration(days: day)))} · ${current?.servings ?? servings} Personen', style: muted),
      gap(14),
      surveyCard('BISHER VORGESCHLAGEN', current == null ? 'Tag bleibt frei' : '${current.recipe.name} · ${current.recipe.minutes} Min.'),
      gap(14),
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Was passt gerade nicht?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        gap(8), const Text('✓ Heute keine Lust', style: TextStyle(color: AppColors.sage, fontSize: 16, fontWeight: FontWeight.w600)),
        gap(8), Text('Nur dieser Vorschlag ändert sich. Deine gemerkten Rezepte und Favoriten bleiben erhalten.', style: muted),
        if (current != null) TextButton(onPressed: () => excludeCurrentProposal(current.recipe), child: const Text('Mag ich grundsätzlich nicht  →')),
      ]), padding: const EdgeInsets.all(16)),
      gap(18), section('Passende Alternativen'),
      if (alternatives.isEmpty) surveyCard('Gerade keine weitere Alternative', 'Im Katalog sind keine weiteren Gerichte verfügbar, die deine Vorgaben erfüllen und noch nicht im Plan stehen. Du kannst zurückgehen und den Tag freilassen.', color: AppColors.cream),
      for (final recipe in alternatives) ...[
        surveyChoice(recipe.name, selectedReplacement?.id == recipe.id, () => update(() => selectedReplacement = recipe),
          subtitle: '${mealDescription(recipe, current?.servings ?? servings)}\n${recipeOrigin(recipe)}'), gap(14),
      ],
    ];
  }

  Future<void> excludeCurrentProposal(Recipe recipe) async {
    final excluded = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Nicht mehr vorschlagen?'),
      content: Text('„${recipe.name}“ wird aus künftigen Vorschlägen ausgeblendet. Du kannst das in deiner Rezeptsammlung rückgängig machen. Dies ist kein Allergieausschluss.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Nicht vorschlagen')),
      ],
    ));
    if (excluded != true || !mounted || swappingDay == null || draft == null) return;
    update(() {
      hiddenRecipes.add(recipe.id);
      draft!.remove(swappingDay!);
      acceptedDays.remove(swappingDay!);
      changedProposalDays.add(swappingDay!);
    });
    savePreferences();
  }

  void applyReplacement() {
    if (draft == null || swappingDay == null || selectedReplacement == null) return;
    if (!replacementRecipes.any((r) => r.id == selectedReplacement!.id)) return;
    final day = swappingDay!;
    update(() {
      draft![day] = PlannedMeal(selectedReplacement!, draft![day]?.servings ?? servings);
      changedProposalDays.add(day);
      acceptedDays.add(day);
      swappingDay = null; selectedReplacement = null;
    });
  }

  Future<void> confirmProposal() async {
    if (saving || loading || loadError != null || draft == null) return;
    if (widget.client != null && widget.user == null) { await account(); return; }
    final next = Map<int, PlannedMeal>.from(draft!);
    if (!await saveMeals(next) || !mounted) return;
    update(() { draft = null; swappingDay = null; selectedReplacement = null; proposalConfirmed = true; });
    savePreferences();
  }

  List<Widget> confirmedProposalView() => [
    proposalBack('Wochenplan', () => update(() => proposalConfirmed = false)),
    gap(14), title('Deine Woche steht.'), gap(8),
    Text('${displayDate(week)} – ${displayDate(week.add(const Duration(days: 6)))} · $servings Personen', style: muted),
    gap(18),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('✓ Wochenplan bestätigt', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      gap(8), Text('${plan.length} Gerichte · ${7 - plan.length} freie Tage', style: const TextStyle(color: Colors.white, fontSize: 14)),
      if (changedProposalDays.isNotEmpty) ...[
        gap(4), Text('${changedProposalDays.length} ${changedProposalDays.length == 1 ? 'Tag angepasst' : 'Tage angepasst'}.', style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    ]), color: AppColors.sage),
    gap(18),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var day = 0; day < 7; day++) Padding(padding: const EdgeInsets.only(bottom: 8), child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: plan[day] == null ? AppColors.cream : changedProposalDays.contains(day) ? AppColors.softGreen : Colors.transparent, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          SizedBox(width: 32, child: Text(_PlanningPageState.days[day].substring(0, 2), style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(plan[day]?.recipe.name ?? 'Tag bleibt frei', style: TextStyle(fontSize: 13, color: plan[day] == null ? AppColors.muted : AppColors.lightText))),
        ]),
      )),
      TextButton(onPressed: editExistingPlan, child: const Text('Plan weiter bearbeiten  →')),
    ]), padding: const EdgeInsets.all(14)),
    gap(18),
    surveyCard('Jetzt wird daraus deine Einkaufsliste.', 'Wir bündeln die Zutaten aus deinem bestätigten Plan. Freie Tage werden nicht eingerechnet.', color: AppColors.softGreen),
  ];
}
