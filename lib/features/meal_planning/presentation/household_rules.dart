part of 'planning_page.dart';

extension _HouseholdRules on _PlanningPageState {
  int dislikeScore(Recipe recipe) {
    String normalize(String text) => text.toLowerCase().replaceAll(RegExp(r'pilze|pilz|champignons?|shiitake|pfifferlinge?'), 'pilz');
    return personalDislikes.where((d) => recipe.ingredients.any((i) => normalize(i.name).contains(normalize(d))) || normalize(recipe.name).contains(normalize(d))).length;
  }
  void openRuleEditor({String? rule, bool personal = false}) => update(() {
    originalRule = rule; ruleName = rule ?? ''; personalRule = personal; ruleError = null; householdPage = 8;
  });
  void openDislikeEditor([String? dislike]) => update(() {
    originalDislike = dislike; dislikeName = dislike ?? ''; dislikeActive = true; ruleError = null; householdPage = 10;
  });

  List<Widget> householdRulesView() => [
    householdBack(0, 'Haushalt'), gap(14), title('Deine Regeln. Ein Ort.'), gap(12),
    Text('Meine persönlichen und geteilten Regeln – später jederzeit änderbar.', style: muted), gap(18),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section('Allergien & feste Ausschlüsse'),
      Text('$householdName · Planungsregeln', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), gap(8),
      Text('Feste Ausschlüsse für die Planung. Keine automatische persönliche Allergieangabe.', style: muted), gap(10),
      if (exclusions.isEmpty) Text('Keine festen Planungsausschlüsse hinterlegt.', style: muted),
      for (final rule in exclusions) ListTile(contentPadding: EdgeInsets.zero, title: Text(rule), trailing: const Icon(Icons.chevron_right), onTap: () => openRuleEditor(rule: rule)),
      recipeAction('Haushaltsausschluss hinzufügen', false, () => openRuleEditor()), gap(18),
      const Text('Du · persönliche feste Regeln', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), gap(8),
      if (personalExclusions.isEmpty) Text('Keine persönlichen Allergien oder Unverträglichkeiten hinterlegt.', style: muted),
      for (final rule in personalExclusions) ListTile(contentPadding: EdgeInsets.zero, title: Text(rule), trailing: const Icon(Icons.chevron_right), onTap: () => openRuleEditor(rule: rule, personal: true)),
      recipeAction('Meine Allergien & Unverträglichkeiten', false, () => openRuleEditor(personal: true)), gap(14),
      Text(accountConnected ? 'Persönliche Regeln anderer Mitglieder bleiben privat.' : 'Alex · Beispielprofil. Persönliche Gesundheitsregeln anderer Mitglieder werden hier nicht bearbeitet.', style: muted),
    ]), padding: const EdgeInsets.all(16)), gap(18),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section('Abneigungen · nicht medizinisch'),
      if (personalDislikes.isEmpty) Text('Noch keine Abneigungen hinterlegt.', style: muted),
      for (final dislike in personalDislikes) ListTile(contentPadding: EdgeInsets.zero, title: Text('$dislike weniger bevorzugen'), trailing: const Icon(Icons.chevron_right), onTap: () => openDislikeEditor(dislike)),
      recipeAction('Meine Abneigungen bearbeiten', false, () => openDislikeEditor()),
    ]), color: AppColors.softGreen, padding: const EdgeInsets.all(16)), gap(18),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section('${hiddenRecipes.length} ausgeblendete Rezepte'),
      Text('Aus „Nicht vorschlagen“. Deine Rezepte werden nicht gelöscht.', style: muted), gap(10),
      recipeAction('Ansehen & wieder freigeben', false, () => householdGo(9)),
    ]), padding: const EdgeInsets.all(16)), gap(18),
    Text('Neue Regeln gelten für künftige Vorschläge. Bereits bestätigte Pläne musst du nach geänderten Ausschlüssen erneut prüfen.', style: muted),
  ];

  List<Widget> householdRuleEditor() => [
    householdBack(7, 'Vorlieben & Ausschlüsse'), gap(14), title(originalRule == null ? 'Festen Ausschluss hinzufügen.' : 'Festen Ausschluss ändern.'), gap(18),
    TextFormField(key: ValueKey('rule-$originalRule-$personalRule'), initialValue: ruleName, decoration: InputDecoration(labelText: 'Zutat oder Allergen', errorText: ruleError), onChanged: (v) => ruleName = v), gap(18),
    surveyCard('Gilt für', personalRule ? 'Dich · persönliche feste Regel' : '$householdName · gemeinsame Planungsregel'), gap(18),
    surveyCard('Art der Regel', personalRule ? 'Persönliche Allergie oder Unverträglichkeit · von dir gepflegt' : 'Fester Ausschluss · keine persönliche Allergieangabe'), gap(18),
    panel(const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('✓ Immer ausschließen', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)), SizedBox(height: 8),
      Text('Nicht durch Budget, Favoriten oder Abneigungen überstimmen.', style: TextStyle(color: Colors.white, fontSize: 14)),
    ]), color: AppColors.sage), gap(18),
    surveyCard('Geprüfte Angaben sind erforderlich.', 'Für Milch, Eier, Erdnüsse, Schalenfrüchte, Gluten und Soja werden die geprüften Katalogangaben verwendet. Frei eingegebene Regeln sperren automatische Vorschläge, solange keine geprüfte Zuordnung vorhanden ist.', color: AppColors.cream), gap(18),
    if (originalRule != null) recipeAction('Entfernung prüfen', false, removeFixedRule), gap(14),
    Text('Persönliche Regeln anderer Personen bleiben unverändert. Eine Änderung schreibt deinen bestehenden Wochenplan nicht automatisch um.', style: muted),
  ];

  Future<void> confirmRuleChange(VoidCallback change) async {
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Festen Ausschluss ändern?'),
      content: Text('Die Änderung gilt für künftige Vorschläge. ${plan.length} bereits geplante Gerichte werden nicht automatisch verändert und müssen erneut geprüft werden. Andere persönliche Regeln bleiben bestehen.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Änderung bestätigen'))],
    ));
    if (yes == true && mounted) { update(() { change(); householdPage = 7; }); savePreferences(); }
  }

  void saveFixedRule() {
    var value = ruleName.trim();
    if (value.isEmpty) { update(() => ruleError = 'Bitte eine Zutat oder ein Allergen eingeben.'); return; }
    for (final known in ['Milch', 'Eier', 'Erdnüsse', 'Schalenfrüchte', 'Gluten', 'Soja']) { if (known.toLowerCase() == value.toLowerCase()) value = known; }
    final target = personalRule ? personalExclusions : exclusions;
    if (target.any((r) => r != originalRule && r.toLowerCase() == value.toLowerCase())) { update(() => ruleError = 'Diese Regel ist bereits hinterlegt.'); return; }
    void change() { if (originalRule != null) target.remove(originalRule); target.add(value); }
    if (originalRule != null && originalRule != value) { confirmRuleChange(change); }
    else { update(() { change(); householdPage = 7; }); savePreferences(); }
  }

  Future<void> removeFixedRule() async {
    if (originalRule == null) return;
    await confirmRuleChange(() => (personalRule ? personalExclusions : exclusions).remove(originalRule));
  }

  String hiddenRecipeName(String id) {
    for (final r in [...recipes, ...plan.values.map((m) => m.recipe)]) { if (r.id == id) return r.name; }
    return 'Nicht mehr im Katalog · $id';
  }
  List<Widget> hiddenRecipesView() => [
    householdBack(7, 'Vorlieben & Ausschlüsse'), gap(14), title('Ausgeblendete Rezepte'), gap(12),
    Text('Für dich · ${hiddenRecipes.length} Rezepte · aus Vorschlägen ausgeblendet', style: muted), gap(18),
    if (hiddenRecipes.isEmpty) surveyCard('Alles wieder sichtbar.', 'Zurzeit ist kein Rezept ausgeblendet.'),
    for (final id in hiddenRecipes) ...[
      panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(hiddenRecipeName(id), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600)), gap(10),
        const Text('Ausgeblendet nach „Nicht vorschlagen“', style: TextStyle(color: AppColors.sage, fontSize: 14, fontWeight: FontWeight.w600)), gap(10),
        Text('Das Rezept wurde nicht gelöscht. Ein gesonderter Grund wurde bisher nicht gespeichert.', style: muted), gap(14),
        recipeAction('Dieses Rezept wieder vorschlagen', true, () {
          update(() => hiddenRecipes.remove(id)); savePreferences();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rezept freigegeben. Feste Regeln und Abneigungen bleiben bestehen.')));
        }),
      ]), padding: const EdgeInsets.all(18)), gap(18),
    ],
    surveyCard('Nur dieses Rezept freigeben.', 'Abneigungen, Allergien und feste Ausschlüsse bleiben bestehen. Eine Freigabe macht ein Rezept nicht automatisch passend.', color: AppColors.softGreen), gap(14),
    recipeAction('Abneigungen separat bearbeiten', false, () => openDislikeEditor()),
  ];

  List<Widget> dislikeEditorView() => [
    householdBack(7, 'Vorlieben & Ausschlüsse'), gap(14), title('Was magst du weniger?'), gap(12), Text('Deine persönliche Vorliebe · keine Allergie', style: muted), gap(18),
    TextFormField(key: ValueKey('dislike-$originalDislike'), initialValue: dislikeName, decoration: InputDecoration(labelText: 'Zutat oder Zutatengruppe', hintText: 'z. B. Pilze', errorText: ruleError), onChanged: (v) => dislikeName = v), gap(18),
    surveyChoice('Andere Zutaten bevorzugen', dislikeActive, () => update(() => dislikeActive = true), subtitle: 'Passende Gerichte mit dieser Zutat nachrangig behandeln, aber nicht fest ausschließen.'), gap(14),
    surveyChoice('Wieder neutral bewerten', !dislikeActive, () => update(() => dislikeActive = false), subtitle: 'Diese Zutat nicht mehr nachrangig behandeln.'), gap(18),
    surveyCard('✓ Berücksichtigen, wenn ich mitesse', 'Bei getrennten Gerichten verändert deine Abneigung nicht automatisch die Auswahl anderer Personen. Der Abgleich erfolgt anhand der Zutaten- und Rezeptnamen.', color: AppColors.softGreen), gap(18),
    surveyCard('Rezeptausblendungen bleiben separat.', 'Ein ausgeblendetes Rezept bleibt ausgeblendet, bis du es unter „Ausgeblendete Rezepte“ ausdrücklich freigibst.', color: AppColors.cream),
  ];
  void saveDislike() {
    final value = dislikeName.trim();
    if (value.isEmpty) { update(() => ruleError = 'Bitte eine Zutat eingeben.'); return; }
    update(() {
      personalDislikes.removeWhere((d) => d.toLowerCase() == (originalDislike ?? value).toLowerCase());
      if (dislikeActive) personalDislikes.add(value);
      householdPage = 7;
    }); savePreferences();
  }

  Future<void> addHouseholdRule() async {
    final kind = await showModalBottomSheet<int>(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: const Text('Gemeinsamer fester Ausschluss'), onTap: () => Navigator.pop(context, 0)),
      ListTile(title: const Text('Meine Allergie / Unverträglichkeit'), onTap: () => Navigator.pop(context, 1)),
      ListTile(title: const Text('Persönliche Abneigung'), onTap: () => Navigator.pop(context, 2)),
    ])));
    if (kind == null || !mounted) return;
    if (kind == 2) { openDislikeEditor(); } else { openRuleEditor(personal: kind == 1); }
  }

  Widget rulesActionBar() {
    if (householdPage == 9) return const SizedBox.shrink();
    final label = householdPage == 7 ? 'Regel hinzufügen +' : householdPage == 8 ? 'Änderung am Ausschluss speichern' : 'Persönliche Vorliebe speichern';
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Padding(padding: const EdgeInsets.fromLTRB(22, 12, 22, 12), child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () { if (householdPage == 7) { addHouseholdRule(); } else if (householdPage == 8) { saveFixedRule(); } else { saveDislike(); } }, style: FilledButton.styleFrom(minimumSize: const Size(0, 56)), child: Text(label, textAlign: TextAlign.center))), gap(8),
      Text(householdPage == 10 ? 'Ändert keine Allergie und keinen festen Ausschluss.' : 'Persönliche Gesundheitsregeln bleiben bei der jeweiligen Person.', textAlign: TextAlign.center, style: muted.copyWith(fontSize: 12)),
    ]))));
  }
}
