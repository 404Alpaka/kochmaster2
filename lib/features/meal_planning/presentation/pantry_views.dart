part of 'planning_page.dart';

extension _PantryViews on _PlanningPageState {
  List<Widget> pantryFlow() => switch (pantryPage) {
    1 => receiptView(),
    2 => leftoversView(),
    3 => preparedMealsView(),
    4 => preparedStorageView(),
    5 => preparedReplanView(),
    _ => pantryView(),
  };

  (double, String)? pantryAmount(Map<String, dynamic> item) {
    final match = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*(.*?)\s*$').firstMatch(item['amount'] as String? ?? '');
    if (match == null) return null;
    return (double.parse(match.group(1)!.replaceAll(',', '.')), match.group(2)!);
  }

  String amountLabel(double value, String unit) => '${value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ',')} $unit'.trim();
  DateTime get pantryToday { final now = DateTime.now(); return DateTime(now.year, now.month, now.day); }
  int? daysUntilDue(Map<String, dynamic> item) {
    final date = DateTime.tryParse(item['expires'] as String? ?? '');
    return date == null ? null : DateTime(date.year, date.month, date.day).difference(pantryToday).inDays;
  }
  String dueLabel(Map<String, dynamic> item) {
    final days = daysUntilDue(item);
    if (days == null) return 'Haltbarkeit ergänzen';
    if (days < 0) return 'Datum seit ${-days} ${days == -1 ? 'Tag' : 'Tagen'} überschritten';
    if (days == 0) return 'Heute prüfen';
    if (days <= 2) return 'Noch $days ${days == 1 ? 'Tag' : 'Tage'}';
    return 'Bis ${displayDate(DateTime.parse(item['expires'] as String))}';
  }
  List<Map<String, dynamic>> get urgentPantry => pantry.where((p) => daysUntilDue(p) != null && daysUntilDue(p)! <= 2).toList()
    ..sort((a, b) => daysUntilDue(a)!.compareTo(daysUntilDue(b)!));

  Widget captureTile(String label, String subtitle, IconData icon, VoidCallback action) => Expanded(child: InkWell(
    onTap: action, borderRadius: BorderRadius.circular(17),
    child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(17)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Colors.white, size: 24), gap(12), Text(label, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
      gap(10), Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFFD3DFC8))),
    ])),
  ));

  List<Widget> pantryView() => [
    title('Dein Vorrat'), gap(8), Text('Weniger wegwerfen. Mehr draus machen.', style: muted), gap(16),
    Row(children: [captureTile('Kassenbon', 'Demo-Bon prüfen', Icons.receipt_long_outlined, startReceiptDemo), const SizedBox(width: 12), captureTile('Barcode', 'Produkt erfassen', Icons.qr_code_scanner, barcodeInfo)]),
    TextButton.icon(onPressed: addPantryItem, icon: const Icon(Icons.add, size: 18), label: const Text('Lebensmittel erfassen')), gap(8),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(urgentPantry.isEmpty ? 'Dein Vorrat kocht mit' : '${urgentPantry.length} Lebensmittel brauchen dich', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF84531E))), gap(6),
      Text(urgentPantry.isEmpty ? 'Entdecke passende Rezepte mit deinen vorhandenen Zutaten.' : '${urgentPantry.take(3).map((p) => p['name']).join(', ')}: Prüfe die eingetragenen Haltbarkeitsdaten.', style: muted),
      TextButton(onPressed: () => update(() { pantryPage = 2; leftoverRecipeIndex = 0; }), child: const Text('Resterezepte entdecken →')),
    ]), color: const Color(0xFFF6E9CF), padding: const EdgeInsets.all(16)), gap(16),
    Wrap(spacing: 6, runSpacing: 6, children: [
      for (final label in ['Alle', 'Kühlschrank', 'Trocken']) ChoiceChip(
        label: Text('$label ${pantry.where((p) => label == 'Alle' || p['location'] == label).length}', style: const TextStyle(fontSize: 12)),
        selected: pantryFilter == label, showCheckmark: false,
        selectedColor: AppColors.softGreen, side: BorderSide.none,
        onSelected: (_) => update(() => pantryFilter = label),
      ),
    ]), gap(16),
    panel(Column(children: [
      if (!pantry.any((p) => pantryFilter == 'Alle' || p['location'] == pantryFilter)) Text('Hier ist noch Platz. Erfasse deine ersten Lebensmittel oder prüfe den Demo-Bon.', style: muted),
      for (final item in pantry.where((p) => pantryFilter == 'Alle' || p['location'] == pantryFilter)) ...[
        Row(children: [
          Expanded(child: TextButton(style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero), onPressed: () => editPantryProduct(item: item), child: Text(item['name'] as String, style: const TextStyle(fontSize: 15, color: AppColors.lightText)))),
          IconButton.filledTonal(tooltip: 'Menge verringern', onPressed: () => adjustPantryAmount(item, -1), icon: const Icon(Icons.remove, size: 18)),
          const SizedBox(width: 4), IconButton.filledTonal(tooltip: 'Menge erhöhen', onPressed: () => adjustPantryAmount(item, 1), icon: const Icon(Icons.add, size: 18)),
        ]),
        Align(alignment: Alignment.centerLeft, child: Text('${item['amount']} · ${item['location']}', style: muted)),
        Align(alignment: Alignment.centerLeft, child: TextButton(style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft), onPressed: () => editPantryProduct(item: item), child: Text(dueLabel(item), style: TextStyle(fontSize: 12, color: daysUntilDue(item) != null && daysUntilDue(item)! <= 2 ? AppColors.terracotta : AppColors.muted)))),
        gap(12),
      ],
    ]), padding: const EdgeInsets.all(16)), gap(16),
    recipeAction('Fertige Mahlzeiten & Portionen →', false, openPreparedMeals), gap(16),
    surveyCard('Auch Gekochtes zählt', 'Übrige Portionen aus dem Kochmodus werden hier mit Lagerort und Kochdatum angezeigt. Eine erweiterte Verwaltung folgt im nächsten Bereich.', color: AppColors.softGreen), gap(14),
    Text('Vorräte werden lokal gespeichert. Haltbarkeitsdaten sind deine Angaben; es gibt noch keine gemeinsame Haushaltssynchronisierung.', style: muted),
  ];

  Future<void> editPantryProduct({Map<String, dynamic>? item, bool receipt = false}) async {
    var name = item?['name'] as String? ?? '';
    var amount = item?['amount'] as String? ?? '';
    var location = item?['location'] as String? ?? 'Kühlschrank';
    var expires = item?['expires'] as String?;
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(item == null ? 'Lebensmittel erfassen' : 'Lebensmittel bearbeiten'),
      content: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(initialValue: name, decoration: const InputDecoration(labelText: 'Lebensmittel'), validator: (v) => v == null || v.trim().isEmpty ? 'Bitte ein Lebensmittel eingeben.' : null, onChanged: (v) => name = v), gap(12),
        TextFormField(initialValue: amount, decoration: const InputDecoration(labelText: 'Menge, z. B. 500 g'), validator: (v) => v == null || v.trim().isEmpty ? 'Bitte eine Menge eingeben.' : null, onChanged: (v) => amount = v), gap(12),
        DropdownButtonFormField<String>(initialValue: location, decoration: const InputDecoration(labelText: 'Lagerort'), items: const [DropdownMenuItem(value: 'Kühlschrank', child: Text('Kühlschrank')), DropdownMenuItem(value: 'Trocken', child: Text('Trocken'))], onChanged: (v) => location = v ?? location), gap(12),
        TextButton.icon(icon: const Icon(Icons.event_outlined), label: Text(expires == null ? 'Haltbarkeitsdatum ergänzen' : 'Bis ${displayDate(DateTime.parse(expires!))}'), onPressed: () async {
          final date = await showDatePicker(context: context, initialDate: DateTime.tryParse(expires ?? '') ?? pantryToday, firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (date != null && context.mounted) setDialogState(() => expires = dateKey(date));
        }),
        if (expires != null) TextButton(onPressed: () => setDialogState(() => expires = null), child: const Text('Datum entfernen')),
      ]))),
      actions: [
        if (item != null) TextButton(onPressed: () => Navigator.pop(context, 'delete'), child: const Text('Entfernen')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(context, 'save'); }, child: Text(item == null ? 'Hinzufügen' : 'Speichern')),
      ],
    )));
    if (!mounted || result == null) return;
    update(() {
      if (result == 'delete') { (receipt ? receiptDraft : pantry).remove(item); return; }
      final target = item ?? <String, dynamic>{};
      target.addAll({'name': name.trim(), 'amount': amount.trim(), 'location': location, 'expires': expires});
      if (item == null) pantry.add(target);
    });
    if (!receipt) savePreferences();
  }

  void adjustPantryAmount(Map<String, dynamic> item, int direction) {
    final parsed = pantryAmount(item);
    if (parsed == null) { editPantryProduct(item: item); return; }
    final step = ['g', 'ml'].contains(parsed.$2.toLowerCase()) ? 50.0 : ['kg', 'l'].contains(parsed.$2.toLowerCase()) ? 0.1 : 1.0;
    final next = parsed.$1 + step * direction;
    if (next <= 0) {
      final index = pantry.indexOf(item);
      update(() => pantry.remove(item)); savePreferences();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item['name']} entfernt.'), action: SnackBarAction(label: 'Rückgängig', onPressed: () { update(() => pantry.insert(index.clamp(0, pantry.length).toInt(), item)); savePreferences(); })));
    } else { update(() => item['amount'] = amountLabel(next, parsed.$2)); savePreferences(); }
  }

  void startReceiptDemo() => update(() {
    pantryPage = 1; receiptResolved = false; showAllReceiptItems = false;
    receiptDraft = [
      {'name': 'Basmatireis', 'amount': '500 g', 'location': 'Trocken'},
      {'name': 'Kichererbsen', 'amount': '2 Dosen', 'location': 'Trocken'},
      {'name': 'Joghurt, laktosefrei', 'amount': '500 g', 'location': 'Kühlschrank', 'expires': dateKey(pantryToday)},
      {'name': 'Zucchini', 'amount': '2 Stück', 'location': 'Kühlschrank', 'expires': dateKey(pantryToday.add(const Duration(days: 2)))},
      {'name': 'Babyspinat', 'amount': '100 g', 'location': 'Kühlschrank', 'expires': dateKey(pantryToday.add(const Duration(days: 1)))},
      {'name': 'Haferflocken', 'amount': '500 g', 'location': 'Trocken'},
      {'name': 'Cherrytomaten', 'amount': '250 g', 'location': 'Kühlschrank', 'uncertain': true},
    ];
  });

  List<Widget> receiptView() => [
    proposalBack('Zurück zum Vorrat', () => update(() => pantryPage = 0)), gap(14), title('Einkauf erkannt.'), gap(8),
    Text('Demo-Bon · Einmal prüfen. Dann ist dein Vorrat aktuell.', style: muted), gap(18),
    surveyCard('✓ ${receiptDraft.where((p) => p['uncertain'] != true).length} Positionen erkannt', 'Beispieldaten, keine Fotoerkennung. Mengen, Lagerorte und Haltbarkeit kannst du vor dem Übernehmen ändern.', color: AppColors.softGreen), gap(18),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      costRow('Marktgrün · Demo', 'Heute'), gap(14),
      for (final item in (showAllReceiptItems ? receiptDraft : receiptDraft.take(4))) ...[
        costRow(item['name'] as String, item['amount'] as String),
        TextButton(onPressed: () => editPantryProduct(item: item, receipt: true), child: Text('${item['location']} · Ändern')), gap(8),
      ],
      if (receiptDraft.length > 4) TextButton(onPressed: () => update(() => showAllReceiptItems = !showAllReceiptItems), child: Text(showAllReceiptItems ? 'Weniger anzeigen ↑' : '${receiptDraft.length - 4} weitere Produkte anzeigen ↓')),
    ]), padding: const EdgeInsets.all(16)), gap(18),
    if (receiptDraft.any((p) => p['uncertain'] == true)) panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Eine Position braucht dich', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), gap(8),
      Text('„BIO TOM. 250“ · Als ${receiptDraft.firstWhere((p) => p['uncertain'] == true)['name']} übernehmen?', style: muted),
      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Zuordnung bestätigen'), value: receiptResolved, onChanged: (v) => update(() => receiptResolved = v ?? false)),
      TextButton(onPressed: () => editPantryProduct(item: receiptDraft.firstWhere((p) => p['uncertain'] == true), receipt: true), child: const Text('Zuordnung ändern →')),
      TextButton(onPressed: () => update(() => receiptDraft.removeWhere((p) => p['uncertain'] == true)), child: const Text('Position weglassen')),
    ]), color: const Color(0xFFF6E9CF), padding: const EdgeInsets.all(16)), gap(18),
    surveyCard('Vorhandenes wird ergänzt, nicht ersetzt.', 'Gleiche Namen, Einheiten, Lagerorte und Haltbarkeitsdaten werden zusammengeführt. Unterschiedliche Chargen bleiben getrennt.'),
  ];

  void importReceipt() {
    if (receiptDraft.isEmpty || (!receiptResolved && receiptDraft.any((p) => p['uncertain'] == true))) return;
    final count = receiptDraft.length;
    update(() {
      for (final raw in receiptDraft) {
        final item = Map<String, dynamic>.from(raw)..remove('uncertain');
        final amount = pantryAmount(item);
        Map<String, dynamic>? existing;
        for (final p in pantry) {
          final old = pantryAmount(p);
          if ((p['name'] as String).toLowerCase() == (item['name'] as String).toLowerCase() && p['location'] == item['location'] && p['expires'] == item['expires'] && amount != null && old != null && old.$2.toLowerCase() == amount.$2.toLowerCase()) { existing = p; break; }
        }
        if (existing == null) { pantry.add(item); }
        else { existing['amount'] = amountLabel(pantryAmount(existing)!.$1 + amount!.$1, amount!.$2); }
      }
      receiptDraft = []; pantryPage = 0; pantryFilter = 'Alle';
    });
    savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count Demo-Produkte zum Vorrat hinzugefügt.')));
  }

  void barcodeInfo() => showDialog<void>(context: context, builder: (context) => AlertDialog(
    title: const Text('Barcode erfassen'), content: const Text('Kamera und Produktdatenbank sind noch nicht angebunden. Erfasse das Produkt vorerst manuell.'),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen')), TextButton(onPressed: () { Navigator.pop(context); addPantryItem(); }, child: const Text('Manuell erfassen'))],
  ));

  String pantryName(String name) => name.toLowerCase().replaceAll('babyspinat', 'spinat').replaceAll('basmatireis', 'reis').trim();
  int pantryMatches(Recipe recipe) => recipe.ingredients.where((i) => pantry.any((p) => pantryName(p['name'] as String) == pantryName(i.name))).length;
  List<Recipe> get leftoverRecipes {
    final matches = eligibleRecipes.where((r) => pantryMatches(r) > 0).toList();
    matches.sort((a, b) => pantryMatches(b).compareTo(pantryMatches(a)));
    return matches;
  }
  Recipe? get selectedLeftover => leftoverRecipes.isEmpty ? null : leftoverRecipes[leftoverRecipeIndex % leftoverRecipes.length];

  List<Widget> leftoversView() {
    final recipe = selectedLeftover;
    return [
      proposalBack('Zurück zum Vorrat', () => update(() => pantryPage = 0)), gap(14), title('Gutes bleibt nicht übrig.'), gap(8),
      Text('Aus deinem Vorrat. Für heute Abend.', style: muted), gap(18),
      if (urgentPantry.isNotEmpty) ...[
        panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Diese ${urgentPantry.length} haben Vorrang', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), gap(10),
          for (final p in urgentPantry.take(5)) ...[costRow('${p['name']} · ${p['amount']}', dueLabel(p)), gap(8)],
        ]), color: const Color(0xFFF6E9CF), padding: const EdgeInsets.all(16)), gap(18),
      ],
      costRow('Dein Vorrat kann das.', '$servings Personen'), gap(16),
      if (recipe == null) surveyCard('Noch kein passendes Resterezept', 'Erfasse Vorräte oder passe deine Planungsvorgaben an. Deine festen Ausschlüsse und die Kochzeit bleiben berücksichtigt.', color: AppColors.cream)
      else panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NUTZT ${pantryMatches(recipe)} DEINER ZUTATEN', style: const TextStyle(fontSize: 12, color: AppColors.sage, fontWeight: FontWeight.w600)), gap(12),
        title(recipe.name), gap(10), Text(mealDescription(recipe, servings), style: muted), gap(14),
        surveyCard('Dein Vorrat kocht mit.', 'Abgleich nach Zutatennamen. Bitte Mengen prüfen; Zusatzkosten sind ohne Preise noch nicht berechnet.', color: AppColors.softGreen), gap(14),
        const Text('So kommt dein Rest auf den Tisch', style: TextStyle(fontWeight: FontWeight.w600)), gap(12),
        for (var i = 0; i < recipe.steps.length; i++) ...[Text('${i + 1}  ${recipe.steps[i]}', style: muted), gap(8)],
        TextButton(onPressed: () { selectTab(0); details(recipe); }, child: const Text('Rezept ansehen →')),
      ]), padding: const EdgeInsets.all(18)), gap(18),
      surveyCard('Für morgen mitgedacht', 'Passe die Portionen beim Einplanen an deinen Bedarf an. Vorräte werden erst nach deiner eigenen Prüfung verändert.', color: AppColors.softGreen),
    ];
  }

  Widget pantryActionBar() {
    if (pantryPage >= 3) return preparedActionBar();
    final receipt = pantryPage == 1;
    final recipe = selectedLeftover;
    final enabled = receipt ? receiptDraft.isNotEmpty && (receiptResolved || !receiptDraft.any((p) => p['uncertain'] == true)) : recipe != null && !saving && !loading && loadError == null;
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Padding(padding: const EdgeInsets.fromLTRB(22, 12, 22, 12), child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: double.infinity, child: FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(0, 56)), onPressed: !enabled ? null : () { if (receipt) { importReceipt(); } else { addRecipe(recipe!, portions: servings); } }, icon: const Icon(Icons.add, size: 18), label: Text(receipt ? '${receiptDraft.length} Produkte zum Vorrat hinzufügen' : 'In deinen Wochenplan aufnehmen', textAlign: TextAlign.center))),
      if (receipt) ...[gap(8), Text('Demo-Bon · Erst prüfen, dann übernehmen.', textAlign: TextAlign.center, style: muted.copyWith(fontSize: 12))]
      else TextButton(onPressed: leftoverRecipes.length > 1 ? () => update(() => leftoverRecipeIndex++) : null, child: const Text('Andere Resterezepte entdecken →')),
    ]))));
  }
}
