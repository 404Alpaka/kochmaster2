part of 'planning_page.dart';

extension _RecipeCollectionViews on _PlanningPageState {
  List<Widget> recipeCollectionFlow() => switch (collectionPage) {
    2 => personalRecipeEditorView(),
    3 => recipeImportView(),
    4 => personalRecipeEditorView(),
    _ => recipeCollectionView(),
  };
  Map<String, dynamic>? personalRecipeRecord(String id) {
    for (final r in personalRecipes) {
      if ((r['recipe'] as Map)['id'] == id) return r;
    }
    return null;
  }

  bool recipeWasCooked(String id) =>
      cookingSession.cookedEntries.any((key) => key.endsWith(':$id'));
  List<Recipe> get collectedRecipes {
    final pool = <String, Recipe>{
      for (final m in plan.values)
        if (m.preparedMealId == null) m.recipe.id: m.recipe,
      for (final r in recipes) r.id: r,
    };
    return pool.values
        .where(
          (r) =>
              isDinnerRecipe(r) &&
              (personalRecipeRecord(r.id) != null ||
                  rememberedRecipes.contains(r.id) ||
                  favoriteRecipes.contains(r.id) ||
                  recipeWasCooked(r.id)),
        )
        .toList();
  }

  bool collectionMatches(Recipe r, String filter) => switch (filter) {
    'Gemerkt' => rememberedRecipes.contains(r.id),
    'Favoriten' => favoriteRecipes.contains(r.id),
    'Gekocht' => recipeWasCooked(r.id),
    'Eigene' => personalRecipeRecord(r.id)?['kind'] == 'own',
    'Importiert' => personalRecipeRecord(r.id)?['kind'] == 'imported',
    _ => true,
  };
  List<Widget> recipeCollectionView() {
    final all = collectedRecipes;
    final filtered = all.where((r) {
      final notes = personalRecipeRecord(r.id)?['notes'] as String? ?? '';
      final haystack =
          '${r.name} $notes ${r.ingredients.map((i) => i.name).join(' ')}'
              .toLowerCase();
      return haystack.contains(collectionQuery.toLowerCase()) &&
          collectionFilters.every((f) => collectionMatches(r, f));
    }).toList();
    return [
      proposalBack('Rezepte entdecken', () => update(() => collectionPage = 0)),
      gap(14),
      title('Meine Rezepte'),
      gap(12),
      Text(
        '${all.length} Rezepte · dein Geschmack, deine Sammlung',
        style: muted,
      ),
      gap(18),
      TextFormField(
        initialValue: collectionQuery,
        decoration: const InputDecoration(
          labelText: 'Sammlung durchsuchen',
          hintText: 'Rezepte, Zutaten oder Notizen',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => update(() => collectionQuery = v),
      ),
      gap(18),
      Wrap(
        spacing: 6,
        runSpacing: 8,
        children: [
          FilterChip(
            label: Text('Alle ${all.length}'),
            selected: collectionFilters.isEmpty,
            onSelected: (_) => update(collectionFilters.clear),
          ),
          for (final filter in [
            'Gemerkt',
            'Favoriten',
            'Gekocht',
            'Eigene',
            'Importiert',
          ])
            FilterChip(
              label: Text(
                '$filter ${all.where((r) => collectionMatches(r, filter)).length}',
              ),
              selected: collectionFilters.contains(filter),
              onSelected: (_) => update(() {
                if (!collectionFilters.add(filter))
                  collectionFilters.remove(filter);
              }),
            ),
        ],
      ),
      gap(10),
      Text(
        'Filter lassen sich kombinieren.',
        style: muted.copyWith(fontSize: 12),
      ),
      gap(18),
      recipeAction(
        'Rezept importieren →',
        false,
        () => update(() {
          collectionImportReturnPage = 1;
          collectionPage = 3;
          personalRecipeError = null;
        }),
      ),
      gap(18),
      if (filtered.isEmpty)
        surveyCard(
          'Hier ist noch Platz.',
          all.isEmpty
              ? 'Merke Rezepte, wähle Favoriten oder lege dein eigenes Rezept an.'
              : 'Für diese Suche und Filter gibt es keine Treffer.',
          color: AppColors.softGreen,
        ),
      for (final recipe in filtered) ...[
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                [
                  if (personalRecipeRecord(recipe.id)?['kind'] == 'own')
                    'Eigenes Rezept',
                  if (personalRecipeRecord(recipe.id)?['kind'] == 'imported')
                    'Importiert',
                  if (rememberedRecipes.contains(recipe.id)) 'Gemerkt',
                  if (favoriteRecipes.contains(recipe.id)) 'Favorit',
                  if (recipeWasCooked(recipe.id)) 'Bereits gekocht',
                ].join(' · '),
                style: const TextStyle(color: AppColors.sage, fontSize: 13),
              ),
              gap(9),
              Text(
                recipe.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              gap(9),
              Text(
                '${recipe.minutes} Min. · ${recipe.servings} Portionen',
                style: muted,
              ),
              if (personalRecipeRecord(recipe.id) != null) ...[
                gap(6),
                Text(
                  'Zutaten und Allergene nicht redaktionell geprüft.',
                  style: muted.copyWith(fontSize: 12),
                ),
              ],
              gap(12),
              recipeAction('Öffnen', false, () => details(recipe)),
              if (personalRecipeRecord(recipe.id) != null)
                TextButton(
                  onPressed: () =>
                      editPersonalRecipe(personalRecipeRecord(recipe.id)!),
                  child: const Text('Eigenes Rezept bearbeiten'),
                ),
            ],
          ),
          padding: const EdgeInsets.all(16),
        ),
        gap(18),
      ],
      Text(
        'Eigene Rezepte und Notizen werden lokal gespeichert und nicht automatisch mit einem Haushalt geteilt.',
        style: muted,
      ),
    ];
  }

  void editPersonalRecipe([Map<String, dynamic>? record]) {
    if (cloudOffline) {
      offlineEditMessage();
      return;
    }
    final recipe = record == null
        ? null
        : recipeFromSnapshot(
            Map<String, dynamic>.from(record['recipe'] as Map),
          );
    update(() {
      openedRecipe = null;
      collectionPage = 2;
      importedPreview = false;
      personalRecipeError = null;
      personalRecipeDraft = {
        'id': recipe?.id ?? 'personal-${DateTime.now().microsecondsSinceEpoch}',
        'existing': record != null,
        'kind': record?['kind'] ?? 'own',
        'name': recipe?.name ?? '',
        'servings': '${recipe?.servings ?? 2}',
        'minutes': '${recipe?.minutes ?? 30}',
        'categories': recipe?.categories.toList() ?? <String>[],
        'source': record?['source'] ?? '',
        'notes': record?['notes'] ?? '',
        'ingredients': recipe == null
            ? <Map<String, dynamic>>[]
            : [
                for (final i in recipe.ingredients)
                  {
                    'key':
                        '${DateTime.now().microsecondsSinceEpoch}-${i.ingredientId}',
                    'id': i.ingredientId,
                    'name': i.name,
                    'quantity': '${i.quantity}',
                    'unit': i.unit,
                  },
              ],
        'steps': recipe == null
            ? <Map<String, dynamic>>[]
            : [
                for (var i = 0; i < recipe.steps.length; i++)
                  {'key': 'step-$i', 'text': recipe.steps[i]},
              ],
      };
    });
  }

  List<Map<String, dynamic>> get personalIngredientRows =>
      (personalRecipeDraft['ingredients'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get personalStepRows =>
      (personalRecipeDraft['steps'] as List).cast<Map<String, dynamic>>();
  Widget personalField(
    String field,
    String label, {
    bool number = false,
    int lines = 1,
  }) => TextFormField(
    key: ValueKey('${personalRecipeDraft['id']}-$field'),
    initialValue: personalRecipeDraft[field] as String? ?? '',
    decoration: InputDecoration(labelText: label),
    maxLines: lines,
    keyboardType: number
        ? TextInputType.number
        : lines > 1
        ? TextInputType.multiline
        : TextInputType.text,
    onChanged: (v) => personalRecipeDraft[field] = v,
  );
  List<Widget> personalRecipeEditorView() => [
    proposalBack('Meine Sammlung', () => update(() => collectionPage = 1)),
    gap(14),
    title(
      importedPreview
          ? 'Import prüfen.'
          : personalRecipeDraft['existing'] == true
          ? 'Rezept bearbeiten.'
          : 'Dein eigenes Rezept.',
    ),
    gap(12),
    Text(
      importedPreview
          ? 'Importvorschau · noch nicht gespeichert. Prüfe alle Angaben.'
          : 'Ein persönlicher Entwurf für deine Sammlung.',
      style: muted,
    ),
    gap(18),
    personalField('name', 'Rezeptname'),
    gap(18),
    Row(
      children: [
        Expanded(child: personalField('servings', 'Portionen', number: true)),
        const SizedBox(width: 12),
        Expanded(
          child: personalField(
            'minutes',
            'Gesamtzeit in Minuten',
            number: true,
          ),
        ),
      ],
    ),
    gap(18),
    section('Kategorien'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in recipeCategoryLabels.entries)
          FilterChip(
            label: Text(entry.value),
            selected: (personalRecipeDraft['categories'] as List).contains(
              entry.key,
            ),
            onSelected: (selected) => update(() {
              final values = personalRecipeDraft['categories'] as List;
              if (selected) {
                if (['meat', 'fish'].contains(entry.key))
                  values.removeWhere(
                    (v) => ['vegetarian', 'vegan'].contains(v),
                  );
                if (['vegetarian', 'vegan'].contains(entry.key))
                  values.removeWhere((v) => ['meat', 'fish'].contains(v));
                values.add(entry.key);
              } else {
                values.remove(entry.key);
              }
            }),
          ),
      ],
    ),
    gap(18),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section('Zutaten · für die angegebenen Portionen'),
          for (final row in personalIngredientRows) ...[
            TextFormField(
              key: ValueKey('ingredient-${row['key']}'),
              initialValue: row['name'] as String,
              decoration: const InputDecoration(labelText: 'Zutat'),
              onChanged: (v) {
                row['name'] = v;
                row['id'] = null;
              },
            ),
            gap(8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('quantity-${row['key']}'),
                    initialValue: row['quantity'] as String,
                    decoration: const InputDecoration(labelText: 'Menge'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => row['quantity'] = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('unit-${row['key']}'),
                    initialValue: row['unit'] as String,
                    decoration: const InputDecoration(
                      labelText: 'Einheit, z. B. g',
                    ),
                    onChanged: (v) => row['unit'] = v,
                  ),
                ),
                IconButton(
                  tooltip: 'Zutat entfernen',
                  onPressed: () =>
                      update(() => personalIngredientRows.remove(row)),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            gap(14),
          ],
          recipeAction(
            'Zutat hinzufügen +',
            false,
            () => update(
              () => personalIngredientRows.add({
                'key': '${DateTime.now().microsecondsSinceEpoch}',
                'name': '',
                'quantity': '',
                'unit': 'g',
              }),
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
    ),
    gap(18),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section('Zubereitung'),
          for (var i = 0; i < personalStepRows.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('step-${personalStepRows[i]['key']}'),
                    initialValue: personalStepRows[i]['text'] as String,
                    decoration: InputDecoration(labelText: 'Schritt ${i + 1}'),
                    maxLines: 3,
                    onChanged: (v) => personalStepRows[i]['text'] = v,
                  ),
                ),
                IconButton(
                  tooltip: 'Schritt entfernen',
                  onPressed: () => update(() => personalStepRows.removeAt(i)),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            gap(14),
          ],
          recipeAction(
            'Schritt hinzufügen +',
            false,
            () => update(
              () => personalStepRows.add({
                'key': '${DateTime.now().microsecondsSinceEpoch}',
                'text': '',
              }),
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
    ),
    gap(18),
    personalField('source', 'Quelle oder Rezept-Link (optional)'),
    gap(18),
    personalField('notes', 'Private Notizen (optional)', lines: 3),
    gap(18),
    surveyCard(
      'Zutaten & Allergene noch prüfen',
      'Als persönliches Rezept speicherbar. Angaben sind nicht redaktionell geprüft und gelten nicht als verlässliche Allergendaten für die automatische Planung mit festen Ausschlüssen. Nährwerte werden nicht geschätzt.',
      color: const Color(0xFFF6E9CF),
    ),
    gap(18),
    if (personalRecipeDraft['existing'] == true) ...[
      surveyCard(
        'Bestehende Pläne nicht still verändern.',
        'Gemerkt-, Favoriten- und Gekocht-Status bleiben erhalten. Bereits geplante Gerichte behalten ihren gespeicherten Rezeptstand.',
        color: AppColors.cream,
      ),
      TextButton(
        onPressed: deletePersonalRecipe,
        child: const Text('Eigenes Rezept löschen'),
      ),
    ],
    if (personalRecipeError != null) ...[
      gap(14),
      Text(
        personalRecipeError!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ],
  ];

  String personalIngredientId(Map<String, dynamic> row) {
    if (row['id'] is String) return row['id'] as String;
    final name = (row['name'] as String).trim().toLowerCase();
    for (final r in recipes)
      for (final i in r.ingredients) {
        if (i.name.toLowerCase() == name) return i.ingredientId;
      }
    return 'personal-ingredient-${Uri.encodeComponent(name)}';
  }

  void savePersonalRecipe() {
    if (cloudOffline) {
      offlineEditMessage();
      return;
    }
    final name = (personalRecipeDraft['name'] as String).trim();
    final portions = int.tryParse(personalRecipeDraft['servings'] as String);
    final minutes = int.tryParse(personalRecipeDraft['minutes'] as String);
    final invalidIngredients = personalIngredientRows.any((r) {
      final q = double.tryParse((r['quantity'] as String).replaceAll(',', '.'));
      return (r['name'] as String).trim().isEmpty ||
          (r['unit'] as String).trim().isEmpty ||
          q == null ||
          !q.isFinite ||
          q <= 0;
    });
    if (name.isEmpty ||
        portions == null ||
        portions < 1 ||
        portions > 99 ||
        minutes == null ||
        minutes < 1 ||
        minutes > 10080 ||
        personalIngredientRows.isEmpty ||
        invalidIngredients ||
        personalStepRows.isEmpty ||
        personalStepRows.any((s) => (s['text'] as String).trim().isEmpty)) {
      update(
        () => personalRecipeError = 'Bitte Name, 1–99 Portionen, gültige Kochzeit, mindestens eine Zutat mit positiver Menge und Einheit sowie vollständige Kochschritte angeben.',
      );
      return;
    }
    final recipe = Recipe(
      id: personalRecipeDraft['id'] as String,
      name: name,
      minutes: minutes,
      servings: portions,
      categories: (personalRecipeDraft['categories'] as List)
          .cast<String>()
          .toSet(),
      ingredients: [
        for (final row in personalIngredientRows)
          IngredientAmount(
            personalIngredientId(row),
            (row['name'] as String).trim(),
            double.parse((row['quantity'] as String).replaceAll(',', '.')),
            (row['unit'] as String).trim(),
          ),
      ],
      steps: [
        for (final row in personalStepRows) (row['text'] as String).trim(),
      ],
    );
    final record = {
      'recipe': recipeSnapshot(recipe),
      'kind': personalRecipeDraft['kind'],
      'source': personalRecipeDraft['source'],
      'notes': personalRecipeDraft['notes'],
    };
    update(() {
      personalRecipes.removeWhere(
        (r) => (r['recipe'] as Map)['id'] == recipe.id,
      );
      personalRecipes.add(record);
      collectionPage = 1;
      openedRecipe = null;
      collectionFilters.clear();
      collectionQuery = '';
      personalRecipeError = null;
      importedPreview = false;
    });
    savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Persönliches Rezept lokal gespeichert.')),
    );
  }

  Future<void> deletePersonalRecipe() async {
    final id = personalRecipeDraft['id'] as String;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eigenes Rezept löschen?'),
        content: const Text(
          'Das Rezept wird aus deiner Sammlung entfernt. Bereits gespeicherte Planplätze und gekochte Mahlzeiten behalten ihre Rezeptkopie.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    update(() {
      personalRecipes.removeWhere((r) => (r['recipe'] as Map)['id'] == id);
      rememberedRecipes.remove(id);
      favoriteRecipes.remove(id);
      hiddenRecipes.remove(id);
      collectionPage = 1;
    });
    savePreferences();
  }

  List<Widget> recipeImportView() => [
    proposalBack(
      collectionImportReturnPage == 1 ? 'Meine Sammlung' : 'Rezepte entdecken',
      () => update(() => collectionPage = collectionImportReturnPage),
    ),
    gap(14),
    title('Lieblingsrezept gefunden?'),
    gap(12),
    Text(
      'Übernimm es in deine Sammlung. Vor dem Speichern prüfst du alle Angaben.',
      style: muted,
    ),
    gap(18),
    Row(
      children: [
        Expanded(
          child: recipeAction(
            'Rezept-Link',
            recipeImportLinkMode,
            () => update(() => recipeImportLinkMode = true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: recipeAction(
            'Rezepttext',
            !recipeImportLinkMode,
            () => update(() => recipeImportLinkMode = false),
          ),
        ),
      ],
    ),
    gap(18),
    TextFormField(
      initialValue: recipeImportSource,
      decoration: const InputDecoration(
        labelText: 'Rezept-Link / Quelle (optional)',
      ),
      keyboardType: TextInputType.url,
      onChanged: (v) => recipeImportSource = v,
    ),
    gap(18),
    if (recipeImportLinkMode) ...[
      surveyCard(
        'Link als Quelle erhalten',
        'Automatisches Auslesen von Webseiten ist noch nicht angebunden. Füge den Rezepttext unten ein. Der Link bleibt bei deinem Import gespeichert.',
        color: AppColors.cream,
      ),
      gap(18),
    ],
    TextFormField(
      key: ValueKey('import-text-$recipeImportText'),
      initialValue: recipeImportText,
      maxLines: 12,
      decoration: const InputDecoration(
        labelText: 'Rezepttext',
        hintText: 'Rezeptname\nPortionen: 2\nZeit: 30\nZutaten:\n150 g Reis\n1 Stück Zucchini\nZubereitung:\nReis garen.\nZucchini anbraten.',
      ),
      onChanged: (v) => recipeImportText = v,
    ),
    gap(18),
    surveyCard(
      'Du behältst die Kontrolle.',
      '1 Quelle und Rezepttext übernehmen\n2 Portionen, Mengen und Schritte prüfen\n3 Mit Quelle in deiner Sammlung speichern. Nicht erkannte Angaben bleiben in der Originaltext-Notiz erhalten.',
      color: AppColors.softGreen,
    ),
    gap(14),
    TextButton(
      onPressed: () => update(() {
        recipeImportText = 'Zitronen-Reispfanne\nPortionen: 2\nZeit: 25\nZutaten:\n150 g Basmatireis\n1 Stück Zucchini\n1 Stück Zitrone\n1 EL Olivenöl\nZubereitung:\nReis garen.\nZucchini in Öl anbraten.\nReis unterheben und mit Zitrone abschmecken.';
        recipeImportSource = '';
      }),
      child: const Text('Beispieltext laden · Demo'),
    ),
    if (personalRecipeError != null)
      Text(
        personalRecipeError!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
  ];
  void previewRecipeImport() {
    final text = recipeImportText.trim();
    if (text.isEmpty) {
      update(
        () => personalRecipeError = 'Bitte zuerst einen Rezepttext einfügen.',
      );
      return;
    }
    final source = recipeImportSource.trim();
    if (recipeImportLinkMode && source.isNotEmpty) {
      final uri = Uri.tryParse(source);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        update(
          () => personalRecipeError = 'Bitte einen gültigen http(s)-Link eingeben oder Rezepttext wählen.',
        );
        return;
      }
    }
    editPersonalRecipe();
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    var section = '';
    personalRecipeDraft['name'] = lines.first;
    personalRecipeDraft['servings'] = '';
    personalRecipeDraft['minutes'] = '';
    personalRecipeDraft['kind'] = 'imported';
    personalRecipeDraft['source'] = source;
    personalRecipeDraft['notes'] = 'Originaltext:\n$text';
    for (final line in lines.skip(1)) {
      final portions = RegExp(
        r'^(?:Portionen|Personen)\s*:\s*(\d+)',
        caseSensitive: false,
      ).firstMatch(line);
      final time = RegExp(
        r'^(?:Zeit|Gesamtzeit|Kochzeit)\s*:\s*(\d+)',
        caseSensitive: false,
      ).firstMatch(line);
      if (portions != null) {
        personalRecipeDraft['servings'] = portions.group(1)!;
        continue;
      }
      if (time != null) {
        personalRecipeDraft['minutes'] = time.group(1)!;
        continue;
      }
      if (RegExp(r'^Zutaten\s*:?$', caseSensitive: false).hasMatch(line)) {
        section = 'ingredients';
        continue;
      }
      if (RegExp(
        r'^(?:Zubereitung|Schritte)\s*:?$',
        caseSensitive: false,
      ).hasMatch(line)) {
        section = 'steps';
        continue;
      }
      if (section == 'ingredients') {
        final match = RegExp(
          r'^[-•]?\s*(\d+(?:[.,]\d+)?)\s+(g|kg|ml|l|EL|TL|Stück|Dose[n]?|Packung(?:en)?)\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(line);
        personalIngredientRows.add({
          'key': 'import-${personalIngredientRows.length}',
          'name': match?.group(3) ?? line,
          'quantity': match?.group(1) ?? '',
          'unit': match?.group(2) ?? '',
        });
      } else if (section == 'steps') {
        personalStepRows.add({
          'key': 'import-${personalStepRows.length}',
          'text': line.replaceFirst(RegExp(r'^\d+[.)]\s*'), ''),
        });
      }
    }
    update(() {
      importedPreview = true;
      collectionPage = 4;
      personalRecipeError = null;
    });
  }

  Widget recipeCollectionActionBar() {
    final label = collectionPage == 1
        ? 'Eigenes Rezept erstellen +'
        : collectionPage == 3
        ? 'Importvorschau öffnen'
        : importedPreview
        ? 'Mit Prüfhinweis speichern'
        : personalRecipeDraft['existing'] == true
        ? 'Änderungen speichern'
        : 'Eigenes Rezept speichern';
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
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                  onPressed: () {
                    if (collectionPage == 1) {
                      editPersonalRecipe();
                    } else if (collectionPage == 3) {
                      previewRecipeImport();
                    } else {
                      savePersonalRecipe();
                    }
                  },
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
              gap(8),
              Text(
                collectionPage == 3
                    ? 'Quelle bleibt erhalten · vor dem Speichern prüfen.'
                    : 'Persönliche Sammlung · lokal gespeichert.',
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
