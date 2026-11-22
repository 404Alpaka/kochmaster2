part of 'planning_page.dart';

extension _HouseholdRules on _PlanningPageState {
  int dislikeScore(Recipe recipe) {
    String normalize(String text) => text.toLowerCase().replaceAll(
      RegExp(r'pilze|pilz|champignons?|shiitake|pfifferlinge?'),
      'pilz',
    );
    return personalDislikes
        .where(
          (d) =>
              recipe.ingredients.any(
                (i) => normalize(i.name).contains(normalize(d)),
              ) ||
              normalize(recipe.name).contains(normalize(d)),
        )
        .length;
  }

  void openRuleEditor({String? rule, bool personal = false}) => update(() {
    originalRule = rule;
    ruleName = rule ?? '';
    personalRule = personal;
    ruleError = null;
    householdPage = 8;
  });
  void openDislikeEditor([String? dislike]) => update(() {
    originalDislike = dislike;
    dislikeName = dislike ?? '';
    dislikeActive = true;
    ruleError = null;
    householdPage = 10;
  });

  Widget rulesSection(String title, String hint, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(hint),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  void toggleFixedRule(Set<String> target, String rule) {
    update(() {
      if (target.contains(rule)) {
        target.remove(rule);
      } else {
        target.add(rule);
      }
    });
    savePreferences();
  }

  List<Widget> householdRulesView() => [
    gap(14),
    Text(
      'Ausschlüsse & Abneigungen',
      style: Theme.of(context).textTheme.headlineMedium
          ?.copyWith(color: AppColors.sage),
    ),
    gap(8),
    Text(
      'Lege fest, was im Wochenplan nie vorkommen soll und was du nur weniger bevorzugst.',
      style: muted,
    ),
    gap(16),
    rulesSection(
      'Allergien & feste Ausschlüsse',
      activeHousehold == null
          ? 'Diese Zutaten werden bei deinen persönlichen Rezeptvorschlägen ausgeschlossen.'
          : 'Gemeinsame Ausschlüsse gelten für den gesamten Haushalt.',
      [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final rule in planningAllergens)
              FilterChip(
                label: Text(rule),
                selected: exclusions.contains(rule),
                onSelected: (_) => toggleFixedRule(exclusions, rule),
              ),
            for (final rule in exclusions.where(
              (rule) => !planningAllergens.contains(rule),
            ))
              ActionChip(
                label: Text(rule),
                onPressed: () => openRuleEditor(rule: rule),
              ),
          ],
        ),
        if (exclusions.isEmpty)
          Text('Noch keine festen Ausschlüsse hinterlegt.', style: muted),
        gap(8),
        TextButton.icon(
          onPressed: () => openRuleEditor(),
          icon: const Icon(Icons.add),
          label: const Text('Weiteren Ausschluss hinzufügen'),
        ),
      ],
    ),
    rulesSection(
      'Meine persönlichen festen Regeln',
      'Allergien oder Unverträglichkeiten gelten nur für dich.',
      [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final rule in planningAllergens)
              FilterChip(
                label: Text(rule),
                selected: personalExclusions.contains(rule),
                onSelected: (_) => toggleFixedRule(personalExclusions, rule),
              ),
            for (final rule in personalExclusions.where(
              (rule) => !planningAllergens.contains(rule),
            ))
              ActionChip(
                label: Text(rule),
                onPressed: () => openRuleEditor(rule: rule, personal: true),
              ),
          ],
        ),
        if (personalExclusions.isEmpty)
          Text(
            'Noch keine persönlichen festen Regeln hinterlegt.',
            style: muted,
          ),
        gap(8),
        TextButton.icon(
          onPressed: () => openRuleEditor(personal: true),
          icon: const Icon(Icons.add),
          label: const Text('Persönliche Regel hinzufügen'),
        ),
      ],
    ),
    rulesSection(
      'Abneigungen',
      'Nicht medizinisch: Passende Gerichte werden weniger bevorzugt, aber nicht grundsätzlich ausgeschlossen.',
      [
        if (personalDislikes.isEmpty)
          Text('Noch keine Abneigungen hinterlegt.', style: muted),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final dislike in personalDislikes)
              FilterChip(
                label: Text(dislike),
                selected: true,
                onSelected: (_) => openDislikeEditor(dislike),
              ),
          ],
        ),
        gap(8),
        TextButton.icon(
          onPressed: () => openDislikeEditor(),
          icon: const Icon(Icons.add),
          label: const Text('Abneigung hinzufügen'),
        ),
      ],
    ),
    rulesSection(
      '${hiddenRecipes.length} ausgeblendete Rezepte',
      'Aus „Nicht vorschlagen“. Deine Rezepte werden nicht gelöscht.',
      [
        TextButton.icon(
          onPressed: () => householdGo(9),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Ansehen & wieder freigeben'),
        ),
      ],
    ),
    gap(4),
    Text(
      'Neue Regeln gelten für künftige Vorschläge. Bereits bestätigte Pläne werden nicht automatisch verändert.',
      style: muted,
    ),
  ];

  List<Widget> householdRuleEditor() => [
    gap(14),
    title(
      originalRule == null
          ? 'Festen Ausschluss hinzufügen.'
          : 'Festen Ausschluss ändern.',
    ),
    gap(18),
    TextFormField(
      key: ValueKey('rule-$originalRule-$personalRule'),
      initialValue: ruleName,
      decoration: InputDecoration(
        labelText: 'Zutat oder Allergen',
        errorText: ruleError,
      ),
      onChanged: (v) => ruleName = v,
    ),
    gap(18),
    surveyCard(
      'Gilt für',
      personalRule
          ? 'Dich · persönliche feste Regel'
          : '$householdName · gemeinsame Planungsregel',
    ),
    gap(18),
    surveyCard(
      'Art der Regel',
      personalRule
          ? 'Persönliche Allergie oder Unverträglichkeit · von dir gepflegt'
          : 'Fester Ausschluss · keine persönliche Allergieangabe',
    ),
    gap(18),
    panel(
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✓ Immer ausschließen',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Nicht durch Budget, Favoriten oder Abneigungen überstimmen.',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
      color: AppColors.sage,
    ),
    gap(18),
    surveyCard(
      'Geprüfte Angaben sind erforderlich.',
      'Für Milch, Eier, Erdnüsse, Schalenfrüchte, Gluten und Soja werden die geprüften Katalogangaben verwendet. Frei eingegebene Regeln sperren automatische Vorschläge, solange keine geprüfte Zuordnung vorhanden ist.',
      color: AppColors.cream,
    ),
    gap(18),
    if (originalRule != null)
      recipeAction('Entfernung prüfen', false, removeFixedRule),
    gap(14),
    Text(
      'Persönliche Regeln anderer Personen bleiben unverändert. Eine Änderung schreibt deinen bestehenden Wochenplan nicht automatisch um.',
      style: muted,
    ),
  ];

  Future<void> confirmRuleChange(VoidCallback change) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Festen Ausschluss ändern?'),
        content: Text(
          'Die Änderung gilt für künftige Vorschläge. ${plan.length} bereits geplante Gerichte werden nicht automatisch verändert und müssen erneut geprüft werden. Andere persönliche Regeln bleiben bestehen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Änderung bestätigen'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      update(() {
        change();
        householdPage = 7;
      });
      savePreferences();
    }
  }

  void saveFixedRule() {
    var value = ruleName.trim();
    if (value.isEmpty) {
      update(() => ruleError = 'Bitte eine Zutat oder ein Allergen eingeben.');
      return;
    }
    for (final known in [
      'Milch',
      'Eier',
      'Erdnüsse',
      'Schalenfrüchte',
      'Gluten',
      'Soja',
    ]) {
      if (known.toLowerCase() == value.toLowerCase()) value = known;
    }
    final target = personalRule ? personalExclusions : exclusions;
    if (target.any(
      (r) => r != originalRule && r.toLowerCase() == value.toLowerCase(),
    )) {
      update(() => ruleError = 'Diese Regel ist bereits hinterlegt.');
      return;
    }
    void change() {
      if (originalRule != null) target.remove(originalRule);
      target.add(value);
    }

    if (originalRule != null && originalRule != value) {
      confirmRuleChange(change);
    } else {
      update(() {
        change();
        householdPage = 7;
      });
      savePreferences();
    }
  }

  Future<void> removeFixedRule() async {
    if (originalRule == null) return;
    await confirmRuleChange(
      () =>
          (personalRule ? personalExclusions : exclusions).remove(originalRule),
    );
  }

  String hiddenRecipeName(String id) {
    for (final r in [...recipes, ...plan.values.map((m) => m.recipe)]) {
      if (r.id == id) return r.name;
    }
    return 'Nicht mehr im Katalog · $id';
  }

  List<Widget> hiddenRecipesView() => [
    gap(14),
    title('Ausgeblendete Rezepte'),
    gap(12),
    Text(
      'Für dich · ${hiddenRecipes.length} Rezepte · aus Vorschlägen ausgeblendet',
      style: muted,
    ),
    gap(18),
    if (hiddenRecipes.isEmpty)
      surveyCard(
        'Alles wieder sichtbar.',
        'Zurzeit ist kein Rezept ausgeblendet.',
      ),
    for (final id in hiddenRecipes) ...[
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hiddenRecipeName(id),
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
            ),
            gap(10),
            const Text(
              'Ausgeblendet nach „Nicht vorschlagen“',
              style: TextStyle(
                color: AppColors.sage,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            gap(10),
            Text(
              'Das Rezept wurde nicht gelöscht. Ein gesonderter Grund wurde bisher nicht gespeichert.',
              style: muted,
            ),
            gap(14),
            recipeAction('Dieses Rezept wieder vorschlagen', true, () {
              update(() => hiddenRecipes.remove(id));
              savePreferences();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Rezept freigegeben. Feste Regeln und Abneigungen bleiben bestehen.',
                  ),
                ),
              );
            }),
          ],
        ),
        padding: const EdgeInsets.all(18),
      ),
      gap(18),
    ],
    surveyCard(
      'Nur dieses Rezept freigeben.',
      'Abneigungen, Allergien und feste Ausschlüsse bleiben bestehen. Eine Freigabe macht ein Rezept nicht automatisch passend.',
      color: AppColors.softGreen,
    ),
    gap(14),
    recipeAction(
      'Abneigungen separat bearbeiten',
      false,
      () => openDislikeEditor(),
    ),
  ];

  List<Widget> dislikeEditorView() => [
    gap(14),
    title('Was magst du weniger?'),
    gap(12),
    Text('Deine persönliche Vorliebe · keine Allergie', style: muted),
    gap(18),
    TextFormField(
      key: ValueKey('dislike-$originalDislike'),
      initialValue: dislikeName,
      decoration: InputDecoration(
        labelText: 'Zutat oder Zutatengruppe',
        hintText: 'z. B. Pilze',
        errorText: ruleError,
      ),
      onChanged: (v) => dislikeName = v,
    ),
    gap(18),
    surveyChoice(
      'Andere Zutaten bevorzugen',
      dislikeActive,
      () => update(() => dislikeActive = true),
      subtitle: 'Passende Gerichte mit dieser Zutat nachrangig behandeln, aber nicht fest ausschließen.',
    ),
    gap(14),
    surveyChoice(
      'Wieder neutral bewerten',
      !dislikeActive,
      () => update(() => dislikeActive = false),
      subtitle: 'Diese Zutat nicht mehr nachrangig behandeln.',
    ),
    gap(18),
    surveyCard(
      '✓ Berücksichtigen, wenn ich mitesse',
      'Bei getrennten Gerichten verändert deine Abneigung nicht automatisch die Auswahl anderer Personen. Der Abgleich erfolgt anhand der Zutaten- und Rezeptnamen.',
      color: AppColors.softGreen,
    ),
    gap(18),
    surveyCard(
      'Rezeptausblendungen bleiben separat.',
      'Ein ausgeblendetes Rezept bleibt ausgeblendet, bis du es unter „Ausgeblendete Rezepte“ ausdrücklich freigibst.',
      color: AppColors.cream,
    ),
  ];
  void saveDislike() {
    final value = dislikeName.trim();
    if (value.isEmpty) {
      update(() => ruleError = 'Bitte eine Zutat eingeben.');
      return;
    }
    update(() {
      personalDislikes.removeWhere(
        (d) => d.toLowerCase() == (originalDislike ?? value).toLowerCase(),
      );
      if (dislikeActive) personalDislikes.add(value);
      householdPage = 7;
    });
    savePreferences();
  }

  Future<void> addHouseholdRule() async {
    final kind = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Gemeinsamer fester Ausschluss'),
              onTap: () => Navigator.pop(context, 0),
            ),
            ListTile(
              title: const Text('Meine Allergie / Unverträglichkeit'),
              onTap: () => Navigator.pop(context, 1),
            ),
            ListTile(
              title: const Text('Persönliche Abneigung'),
              onTap: () => Navigator.pop(context, 2),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    if (kind == 2) {
      openDislikeEditor();
    } else {
      openRuleEditor(personal: kind == 1);
    }
  }

  Widget rulesActionBar() {
    if (householdPage == 9) return const SizedBox.shrink();
    final label = householdPage == 7
        ? 'Regel hinzufügen +'
        : householdPage == 8
        ? 'Änderung am Ausschluss speichern'
        : 'Persönliche Vorliebe speichern';
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
                  onPressed: () {
                    if (householdPage == 7) {
                      addHouseholdRule();
                    } else if (householdPage == 8) {
                      saveFixedRule();
                    } else {
                      saveDislike();
                    }
                  },
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
              gap(8),
              Text(
                householdPage == 10
                    ? 'Ändert keine Allergie und keinen festen Ausschluss.'
                    : 'Persönliche Gesundheitsregeln bleiben bei der jeweiligen Person.',
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
