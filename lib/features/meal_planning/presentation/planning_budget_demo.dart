part of 'planning_page.dart';

// Isolated, explicitly labelled Figma scenario. These are not retailer prices.
extension _PlanningBudgetDemo on _PlanningPageState {
  static const _savings = [1.60, 1.00, 2.00, 3.90];
  static const _changes = [
    ('Montag: Linsen-Reis-Bowl', 'Statt Kichererbsen-Bowl\n4,80 € → 3,20 € für 2 Portionen'),
    ('Dienstag: Tomatenpasta', 'Statt Zitronenpasta\n3,70 € → 2,70 € für 2 Portionen'),
    ('Passende Eigenmarken', 'Gleiche benötigte Mengen; günstigere Beispielprodukte.'),
    ('Selbst einkaufen', 'Statt Lieferung; keine Liefergebühr.'),
  ];

  double get budgetDemoTotal => 62.40 - budgetDemoSelections.fold<double>(0, (sum, i) => sum + _savings[i]);
  double get budgetDemoLimit => planBudget ?? 55;
  List<Recipe> get budgetDemoRecipes => [
    _demoRecipe(budgetDemoSelections.contains(0) ? 'Linsen-Reis-Bowl' : 'Kichererbsen-Bowl', 25, [
      const IngredientAmount('rice', 'Reis', 150, 'g'),
      IngredientAmount(budgetDemoSelections.contains(0) ? 'lentils' : 'chickpeas', budgetDemoSelections.contains(0) ? 'Linsen' : 'Kichererbsen', 240, 'g'),
      const IngredientAmount('zucchini', 'Zucchini', 200, 'g'),
    ]),
    _demoRecipe(budgetDemoSelections.contains(1) ? 'Tomatenpasta' : 'Zitronenpasta', 20, [
      const IngredientAmount('pasta', 'Nudeln', 200, 'g'),
      if (budgetDemoSelections.contains(1)) const IngredientAmount('tomato', 'Tomaten', 300, 'g')
      else const IngredientAmount('lemon', 'Zitrone', 1, 'Stück'),
      const IngredientAmount('olive-oil', 'Olivenöl', 20, 'ml'),
    ], gluten: true),
    _demoRecipe('Rotes Linsen-Dal', 30, [const IngredientAmount('lentils', 'Linsen', 180, 'g'), const IngredientAmount('tomato', 'Tomaten', 300, 'g')]),
    _demoRecipe('Ofenkartoffeln mit Kräutern', 30, [const IngredientAmount('potato', 'Kartoffeln', 600, 'g'), const IngredientAmount('olive-oil', 'Olivenöl', 20, 'ml')]),
    _demoRecipe('Gemüse-Reispfanne', 25, [const IngredientAmount('rice', 'Reis', 150, 'g'), const IngredientAmount('zucchini', 'Zucchini', 300, 'g')]),
    _demoRecipe('Spinat-Kichererbsen-Curry', 30, [const IngredientAmount('spinach', 'Spinat', 200, 'g'), const IngredientAmount('chickpeas', 'Kichererbsen', 240, 'g')]),
    _demoRecipe('Kartoffel-Spinat-Pfanne', 25, [const IngredientAmount('potato', 'Kartoffeln', 500, 'g'), const IngredientAmount('spinach', 'Spinat', 200, 'g')]),
  ];

  Recipe _demoRecipe(String name, int minutes, List<IngredientAmount> ingredients, {bool gluten = false}) => Recipe(
    id: 'budget-demo-${name.toLowerCase().replaceAll(' ', '-')}', name: name, minutes: minutes, servings: 2,
    ingredients: ingredients,
    steps: const ['Dies ist ein Beispielgericht für die Budget-Demo. Eine vollständige Kochanleitung ist noch nicht hinterlegt.'],
    verifiedAllergens: gluten ? const {'Gluten'} : const {},
    verifiedDiets: const {'Vegetarisch', 'Vegan'},
  );

  bool get canApplyBudgetDemo => budgetDemoTotal <= budgetDemoLimit &&
      planningDays == 7 && servings == 2 && startDay == 0 &&
      budgetDemoRecipes.every((r) => recipeMatchesPlanning(r));

  Widget budgetBack(String label, int step) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(onPressed: () => update(() => surveyStep = step), icon: const Icon(Icons.arrow_back, size: 18), label: Text(label)),
  );

  List<Widget> budgetConflictView() => [
    budgetBack('Planbudget ändern', 5),
    gap(18),
    Text('DEMO · ${euro(budgetDemoLimit)} GEWÄHLT', style: const TextStyle(color: AppColors.sage, fontSize: 13, fontWeight: FontWeight.w600)),
    gap(18),
    title('Deine Wünsche passen nicht ins Budget.'),
    gap(18),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('62,40 € benötigt', style: TextStyle(color: Color(0xFF80511E), fontSize: 28, fontWeight: FontWeight.w600)),
      gap(7),
      Text('${euro(budgetDemoLimit)} Budget · ${euro(62.40 - budgetDemoLimit)} darüber', style: const TextStyle(color: Color(0xFF80511E), fontSize: 16, fontWeight: FontWeight.w600)),
      gap(7),
      const Text('Beispiel: 7 Abendessen · 2 Personen · inklusive 3,90 € Lieferung', style: TextStyle(color: Color(0xFF80511E), fontSize: 14)),
    ]), color: const Color(0xFFF6E9CF)),
    gap(18),
    section('Diese konkreten Wechsel helfen:'),
    surveyCard('Bowl durch Linsen-Reis-Bowl ersetzen', '2,40 € → 1,60 € pro Portion\nFür 2 Personen: 1,60 € weniger'),
    gap(14),
    surveyCard('Tomatenpasta statt Zitronenpasta', '1,85 € → 1,35 € pro Portion\nFür 2 Personen: 1,00 € weniger'),
    gap(18),
    Text('Zusätzlich möglich: Eigenmarken wählen und selbst einkaufen. Nichts wird ungefragt ausgetauscht.', style: muted),
    gap(14),
    recipeAction('Stattdessen Budget anpassen', false, () => update(() => surveyStep = 5)),
    gap(14),
    Text('Figma-Demo mit Beispielgerichten und Beispielpreisen. Dein bisheriger Wochenplan bleibt erhalten.', style: muted),
  ];

  List<Widget> budgetAlternativesView() {
    final fits = budgetDemoTotal <= budgetDemoLimit;
    final savings = 62.40 - budgetDemoTotal;
    return [
      budgetBack('Zurück zum Budgetkonflikt', 6),
      gap(18),
      title(fits ? 'So passt es in ${euro(budgetDemoLimit)}.' : 'Noch nicht im Planbudget.'),
      gap(18),
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(euro(budgetDemoTotal), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: Colors.white)),
        gap(8),
        Text('${euro((budgetDemoLimit - budgetDemoTotal).abs())} ${fits ? 'unter' : 'über'} deinem Planbudget', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        gap(8),
        Text('Demo · 7 Abendessen · 2 Personen\n${budgetDemoSelections.contains(3) ? 'Selbst einkaufen · keine Liefergebühr' : 'Mit Lieferung · 3,90 € Liefergebühr'}', style: const TextStyle(fontSize: 14, color: Colors.white)),
      ]), color: AppColors.sage),
      gap(18),
      for (var i = 0; i < _changes.length; i++) ...[
        panel(CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: budgetDemoSelections.contains(i),
          onChanged: (_) => update(() { if (!budgetDemoSelections.add(i)) budgetDemoSelections.remove(i); }),
          title: Text(_changes[i].$1, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            gap(7), Text(_changes[i].$2, style: muted), gap(7),
            Text('− ${euro(_savings[i])}', style: const TextStyle(fontSize: 18, color: AppColors.sage, fontWeight: FontWeight.w600)),
          ]),
        ), padding: const EdgeInsets.all(16)),
        gap(18),
      ],
      surveyCard('62,40 € − ${euro(savings)} = ${euro(budgetDemoTotal)}', 'Nur ausgewählte Änderungen werden übernommen. Die übrigen Beispielgerichte bleiben unverändert.', color: AppColors.softGreen),
      gap(14),
      if (!canApplyBudgetDemo) ...[
        surveyCard('Bitte passe die Demo-Auswahl an.', !fits
          ? 'Die ausgewählten Maßnahmen reichen für dein Budget noch nicht aus. Wähle weitere Einsparungen oder erhöhe dein Planbudget.'
          : 'Dieses Figma-Beispiel gilt für 7 Abendessen, 2 Personen und Montag als Starttag. Deine Kochzeit, Ausschlüsse und ausgeblendeten Rezepte müssen ebenfalls passen. Ändere deine Angaben oder erstelle auf der Budgetseite einen regulären Katalogvorschlag.', color: AppColors.cream),
        gap(14),
        recipeAction('Planbudget ändern', false, () => update(() => surveyStep = 5)),
        gap(10),
        TextButton(onPressed: () => update(() => surveyStep = 1), child: const Text('Planungsangaben ändern')),
        gap(14),
      ],
      Text('Preisvorschau mit Beispielpreisen, keine Live-Preise. Demo-Gerichte enthalten Zutaten für die Einkaufsliste, aber noch keine vollständigen Kochanleitungen.', style: muted),
    ];
  }

  void applyBudgetDemo() {
    if (!canApplyBudgetDemo) return;
    final meals = budgetDemoRecipes;
    update(() {
      surveyStep = 0;
      surveyCompleted = true;
      editingPlan = false;
      proposalConfirmed = false;
      acceptedDays.clear();
      changedProposalDays.clear();
      swappingDay = null;
      selectedReplacement = null;
      draft = {for (var i = 0; i < meals.length; i++) i: PlannedMeal(meals[i], 2)};
    });
    savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo-Änderungen im Vorschlag übernommen. Bestätige jetzt deinen Wochenplan.')));
  }
}
