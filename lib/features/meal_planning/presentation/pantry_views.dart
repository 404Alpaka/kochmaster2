part of 'planning_page.dart';

extension _PantryViews on _PlanningPageState {
  List<Widget> pantryFlow() => switch (pantryPage) {
    1 => receiptView(),
    2 => leftoversView(),
    3 => preparedMealsView(),
    4 => preparedStorageView(),
    5 => preparedReplanView(),
    6 => pantryRecipeSuggestionsView(),
    _ => pantryView(),
  };

  (double, String)? pantryAmount(Map<String, dynamic> item) {
    final match = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*(.*?)\s*$')
        .firstMatch(item['amount'] as String? ?? '');
    if (match == null) return null;
    return (
      double.parse(match.group(1)!.replaceAll(',', '.')),
      ['packung', 'packungen'].contains(match.group(2)!.toLowerCase())
          ? 'Packung'
          : match.group(2)!,
    );
  }

  String amountLabel(double value, String unit) =>
      '${value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ',')} ${unit == 'Packung' && value != 1 ? 'Packungen' : unit}'
          .trim();
  DateTime get pantryToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int? daysUntilDue(Map<String, dynamic> item) {
    final date = DateTime.tryParse(item['expires'] as String? ?? '');
    return date == null
        ? null
        : DateTime(
            date.year,
            date.month,
            date.day,
          ).difference(pantryToday).inDays;
  }

  String dueLabel(Map<String, dynamic> item) {
    final days = daysUntilDue(item);
    if (days == null) return 'Haltbarkeit ergänzen';
    if (days < 0) {
      return 'Datum seit ${-days} ${days == -1 ? 'Tag' : 'Tagen'} überschritten';
    }
    if (days == 0) return 'Heute prüfen';
    if (days <= 2) return 'Noch $days ${days == 1 ? 'Tag' : 'Tage'}';
    return 'Bis ${displayDate(DateTime.parse(item['expires'] as String))}';
  }

  List<Map<String, dynamic>> get urgentPantry =>
      pantry
          .where((p) => daysUntilDue(p) != null && daysUntilDue(p)! <= 2)
          .toList()
        ..sort((a, b) => daysUntilDue(a)!.compareTo(daysUntilDue(b)!));

  void showPantryCapture() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, icon, action)
                in <(String, IconData, VoidCallback)>[
                  (
                    'Kassenbon scannen',
                    Icons.receipt_long_outlined,
                    receiptCaptureInfo,
                  ),
                  (
                    'Bon importieren',
                    Icons.file_upload_outlined,
                    () => importReceiptFile(),
                  ),
                  ('Bontext einfügen', Icons.content_paste, pasteReceiptText),
                  ('Barcode scannen', Icons.qr_code_scanner, barcodeInfo),
                  ('Manuell hinzufügen', Icons.add, addPantryItem),
                  (
                    'Beispiel-Bon ausprobieren',
                    Icons.receipt_outlined,
                    startReceiptDemo,
                  ),
                  (
                    'Gekochte Mahlzeit erfassen',
                    Icons.restaurant_outlined,
                    () => editPreparedMeal(),
                  ),
                ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  Navigator.pop(context);
                  action();
                },
              ),
          ],
        ),
      ),
    ),
  );

  Widget emptyPantryIllustration() => Center(
    child: Container(
      width: 78,
      height: 128,
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        border: Border.all(color: AppColors.sage, width: 3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 41,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(left: 9),
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          Container(height: 3, color: AppColors.sage),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                margin: const EdgeInsets.only(left: 9, top: 13),
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  String pantryExpiryBadge(Map<String, dynamic> item) {
    final days = daysUntilDue(item);
    if (days == null) return 'Datum ergänzen';
    if (days < 0) return 'Datum prüfen';
    if (days == 0) return 'Heute';
    if (days == 1) return 'Morgen';
    return '$days Tage';
  }

  Widget pantryProductTile(
    Map<String, dynamic> item, {
    bool showLocation = false,
  }) {
    final urgent = daysUntilDue(item) != null && daysUntilDue(item)! <= 2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => editPantryProduct(item: item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] as String,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${item['amount']}${showLocation ? ' · ${item['location']}' : ''}',
                        style: muted.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: urgent
                        ? const Color(0xFFF6E7CD)
                        : AppColors.softGreen,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    pantryExpiryBadge(item),
                    style: TextStyle(
                      fontSize: 12,
                      color: urgent ? const Color(0xFF80501D) : AppColors.sage,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> pantryView() {
    final empty = pantry.isEmpty && preparedMeals.isEmpty;
    final visible = pantry
        .where(
          (item) => pantryFilter == 'Alle' || item['location'] == pantryFilter,
        )
        .toList();
    final urgent =
        visible
            .where(
              (item) => daysUntilDue(item) != null && daysUntilDue(item)! <= 2,
            )
            .toList()
          ..sort((a, b) => daysUntilDue(a)!.compareTo(daysUntilDue(b)!));
    final normal = visible.where((item) => !urgent.contains(item)).toList();
    Widget heading(String label, {bool urgent = false}) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: .4,
          color: urgent ? const Color(0xFF995007) : AppColors.muted,
        ),
      ),
    );
    return [
      title('Dein Vorrat'),
      gap(4),
      Text('Weniger wegwerfen. Mehr draus machen.', style: muted),
      gap(12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => update(() {
            pantrySuggestionPortions = servings;
            pantryPage = 6;
          }),
          icon: const Icon(Icons.restaurant_menu_outlined),
          label: const Text('Was kann ich kochen?'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
        ),
      ),
      if (empty) ...[
        gap(62),
        emptyPantryIllustration(),
        gap(30),
        const Text(
          'Dein Vorrat ist noch leer',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        gap(10),
        Text(
          'Erfasse deine Einkäufe und sieh, was bald abläuft.',
          textAlign: TextAlign.center,
          style: muted.copyWith(fontSize: 14),
        ),
        gap(30),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: receiptCaptureInfo,
            child: Text(
              'Kassenbon scannen',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        gap(12),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: const BorderSide(color: AppColors.sage),
            ),
            onPressed: barcodeInfo,
            child: const Text('Barcode scannen'),
          ),
        ),
        gap(12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => importReceiptFile(),
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Bon importieren · PDF oder Bild'),
          ),
        ),
        TextButton(
          onPressed: pasteReceiptText,
          child: const Text('Bontext einfügen'),
        ),
        gap(18),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 6,
          children: [
            TextButton(
              onPressed: addPantryItem,
              child: const Text('Manuell hinzufügen'),
            ),
            TextButton(
              onPressed: startReceiptDemo,
              child: const Text('Beispiel-Bon ausprobieren'),
            ),
          ],
        ),
      ] else ...[
        gap(16),
        if (urgentPantry.isNotEmpty) ...[
          Material(
            color: const Color(0xFFF6E7CD),
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => update(() {
                pantryPage = 2;
                leftoverRecipeIndex = 0;
              }),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${urgentPantry.length} ${urgentPantry.length == 1 ? 'Zutat läuft' : 'Zutaten laufen'} bald ab',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF75430E),
                      ),
                    ),
                    gap(3),
                    const Text(
                      'Passende Resterezepte entdecken →',
                      style: TextStyle(fontSize: 13, color: Color(0xFF75430E)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          gap(16),
        ],
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in ['Alle', 'Kühlschrank', 'Trocken', 'Gekocht'])
                SizedBox(
                  width:
                      (constraints.maxWidth - 24) *
                      (label == 'Alle'
                          ? .19
                          : label == 'Kühlschrank'
                          ? .31
                          : .25),
                  child: Material(
                    color: pantryFilter == label
                        ? AppColors.sage
                        : Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: BorderSide(
                        color: pantryFilter == label
                            ? AppColors.sage
                            : const Color(0xFFD8DED2),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => update(() => pantryFilter = label),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: pantryFilter == label
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${label == 'Alle'
                                  ? pantry.length + preparedMeals.length
                                  : label == 'Gekocht'
                                  ? preparedMeals.length
                                  : pantry.where((p) => p['location'] == label).length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: pantryFilter == label
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        gap(8),
        if (urgent.isNotEmpty) ...[
          heading('BALD ABLAUFEND', urgent: true),
          for (final item in urgent)
            pantryProductTile(item, showLocation: true),
        ],
        for (final location in ['Kühlschrank', 'Trocken'])
          if (normal.any((item) => item['location'] == location)) ...[
            heading(location.toUpperCase()),
            for (final item in normal.where(
              (item) => item['location'] == location,
            ))
              pantryProductTile(item),
          ],
        if (pantryFilter == 'Alle' || pantryFilter == 'Gekocht') ...[
          if (preparedMeals.isNotEmpty) heading('GEKOCHT'),
          for (final meal in preparedMeals) ...[
            Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                title: Text(
                  meal['name'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${meal['portions']} Portionen · ${meal['location']}',
                  style: muted,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: openPreparedMeals,
              ),
            ),
            gap(8),
          ],
        ],
        if (visible.isEmpty &&
            (pantryFilter != 'Alle' && pantryFilter != 'Gekocht' ||
                preparedMeals.isEmpty)) ...[
          gap(20),
          Text('Hier ist noch Platz. Füge neue Vorräte hinzu.', style: muted),
        ],
        gap(84),
      ],
    ];
  }

  List<PantryRecipeMatch> pantryRecipeMatches() {
    final result = const PantryRecipeMatcher().match(
      recipes: eligibleRecipes,
      pantry: pantry,
      portions: pantrySuggestionPortions,
    );
    return result.where((match) {
      if (pantrySuggestionFilter == 1 && !match.immediatelyCookable)
        return false;
      if (pantrySuggestionFilter == 2 && match.missingCount > 2) return false;
      if (pantrySuggestionMaxMinutes > 0 &&
          match.recipe.minutes > pantrySuggestionMaxMinutes)
        return false;
      return true;
    }).toList();
  }

  void addMissingIngredients(PantryRecipeMatch match) {
    final planItems = buildShoppingList(plan.values);
    for (final missing in match.matches.where(
      (m) => m.state != PantryIngredientState.full,
    )) {
      final requiredMissing = missing.missingQuantity;
      if (!requiredMissing.isFinite || requiredMissing <= 0) continue;

      var alreadyListed = 0.0;
      for (final item in [...planItems, ...pantryShoppingItems]) {
        if (item.ingredientId != missing.ingredient.ingredientId) continue;
        final converted = planningQuantity(item.quantity, item.unit);
        if (converted != null && converted.$2 == missing.unit)
          alreadyListed += converted.$1;
      }
      final toAdd = ((requiredMissing - alreadyListed).clamp(
        0,
        double.infinity,
      )).toDouble();
      if (toAdd <= 0) continue;

      final existingIndex = pantryShoppingItems.indexWhere((item) {
        if (item.ingredientId != missing.ingredient.ingredientId) return false;
        final converted = planningQuantity(item.quantity, item.unit);
        return converted != null && converted.$2 == missing.unit;
      });
      if (existingIndex >= 0) {
        final existing = pantryShoppingItems[existingIndex];
        pantryShoppingItems[existingIndex] = IngredientAmount(
          existing.ingredientId,
          existing.name,
          existing.quantity + toAdd,
          existing.unit,
        );
      } else {
        pantryShoppingItems.add(
          IngredientAmount(
            missing.ingredient.ingredientId,
            missing.ingredient.name,
            toAdd,
            missing.unit == 'piece' ? 'Stück' : missing.unit,
          ),
        );
      }
    }
    savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          match.missingCount == 0
              ? 'Dieses Rezept ist bereits vollständig.'
              : 'Fehlmengen wurden zum Korb hinzugefügt.',
        ),
      ),
    );
  }

  List<Widget> pantryRecipeSuggestionsView() {
    final matches = pantryRecipeMatches();
    return [
      proposalBack('Zurück zum Vorrat', () => update(() => pantryPage = 0)),
      gap(14),
      title('Was kann ich kochen?'),
      gap(8),
      Text(
        pantry.isEmpty
            ? 'Dein Vorrat ist leer.'
            : 'Vorschläge aus deinem Vorrat für ${pantrySuggestionPortions} Personen.',
        style: muted,
      ),
      if (pantry.isEmpty) ...[
        gap(18),
        surveyCard(
          'Noch keine Zutaten erfasst',
          'Füge Lebensmittel hinzu, um passende Rezepte zu berechnen.',
          color: AppColors.cream,
        ),
        gap(12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: addPantryItem,
            icon: const Icon(Icons.add),
            label: const Text('Lebensmittel hinzufügen'),
          ),
        ),
      ] else ...[
        gap(16),
        Row(
          children: [
            Expanded(
              child: Text(
                '$pantrySuggestionPortions Personen',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Weniger Portionen',
              onPressed: pantrySuggestionPortions > 1
                  ? () => update(() => pantrySuggestionPortions--)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              tooltip: 'Mehr Portionen',
              onPressed: pantrySuggestionPortions < 30
                  ? () => update(() => pantrySuggestionPortions++)
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        gap(10),
        Wrap(
          spacing: 6,
          runSpacing: 8,
          children: [
            for (final entry in const [
              (0, 'Alle Vorschläge'),
              (1, 'Sofort kochbar'),
              (2, 'Maximal 2 Zutaten fehlen'),
            ])
              FilterChip(
                label: Text(entry.$2),
                selected: pantrySuggestionFilter == entry.$1,
                onSelected: (_) =>
                    update(() => pantrySuggestionFilter = entry.$1),
              ),
          ],
        ),
        gap(8),
        DropdownButtonFormField<int>(
          initialValue: pantrySuggestionMaxMinutes,
          decoration: const InputDecoration(
            labelText: 'Maximale Zubereitungszeit',
          ),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Alle Zeiten')),
            DropdownMenuItem(value: 15, child: Text('Bis 15 Minuten')),
            DropdownMenuItem(value: 30, child: Text('Bis 30 Minuten')),
            DropdownMenuItem(value: 45, child: Text('Bis 45 Minuten')),
            DropdownMenuItem(value: 60, child: Text('Bis 60 Minuten')),
          ],
          onChanged: (value) =>
              update(() => pantrySuggestionMaxMinutes = value ?? 0),
        ),
        gap(16),
        if (matches.isEmpty)
          surveyCard(
            'Keine passenden Rezepte',
            'Passe die Filter an oder ergänze weitere Vorräte.',
            color: AppColors.cream,
          ),
        for (final match in matches)
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                detailServings = pantrySuggestionPortions;
                details(match.recipe);
                pantryPage = 0;
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: recipePhoto(match.recipe, height: 180),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                match.recipe.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (match.immediatelyCookable)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.softGreen,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Text(
                                  'Sofort kochbar',
                                  style: TextStyle(
                                    color: AppColors.sage,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        gap(8),
                        Text(
                          '${match.recipe.minutes} Minuten · ${match.percentage} % Zutaten vorhanden',
                          style: muted,
                        ),
                        gap(4),
                        Text(
                          match.missingCount == 0
                              ? 'Alle Zutaten vorhanden'
                              : '${match.missingCount} ${match.missingCount == 1 ? 'Zutat fehlt' : 'Zutaten fehlen'}',
                          style: TextStyle(
                            color: match.missingCount == 0
                                ? AppColors.sage
                                : AppColors.terracotta,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (match.missingCount > 0) ...[
                          gap(12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => addMissingIngredients(match),
                              child: const Text(
                                'Fehlende Zutaten zur Einkaufsliste',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ];
  }

  Future<void> editPantryProduct({
    Map<String, dynamic>? item,
    bool receipt = false,
    Map<String, dynamic>? initial,
  }) async {
    var name = (item ?? initial)?['name'] as String? ?? '';
    var ingredientId = (item ?? initial)?['ingredientId'] as String?;
    final ingredientOptions = {...planningIngredientOptions};
    if (ingredientId != null && !ingredientOptions.containsKey(ingredientId)) {
      ingredientOptions[ingredientId] = name;
    }
    var amount = (item ?? initial)?['amount'] as String? ?? '';
    var location = (item ?? initial)?['location'] as String? ?? 'Kühlschrank';
    var expires = (item ?? initial)?['expires'] as String?;
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            item == null ? 'Lebensmittel erfassen' : 'Lebensmittel bearbeiten',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(
                      labelText: 'Lebensmittel',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Bitte ein Lebensmittel eingeben.'
                        : null,
                    onChanged: (v) {
                      name = v;
                      ingredientId = null;
                    },
                  ),
                  gap(12),
                  TextFormField(
                    initialValue: amount,
                    decoration: const InputDecoration(
                      labelText: 'Menge, z. B. 500 g',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Bitte eine Menge eingeben.'
                        : null,
                    onChanged: (v) => amount = v,
                  ),
                  gap(12),
                  DropdownButtonFormField<String>(
                    initialValue: ingredientId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Zutat für die Wochenplanung (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Keine ausdrückliche Zuordnung'),
                      ),
                      for (final entry
                          in ingredientOptions.entries.toList()
                            ..sort((a, b) => a.value.compareTo(b.value)))
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => ingredientId = v,
                  ),
                  gap(12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: location,
                    decoration: const InputDecoration(labelText: 'Lagerort'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Kühlschrank',
                        child: Text('Kühlschrank'),
                      ),
                      DropdownMenuItem(
                        value: 'Trocken',
                        child: Text('Trocken'),
                      ),
                    ],
                    onChanged: (v) => location = v ?? location,
                  ),
                  gap(12),
                  TextButton.icon(
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      expires == null
                          ? 'Haltbarkeitsdatum ergänzen'
                          : 'Bis ${displayDate(DateTime.parse(expires!))}',
                    ),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(expires ?? '') ?? pantryToday,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null && context.mounted) {
                        setDialogState(() => expires = dateKey(date));
                      }
                    },
                  ),
                  if (expires != null)
                    TextButton(
                      onPressed: () => setDialogState(() => expires = null),
                      child: const Text('Datum entfernen'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            if (item != null)
              TextButton(
                onPressed: () => Navigator.pop(context, 'delete'),
                child: const Text('Entfernen'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, 'save');
                }
              },
              child: Text(item == null ? 'Hinzufügen' : 'Speichern'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    update(() {
      if (result == 'delete') {
        (receipt ? receiptDraft : pantry).remove(item);
        return;
      }
      final target = item ?? <String, dynamic>{};
      target.addAll({
        'name': name.trim(),
        'amount': amount.trim(),
        'location': location,
        'expires': expires,
        'ingredientId': ingredientId,
      });
      if (item == null) pantry.add(target);
    });
    if (!receipt) savePreferences();
  }

  void startReceiptDemo() => update(() {
    pantryPage = 1;
    receiptIsDemo = true;
    receiptSource = 'Beispiel-Bon';
    receiptFingerprint = null;
    receiptResolved = false;
    showAllReceiptItems = false;
    receiptDraft = [
      {'name': 'Basmatireis', 'amount': '500 g', 'location': 'Trocken'},
      {'name': 'Kichererbsen', 'amount': '2 Dosen', 'location': 'Trocken'},
      {
        'name': 'Joghurt, laktosefrei',
        'amount': '500 g',
        'location': 'Kühlschrank',
        'expires': dateKey(pantryToday),
      },
      {
        'name': 'Zucchini',
        'amount': '2 Stück',
        'location': 'Kühlschrank',
        'expires': dateKey(pantryToday.add(const Duration(days: 2))),
      },
      {
        'name': 'Babyspinat',
        'amount': '100 g',
        'location': 'Kühlschrank',
        'expires': dateKey(pantryToday.add(const Duration(days: 1))),
      },
      {'name': 'Haferflocken', 'amount': '500 g', 'location': 'Trocken'},
      {
        'name': 'Cherrytomaten',
        'amount': '250 g',
        'location': 'Kühlschrank',
        'uncertain': true,
      },
    ];
  });

  List<Map<String, dynamic>> get selectedReceiptItems =>
      receiptDraft.where((item) => item['selected'] != false).toList();
  bool get receiptCanImport =>
      selectedReceiptItems.isNotEmpty &&
      (receiptIsDemo
          ? receiptResolved || !receiptDraft.any((p) => p['uncertain'] == true)
          : receiptResolved);

  List<Widget> receiptView() => [
    proposalBack('Zurück zum Vorrat', () => update(() => pantryPage = 0)),
    gap(14),
    title('Einkauf erkannt.'),
    gap(8),
    Text(receiptSource, style: muted),
    gap(18),
    surveyCard(
      '${receiptDraft.length} Positionen erkannt · ${selectedReceiptItems.length} ausgewählt',
      receiptIsDemo
          ? 'Beispieldaten. Mengen und Lagerorte vor dem Übernehmen prüfen.'
          : 'Wähle die Lebensmittel für deinen Vorrat. Haushaltsartikel und unklare Namen sind abgewählt. Stückzahlen auf dem Bon zählen Packungen; deren Inhalt bitte ergänzen. Haltbarkeitsdaten werden nicht geschätzt.',
      color: AppColors.softGreen,
    ),
    gap(18),
    for (final item
        in (showAllReceiptItems ? receiptDraft : receiptDraft.take(4))) ...[
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: item['selected'] != false,
              onChanged: (value) => update(() {
                item['selected'] = value ?? false;
                receiptResolved = false;
              }),
              title: Text(
                item['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${item['amount']} · ${item['location']}',
                style: muted,
              ),
            ),
            if (item['reviewNote'] != null)
              Text(
                item['reviewNote'] as String,
                style: muted.copyWith(fontSize: 12),
              ),
            Wrap(
              children: [
                TextButton(
                  onPressed: () async {
                    await editPantryProduct(item: item, receipt: true);
                    if (mounted) update(() => receiptResolved = false);
                  },
                  child: const Text('Ändern'),
                ),
                TextButton(
                  onPressed: () => update(() {
                    receiptDraft.remove(item);
                    receiptResolved = false;
                  }),
                  child: const Text('Entfernen'),
                ),
              ],
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
      gap(10),
    ],
    if (receiptDraft.length > 4)
      TextButton(
        onPressed: () =>
            update(() => showAllReceiptItems = !showAllReceiptItems),
        child: Text(
          showAllReceiptItems
              ? 'Weniger anzeigen ↑'
              : '${receiptDraft.length - 4} weitere Produkte anzeigen ↓',
        ),
      ),
    gap(12),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        receiptIsDemo
            ? 'Zuordnung bestätigen'
            : 'Auswahl, Mengen und Lagerorte geprüft',
      ),
      subtitle: const Text(
        'Erst nach deiner Bestätigung werden die ausgewählten Produkte gespeichert.',
      ),
      value: receiptResolved,
      onChanged: (value) => update(() => receiptResolved = value ?? false),
    ),
    gap(18),
    Text(
      'Gleiche Artikel mit gleicher Einheit, gleichem Lagerort und gleichem Haltbarkeitsdatum werden zusammengeführt. Der Originalbon wird nicht gespeichert.',
      style: muted,
    ),
  ];

  void importReceipt() {
    if (!receiptCanImport) {
      return;
    }
    if (receiptFingerprint != null &&
        receiptAlreadyImported(receiptFingerprint!)) {
      pantryImportError(
        const FormatException('Dieser Bon wurde bereits übernommen.'),
      );
      return;
    }
    final count = selectedReceiptItems.length;
    update(() {
      for (final raw in selectedReceiptItems) {
        final item = Map<String, dynamic>.from(raw)
          ..removeWhere(
            (key, _) => [
              'uncertain',
              'selected',
              'reviewNote',
              'quantityMissing',
              'price',
            ].contains(key),
          );
        if (receiptFingerprint != null) {
          item['sourceReceiptIds'] = [receiptFingerprint];
        }
        final amount = pantryAmount(item);
        Map<String, dynamic>? existing;
        for (final p in pantry) {
          final old = pantryAmount(p);
          if ((p['name'] as String).toLowerCase() ==
                  (item['name'] as String).toLowerCase() &&
              p['location'] == item['location'] &&
              p['expires'] == item['expires'] &&
              amount != null &&
              old != null &&
              old.$2.toLowerCase() == amount.$2.toLowerCase()) {
            existing = p;
            break;
          }
        }
        if (existing == null) {
          pantry.add(item);
        } else {
          if (receiptFingerprint != null) {
            existing['sourceReceiptIds'] = {
              ...List<String>.from(existing['sourceReceiptIds'] as List? ?? []),
              receiptFingerprint!,
            }.toList();
          }
          existing['amount'] = amountLabel(
            pantryAmount(existing)!.$1 + amount!.$1,
            amount.$2,
          );
        }
      }
      if (receiptFingerprint != null) {
        importedReceiptIds.add(receiptFingerprint!);
      }
      receiptDraft = [];
      pantryPage = 0;
      pantryFilter = 'Alle';
    });
    savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$count ${count == 1 ? 'Produkt' : 'Produkte'} zum Vorrat hinzugefügt.',
        ),
      ),
    );
  }

  String pantryName(String name) => name
      .toLowerCase()
      .replaceAll('babyspinat', 'spinat')
      .replaceAll('basmatireis', 'reis')
      .trim();
  int pantryMatches(Recipe recipe) => recipe.ingredients
      .where(
        (i) => pantry.any(
          (p) => pantryName(p['name'] as String) == pantryName(i.name),
        ),
      )
      .length;
  List<Recipe> get leftoverRecipes {
    final matches = eligibleRecipes.where((r) => pantryMatches(r) > 0).toList();
    matches.sort((a, b) => pantryMatches(b).compareTo(pantryMatches(a)));
    return matches;
  }

  Recipe? get selectedLeftover => leftoverRecipes.isEmpty
      ? null
      : leftoverRecipes[leftoverRecipeIndex % leftoverRecipes.length];

  List<Widget> leftoversView() {
    final recipe = selectedLeftover;
    return [
      proposalBack('Zurück zum Vorrat', () => update(() => pantryPage = 0)),
      gap(14),
      title('Gutes bleibt nicht übrig.'),
      gap(8),
      Text('Aus deinem Vorrat. Für heute Abend.', style: muted),
      gap(18),
      if (urgentPantry.isNotEmpty) ...[
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diese ${urgentPantry.length} haben Vorrang',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              gap(10),
              for (final p in urgentPantry.take(5)) ...[
                costRow('${p['name']} · ${p['amount']}', dueLabel(p)),
                gap(8),
              ],
            ],
          ),
          color: const Color(0xFFF6E9CF),
          padding: const EdgeInsets.all(16),
        ),
        gap(18),
      ],
      costRow('Dein Vorrat kann das.', '$servings Personen'),
      gap(16),
      if (recipe == null)
        surveyCard(
          'Noch kein passendes Resterezept',
          'Erfasse Vorräte oder passe deine Planungsvorgaben an. Deine festen Ausschlüsse und die Kochzeit bleiben berücksichtigt.',
          color: AppColors.cream,
        )
      else
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NUTZT ${pantryMatches(recipe)} DEINER ZUTATEN',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.sage,
                  fontWeight: FontWeight.w600,
                ),
              ),
              gap(12),
              title(recipe.name),
              gap(10),
              Text(mealDescription(recipe, servings), style: muted),
              gap(14),
              surveyCard(
                'Dein Vorrat kocht mit.',
                'Abgleich nach Zutatennamen. Bitte Mengen prüfen; Zusatzkosten sind ohne Preise noch nicht berechnet.',
                color: AppColors.softGreen,
              ),
              gap(14),
              const Text(
                'So kommt dein Rest auf den Tisch',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              gap(12),
              for (var i = 0; i < recipe.steps.length; i++) ...[
                Text(
                  '${i + 1}  ${renderRecipeStep(recipe, recipe.steps[i], portions: servings)}',
                  style: muted,
                ),
                gap(8),
              ],
              TextButton(
                onPressed: () {
                  selectTab(0);
                  details(recipe);
                },
                child: const Text('Rezept ansehen →'),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
        ),
      gap(18),
      surveyCard(
        'Für morgen mitgedacht',
        'Passe die Portionen beim Einplanen an deinen Bedarf an. Vorräte werden erst nach deiner eigenen Prüfung verändert.',
        color: AppColors.softGreen,
      ),
    ];
  }

  Widget pantryActionBar() {
    if (pantryPage >= 3) return preparedActionBar();
    final receipt = pantryPage == 1;
    final recipe = selectedLeftover;
    final enabled = receipt
        ? receiptCanImport
        : recipe != null && !saving && !loading && loadError == null;
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
                  onPressed: !enabled
                      ? null
                      : () {
                          if (receipt) {
                            importReceipt();
                          } else {
                            addRecipe(recipe!, portions: servings);
                          }
                        },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    receipt
                        ? '${selectedReceiptItems.length} ${selectedReceiptItems.length == 1 ? 'Produkt' : 'Produkte'} zum Vorrat hinzufügen'
                        : 'In deinen Wochenplan aufnehmen',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (receipt) ...[
                gap(8),
                Text(
                  'Erst prüfen, dann übernehmen.',
                  textAlign: TextAlign.center,
                  style: muted.copyWith(fontSize: 12),
                ),
              ] else
                TextButton(
                  onPressed: leftoverRecipes.length > 1
                      ? () => update(() => leftoverRecipeIndex++)
                      : null,
                  child: const Text('Andere Resterezepte entdecken →'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
