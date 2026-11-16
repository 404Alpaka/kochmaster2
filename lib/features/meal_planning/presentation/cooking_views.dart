part of 'planning_page.dart';

class _CookingTimer {
  _CookingTimer(this.seconds) : pausedSeconds = seconds;
  int seconds;
  int pausedSeconds;
  DateTime? deadline;
  bool started = false;
  bool announced = false;
  int get remaining => deadline == null ? pausedSeconds : ((deadline!.difference(DateTime.now()).inMilliseconds / 1000).ceil()).clamp(0, 86400).toInt();
  bool get running => deadline != null && remaining > 0;
  void toggle() {
    if (running) { pausedSeconds = remaining; deadline = null; }
    else { if (remaining == 0) pausedSeconds = seconds; deadline = DateTime.now().add(Duration(seconds: pausedSeconds)); started = true; announced = false; }
  }
  void addMinute() {
    if (deadline != null) { deadline = DateTime.now().add(Duration(seconds: remaining + 60)); }
    else { pausedSeconds += 60; }
    seconds += 60; announced = false;
  }
}
class _CookingUse {
  _CookingUse(this.item, this.used, this.unit);
  final Map<String, dynamic> item;
  double used;
  final String unit;
}

extension _CookingViews on _PlanningPageState {
  List<Widget> cookingFlow() => cookingRecipe == null ? [] : switch (cookingPage) {
    2 => cookingStepView(), 3 => cookingFinishedView(), _ => cookingOverview(),
  };
  String timerLabel(int seconds) => '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  List<IngredientAmount> get cookingIngredients => buildShoppingList([PlannedMeal(cookingRecipe!, cookingPortions)]);

  Future<void> openCooking(Recipe recipe, {required int portions, int? day}) async {
    final date = day == null ? pantryToday : week.add(Duration(days: day));
    final key = '${dateKey(date)}:${recipe.id}';
    if (cookingRecipe != null && cookingKey == key && !cookedEntries.contains(key)) { update(() => cookingPage = 1); return; }
    if (cookingRecipe != null && !cookedEntries.contains(cookingKey)) {
      final change = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Kochvorgang wechseln?'), content: const Text('Der bisherige Kochfortschritt und seine Timer werden beendet. Vorräte bleiben unverändert.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Wechseln'))]));
      if (change != true || !mounted) return;
    }
    cookingTicker?.cancel();
    update(() {
      cookingRecipe = recipe; cookingPortions = portions; cookingDay = day; cookingDate = date; cookingKey = key;
      cookingPage = 1; cookingStep = 0; cookingTimers.clear(); cookingUses.clear();
      remainingCookedPortions = (portions - servings).clamp(0, portions).toInt(); cookedOn = pantryToday; cookedStorage = 'Kühlschrank';
    });
    cookingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final ended = <int>[];
      for (final entry in cookingTimers.entries) {
        if (entry.value.started && entry.value.deadline != null && entry.value.remaining == 0 && !entry.value.announced) { entry.value.announced = true; ended.add(entry.key); }
      }
      if (cookingTimers.values.any((t) => t.running) || ended.isNotEmpty) update(() {});
      if (ended.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Timer beendet: Schritt ${ended.map((i) => i + 1).join(', ')}.')));
    });
  }

  Widget cookingPortionControl() => Row(children: [
    IconButton(tooltip: 'Weniger Kochportionen', onPressed: cookingPortions <= 1 ? null : () => update(() => cookingPortions--), icon: const Icon(Icons.remove)),
    Expanded(child: Text('$cookingPortions Portionen', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
    IconButton(tooltip: 'Mehr Kochportionen', onPressed: cookingPortions >= 30 ? null : () => update(() => cookingPortions++), icon: const Icon(Icons.add)),
  ]);
  List<Widget> cookingOverview() => [
    proposalBack(cookingDay == null ? 'Zurück zum Rezept' : 'Zurück zum Wochenplan', () => update(() => cookingPage = 0)), gap(14), title('Zeit zu kochen.'), gap(12),
    Text('${cookingDay == null ? 'Heute' : _PlanningPageState.days[cookingDay!]} · ${displayDate(cookingDate!)}${cookingDay == null ? '' : ' · aus deinem Plan'}', style: muted), gap(18),
    surveyCard(cookingRecipe!.name, mealDescription(cookingRecipe!, cookingPortions)), gap(18),
    if (cookedEntries.contains(cookingKey)) ...[surveyCard('✓ Bereits als gekocht gespeichert', 'Dieser Kochvorgang wurde abgeschlossen. Vorräte und Reste werden kein zweites Mal gebucht.', color: AppColors.softGreen), gap(18)]
    else ...[
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Heute mehr kochen, morgen weniger tun.', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), gap(10),
        cookingPortionControl(), gap(10), Text('Die Zutaten werden für $cookingPortions Portionen berechnet. Übrige Portionen legst du nach dem Kochen fest.', style: muted),
      ]), color: AppColors.softGreen), gap(18),
    ],
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      section('Das brauchst du'),
      for (final i in cookingIngredients) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${amountLabel(i.quantity, i.unit)} ${i.name}')),
    ]), padding: const EdgeInsets.all(16)), gap(18),
    for (var i = 0; i < cookingRecipe!.steps.length; i++) TextButton(style: TextButton.styleFrom(alignment: Alignment.centerLeft), onPressed: cookedEntries.contains(cookingKey) ? null : () => update(() { cookingStep = i; cookingPage = 2; }), child: Text('${i + 1}  ${cookingRecipe!.steps[i]}')),
    if (cookingRecipe!.steps.isEmpty) Text('Für dieses Gericht sind noch keine Zubereitungsschritte hinterlegt.', style: muted), gap(14),
    Text('Rezepttexte bleiben unverändert. Mengenangaben innerhalb eines Kochschritts beziehen sich gegebenenfalls auf die Originalportionen; maßgeblich ist deine skalierte Zutatenliste.', style: muted),
    if (cookingTimers.isNotEmpty) ...[gap(14), ...cookingTimerCards()],
  ];

  _CookingTimer stepTimer(int index) => cookingTimers.putIfAbsent(index, () {
    final match = RegExp(r'(\d+)\s*(?:Minuten|Min\.|Min\b)', caseSensitive: false).firstMatch(cookingRecipe!.steps[index]);
    return _CookingTimer(((int.tryParse(match?.group(1) ?? '') ?? 5).clamp(1, 180).toInt()) * 60);
  });
  List<Widget> cookingTimerCards() => [for (final entry in cookingTimers.entries) ...[cookingTimerCard(entry.key, entry.value), gap(14)]];
  Widget cookingTimerCard(int index, _CookingTimer timer) {
    final dark = timer.running;
    final color = dark ? Colors.white : AppColors.lightText;
    return panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('SCHRITT ${index + 1} · ${timer.running ? 'TIMER LÄUFT' : timer.started && timer.remaining == 0 ? 'TIMER BEENDET' : timer.started ? 'PAUSIERT' : 'TIMER BEREIT'}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)), gap(10),
      Text(timerLabel(timer.remaining), style: TextStyle(fontSize: 48, fontWeight: FontWeight.w600, color: color)), gap(8),
      Text('Dauer selbst prüfen und bei Bedarf anpassen.', style: TextStyle(fontSize: 13, color: color)), gap(12),
      Row(children: [Expanded(child: recipeAction(timer.running ? 'Pause' : timer.started && timer.remaining > 0 ? 'Fortsetzen' : 'Starten', false, () => update(timer.toggle))), const SizedBox(width: 10), Expanded(child: recipeAction('+ 1 Min.', false, () => update(timer.addMinute)))]),
      TextButton(onPressed: () => update(() { timer.deadline = null; timer.pausedSeconds = timer.seconds; timer.started = false; timer.announced = false; }), child: Text('Zurücksetzen', style: TextStyle(color: color))),
    ]), color: dark ? AppColors.sage : AppColors.softGreen, padding: const EdgeInsets.all(20));
  }

  List<Widget> cookingStepView() {
    final steps = cookingRecipe!.steps;
    if (steps.isEmpty) return cookingOverview();
    final timer = stepTimer(cookingStep);
    return [
      proposalBack('Kochübersicht', () => update(() => cookingPage = 1)), gap(16),
      Row(children: [for (var i = 0; i < steps.length; i++) Expanded(child: Container(height: 5, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: i <= cookingStep ? AppColors.sage : AppColors.softGreen, borderRadius: BorderRadius.circular(2))))]), gap(18),
      Text('SCHRITT ${cookingStep + 1} VON ${steps.length}', style: const TextStyle(color: AppColors.sage, fontSize: 13, fontWeight: FontWeight.w600)), gap(18),
      title(steps[cookingStep].length <= 65 ? steps[cookingStep] : 'Schritt ${cookingStep + 1}'), gap(14),
      if (steps[cookingStep].length > 65) ...[Text(steps[cookingStep], style: const TextStyle(fontSize: 18, height: 1.5)), gap(18)],
      cookingTimerCard(cookingStep, timer), gap(18),
      if (cookingTimers.entries.any((e) => e.key != cookingStep && e.value.started)) ...[
        section('Andere Timer im Blick'),
        for (final e in cookingTimers.entries.where((e) => e.key != cookingStep && e.value.started)) ListTile(title: Text('Schritt ${e.key + 1} · ${timerLabel(e.value.remaining)}'), trailing: const Icon(Icons.chevron_right), onTap: () => update(() => cookingStep = e.key)), gap(14),
      ],
      if (cookingStep > 0) TextButton(onPressed: () => update(() => cookingStep--), child: const Text('Vorheriger Schritt')),
      surveyCard('Zutaten für $cookingPortions Portionen', cookingIngredients.map((i) => '${amountLabel(i.quantity, i.unit)} ${i.name}').join('\n')),
      gap(14), Text('Timer laufen beim Schrittwechsel weiter. Hinweise erscheinen nur in der geöffneten App; beim Neuladen endet der Kochmodus.', style: muted),
    ];
  }

  void prepareCookingReview() {
    cookingUses.clear();
    for (final ingredient in cookingIngredients) {
      var needed = ingredient.quantity;
      for (final item in pantry) {
        final parsed = pantryAmount(item);
        if (parsed == null || pantryName(item['name'] as String) != pantryName(ingredient.name) || parsed.$2.toLowerCase() != ingredient.unit.toLowerCase() || needed <= 0) continue;
        _CookingUse? previous;
        for (final use in cookingUses) { if (identical(use.item, item)) previous = use; }
        final available = parsed.$1 - (previous?.used ?? 0);
        final used = needed < available ? needed : available;
        if (used > 0) {
          if (previous == null) { cookingUses.add(_CookingUse(item, used, parsed.$2)); } else { previous.used += used; }
          needed -= used;
        }
      }
    }
    update(() { deductCookingStock = true; remainingCookedPortions = (cookingPortions - servings).clamp(0, cookingPortions).toInt(); cookedOn = pantryToday; cookingPage = 3; });
  }

  Future<void> editCookingUse(_CookingUse use) async {
    var value = amountLabel(use.used, '').trim();
    final form = GlobalKey<FormState>();
    final result = await showDialog<double>(context: context, builder: (context) => AlertDialog(title: Text('${use.item['name']} · Verbrauch'),
      content: Form(key: form, child: TextFormField(initialValue: value, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Verbraucht in ${use.unit}'), onChanged: (v) => value = v,
        validator: (v) { final n = double.tryParse((v ?? '').replaceAll(',', '.')); final available = pantryAmount(use.item)?.$1 ?? 0; return n == null || !n.isFinite || n < 0 || n > available ? 'Bitte 0 bis $available eingeben.' : null; })),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')), TextButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(context, double.parse(value.replaceAll(',', '.'))); }, child: const Text('Übernehmen'))]));
    if (result != null && mounted) update(() => use.used = result);
  }

  List<Widget> cookingFinishedView() => [
    proposalBack('Zurück zur Kochübersicht', () => update(() => cookingPage = 1)), gap(14),
    const Text('✓ Kochschritte abgeschlossen', style: TextStyle(color: AppColors.sage, fontWeight: FontWeight.w600)), gap(12), title('Gekocht. Gut genutzt.'), gap(12), Text('${cookingRecipe!.name} · $cookingPortions Portionen'), gap(18),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Verbrauchte Mengen übernehmen'), subtitle: const Text('Vorschläge prüfen und bei Bedarf anpassen.'), value: deductCookingStock, onChanged: (v) => update(() => deductCookingStock = v ?? false)),
      if (cookingUses.isEmpty) Text('Keine vorhandenen Vorräte eindeutig nach Name und Einheit zugeordnet. Es werden keine Mengen abgezogen.', style: muted),
      for (final use in cookingUses) ...[
        Text(use.item['name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        TextButton(onPressed: () => editCookingUse(use), child: Text('${amountLabel(use.used, use.unit)} verbraucht · Ändern')),
        Text('${use.item['amount']} → ${amountLabel(((pantryAmount(use.item)?.$1 ?? 0) - (deductCookingStock ? use.used : 0)).clamp(0, double.infinity).toDouble(), use.unit)}', style: muted), gap(12),
      ],
      Text('Nur vorhandene Mengen mit gleicher Einheit werden vorgeschlagen. Fehlende Zutaten oder andere Einheiten werden nicht automatisch abgezogen.', style: muted),
    ]), padding: const EdgeInsets.all(16)), gap(18),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section('Übrige Portionen aufheben'),
      Row(children: [IconButton(onPressed: remainingCookedPortions > 0 ? () => update(() => remainingCookedPortions--) : null, icon: const Icon(Icons.remove)), Expanded(child: Text('$remainingCookedPortions Portionen', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))), IconButton(onPressed: remainingCookedPortions < cookingPortions ? () => update(() => remainingCookedPortions++) : null, icon: const Icon(Icons.add))]), gap(12),
      DropdownButtonFormField<String>(initialValue: cookedStorage, decoration: const InputDecoration(labelText: 'Aufbewahrung'), items: [for (final place in ['Kühlschrank', 'Gefrierfach']) DropdownMenuItem(value: place, child: Text(place))], onChanged: (v) { if (v != null) update(() => cookedStorage = v); }), gap(12),
      TextButton.icon(icon: const Icon(Icons.event_outlined), label: Text('Gekocht am: ${displayDate(cookedOn ?? pantryToday)}'), onPressed: () async {
        final date = await showDatePicker(context: context, initialDate: cookedOn ?? pantryToday, firstDate: DateTime(2000), lastDate: pantryToday);
        if (date != null && mounted) update(() => cookedOn = date);
      }),
    ]), padding: const EdgeInsets.all(16)), gap(14),
    Text('Vorrat, Kochstatus und übrige Portionen werden lokal gespeichert. Sie werden erst beim Speichern verändert.', style: muted),
  ];

  void saveCookingResult() {
    if (cookedEntries.contains(cookingKey)) return;
    if (deductCookingStock && cookingUses.any((use) => !pantry.contains(use.item) || pantryAmount(use.item)?.$2.toLowerCase() != use.unit.toLowerCase() || use.used > (pantryAmount(use.item)?.$1 ?? 0))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dein Vorrat hat sich geändert. Bitte prüfe die Verbrauchsmengen erneut.'))); return;
    }
    update(() {
      if (deductCookingStock) for (final use in cookingUses) {
        final remaining = pantryAmount(use.item)!.$1 - use.used;
        if (remaining <= 0) { pantry.remove(use.item); } else { use.item['amount'] = amountLabel(remaining, use.unit); }
      }
      if (remainingCookedPortions > 0) preparedMeals.add({
        'id': 'cooked-${DateTime.now().microsecondsSinceEpoch}', 'name': cookingRecipe!.name, 'portions': remainingCookedPortions,
        'location': cookedStorage, 'storedOn': dateKey(pantryToday), 'cookedOn': dateKey(cookedOn ?? pantryToday), 'recipe': recipeSnapshot(cookingRecipe!),
      });
      cookingHistory.add({'key': cookingKey, 'date': dateKey(cookedOn ?? pantryToday), 'recipeId': cookingRecipe!.id, 'name': cookingRecipe!.name, 'portions': cookingPortions, 'savedLeftovers': remainingCookedPortions});
      cookedEntries.add(cookingKey); cookingPage = 0;
    });
    cookingTicker?.cancel(); cookingTimers.clear(); savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Als gekocht gespeichert · $remainingCookedPortions Portionen aufgehoben.')));
  }

  Widget cookingActionBar() {
    final alreadyCooked = cookedEntries.contains(cookingKey);
    final label = cookingPage == 1 ? 'Kochen starten' : cookingPage == 3 ? 'Vorrat & $remainingCookedPortions Portionen speichern' : cookingStep + 1 < cookingRecipe!.steps.length ? 'Weiter: Schritt ${cookingStep + 2}' : 'Gekocht markieren ✓';
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Padding(padding: const EdgeInsets.fromLTRB(22, 12, 22, 12), child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: double.infinity, child: FilledButton(onPressed: alreadyCooked || (cookingPage == 1 && cookingRecipe!.steps.isEmpty) ? null : () {
        if (cookingPage == 1) { update(() { cookingStep = 0; cookingPage = 2; }); }
        else if (cookingPage == 3) { saveCookingResult(); }
        else if (cookingStep + 1 < cookingRecipe!.steps.length) { update(() => cookingStep++); }
        else { prepareCookingReview(); }
      }, style: FilledButton.styleFrom(minimumSize: const Size(0, 56)), child: Text(alreadyCooked ? 'Bereits gekocht ✓' : label, textAlign: TextAlign.center))), gap(8),
      Text(cookingPage == 3 ? 'Erst jetzt werden Vorräte und Reste aktualisiert.' : 'Zutaten für $cookingPortions Portionen · Timer laufen beim Schrittwechsel weiter.', textAlign: TextAlign.center, style: muted.copyWith(fontSize: 12)),
    ]))));
  }
}
