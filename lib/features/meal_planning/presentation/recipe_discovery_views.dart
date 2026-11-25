part of 'planning_page.dart';

extension _RecipeDiscovery on _PlanningPageState {
  bool get recipeDiscoveryActive =>
      tab == 0 &&
      collectionPage == 0 &&
      openedRecipe == null &&
      cookingPage == 0;
  Widget recipePinnedHeader() => Container(
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Rezepte entdecken',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontSize: 25),
        ),
        gap(12),
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Rezept oder Zutat suchen',
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            prefixIcon: const Icon(Icons.search_rounded, size: 21),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Suche löschen',
                    onPressed: () => update(() {
                      query = '';
                      searchController.clear();
                    }),
                    icon: const Icon(Icons.close),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
          ),
          onChanged: (value) => update(() => query = value),
        ),
      ],
    ),
  );

  Widget recipeDiscoveryControls() {
    if (cloudOffline) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    Widget action(String tooltip, IconData icon, VoidCallback? onPressed) =>
        Material(
          color: colors.primaryContainer,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: .18),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            color: colors.primary,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: Icon(icon, size: 25),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            action(
              admin ? 'Rezept erstellen' : 'Eigenes Rezept erstellen',
              Icons.add,
              admin
                  ? (adminActionBusy ? null : () => adminRecipeAction('create'))
                  : () => editPersonalRecipe(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            action(
              'Rezept importieren',
              Icons.file_download_outlined,
              () => update(() {
                collectionImportReturnPage = 0;
                collectionPage = 3;
                personalRecipeError = null;
              }),
            ),
            const SizedBox(width: 12),
            Material(
              color: colors.primaryContainer,
              elevation: 3,
              shadowColor: Colors.black.withValues(alpha: .18),
              shape: const CircleBorder(),
              child: PopupMenuButton<int>(
                tooltip: 'Rezeptauswahl ändern',
                icon: Icon(
                  recipeFilter == 0 ? Icons.favorite_border : Icons.favorite,
                  color: colors.primary,
                  size: 25,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 240),
                style: IconButton.styleFrom(
                  fixedSize: const Size(48, 48),
                  shape: const CircleBorder(),
                ),
                initialValue: recipeFilter,
                onSelected: (value) {
                  update(() => recipeFilter = value);
                },
                itemBuilder: (context) => [
                  for (final (value, label, icon) in [
                    (0, 'Alle Rezepte', Icons.restaurant_outlined),
                    (1, 'Gemerkt', Icons.bookmark_border),
                    (2, 'Favoriten', Icons.favorite_border),
                    (3, 'Aus Vorrat', Icons.kitchen_outlined),
                  ])
                    PopupMenuItem(
                      value: value,
                      child: Row(
                        children: [
                          Icon(icon, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(label)),
                          if (recipeFilter == value)
                            const Icon(Icons.check, size: 18),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData categoryIcon(String key) => switch (key) {
    'meat' => Icons.outdoor_grill_outlined,
    'fish' => Icons.set_meal_outlined,
    'vegetarian' => Icons.eco_outlined,
    'vegan' => Icons.spa_outlined,
    'starter' => Icons.tapas_outlined,
    'main' => Icons.restaurant_outlined,
    'soup' => Icons.soup_kitchen_outlined,
    'salad' => Icons.grass_outlined,
    'dessert' => Icons.cake_outlined,
    'breakfast' => Icons.free_breakfast_outlined,
    'stew' => Icons.soup_kitchen_outlined,
    'casserole' => Icons.kitchen_outlined,
    'baking' => Icons.bakery_dining_outlined,
    'pasta' => Icons.ramen_dining_outlined,
    'rice' => Icons.rice_bowl_outlined,
    'potato' => Icons.dinner_dining_outlined,
    'bread' => Icons.bakery_dining_outlined,
    'cake' => Icons.cake_outlined,
    'grilling' => Icons.outdoor_grill_outlined,
    'sauce' => Icons.tapas_outlined,
    _ => Icons.bakery_dining_outlined,
  };

  Map<String, String> get discoveryCategories => {
    'all': 'Alle',
    for (final entry in recipeCategoryLabels.entries)
      if (entry.key != 'breakfast') entry.key: entry.value,
  };

  Color categoryAccent(String key) => switch (key) {
    'meat' || 'grilling' => const Color(0xFF9B614E),
    'fish' => const Color(0xFF467A87),
    'vegetarian' || 'vegan' || 'salad' => const Color(0xFF547B4C),
    'dessert' || 'cake' || 'baking' => const Color(0xFF9A6A7D),
    'pasta' || 'rice' || 'potato' || 'bread' => const Color(0xFFA1783E),
    _ => AppColors.sage,
  };

  Widget recipeCategoryTile(String key, String label) {
    final selected = key == 'favorites'
        ? recipeFilter == 2 && recipeCategory == null
        : recipeFilter == 0 && (recipeCategory ?? 'all') == key;
    final colors = Theme.of(context).colorScheme;
    void select() => update(() {
      recipeFilter = key == 'favorites' ? 2 : 0;
      recipeCategory =
          key == 'favorites' || key == 'all' || recipeCategory == key
          ? null
          : key;
    });
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: select,
      child: Material(
        key: selected ? recipeCategoryAnchor : null,
        color: selected ? AppColors.sage : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: selected
                ? AppColors.sage
                : colors.outlineVariant.withValues(alpha: .6),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: select,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showRecipeCategories() async {
    var categorySearch = '';
    final selection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              8,
              22,
              22 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SizedBox(
              height: (MediaQuery.sizeOf(context).height * .65).clamp(200, 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Was möchtest du kochen?',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kategorien schließen',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  gap(14),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Kategorie suchen',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setSheetState(
                      () => categorySearch = value.trim().toLowerCase(),
                    ),
                  ),
                  gap(18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final entry in discoveryCategories.entries.where(
                            (entry) => entry.value.toLowerCase().contains(
                              categorySearch,
                            ),
                          ))
                            ChoiceChip(
                              avatar: RecipeCategoryIcon(
                                entry.key,
                                color: (recipeCategory ?? 'all') == entry.key
                                    ? Theme.of(context).colorScheme.primary
                                    : categoryAccent(entry.key),
                                size: 22,
                                fallback: categoryIcon(entry.key),
                              ),
                              label: Text(entry.value),
                              selected: (recipeCategory ?? 'all') == entry.key,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  Navigator.pop(context, entry.key),
                            ),
                          if (!discoveryCategories.values.any(
                            (value) =>
                                value.toLowerCase().contains(categorySearch),
                          ))
                            Text('Keine Kategorie gefunden.', style: muted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (selection != null && mounted) {
      update(() {
        recipeFilter = 0;
        recipeCategory = selection == 'all' ? null : selection;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final anchor = recipeCategoryAnchor.currentContext;
        if (mounted && anchor != null) {
          Scrollable.ensureVisible(
            anchor,
            alignment: .5,
            duration: const Duration(milliseconds: 180),
          );
        }
      });
    }
  }

  List<Widget> recipeDiscoveryView() {
    final filtered = dinnerRecipes.where((recipe) {
      final search = query.trim().toLowerCase();
      final inStock = recipe.ingredients.any(
        (i) => pantry.any(
          (p) => (p['name'] as String).toLowerCase() == i.name.toLowerCase(),
        ),
      );
      return !hiddenRecipes.contains(recipe.id) &&
          (search.isEmpty ||
              recipe.name.toLowerCase().contains(search) ||
              recipe.ingredients.any(
                (i) => i.name.toLowerCase().contains(search),
              )) &&
          (recipeCategory == null ||
              recipe.categories.contains(recipeCategory) ||
              (recipeCategory == 'vegetarian' &&
                  recipe.categories.contains('vegan'))) &&
          (recipeFilter != 1 || rememberedRecipes.contains(recipe.id)) &&
          (recipeFilter != 2 || favoriteRecipes.contains(recipe.id)) &&
          (recipeFilter != 3 || inStock);
    }).toList();
    final searching =
        query.trim().isNotEmpty || recipeCategory != null || recipeFilter != 0;
    final now = DateTime.now();
    final dayIndex = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(2026)).inDays;
    final featured = filtered.isEmpty
        ? null
        : filtered[searching ? 0 : dayIndex % filtered.length];
    final popular = filtered.where((r) => r.favoriteCount > 0).toList()
      ..sort((a, b) {
        final value = b.favoriteCount.compareTo(a.favoriteCount);
        return value == 0 ? a.name.compareTo(b.name) : value;
      });
    return [
      Row(
        children: [
          IconButton(
            tooltip: 'Kategorien durchsuchen',
            onPressed: showRecipeCategories,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.tune_rounded, size: 20),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in {
                    'all': 'Alle',
                    'favorites': 'Favoriten',
                    ...Map.of(discoveryCategories)..remove('all'),
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: recipeCategoryTile(entry.key, entry.value),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      gap(14),
      if (searching)
        section(
          switch (recipeFilter) {
            1 => 'Gemerkte Rezepte',
            2 => 'Favoriten',
            3 => 'Aus deinem Vorrat',
            _ => 'Suchergebnisse',
          },
          action: TextButton(
            onPressed: () => update(() {
              query = '';
              searchController.clear();
              recipeCategory = null;
              recipeFilter = 0;
            }),
            child: const Text('Zurücksetzen'),
          ),
        )
      else
        section('Rezept des Tages'),
      if (filtered.isEmpty)
        panel(
          Text(
            dinnerRecipes.isEmpty
                ? 'Noch keine veröffentlichten Rezepte vorhanden.'
                : recipeFilter == 2
                ? 'Noch keine Favoriten für diese Auswahl. Markiere ein Rezept mit „Favorit“.'
                : recipeFilter == 1
                ? 'Noch keine gemerkten Rezepte für diese Auswahl. Speichere ein Rezept mit „Merken“.'
                : recipeFilter == 3
                ? 'Keine passenden Rezepte zu deinem Vorrat. Ergänze Zutaten im Vorrat oder ändere deine Suche.'
                : 'Keine passenden Rezepte. Probiere einen anderen Suchbegriff oder eine andere Kategorie.',
            style: muted,
          ),
        ),
      if (featured != null && recipeFilter == 0)
        recipeCard(featured, featured: true),
      if (!searching) ...[
        gap(26),
        section('Beliebte Rezepte'),
        if (popular.isEmpty)
          panel(
            Text(
              'Hier erscheinen Rezepte, die besonders häufig als Favorit gespeichert wurden. Es liegen noch keine Favoritenzahlen vor.',
              style: muted,
            ),
          ),
        if (popular.isNotEmpty) recipeGrid(popular.take(4).toList()),
      ],
      if (recipeFilter != 0 && filtered.isNotEmpty || filtered.length > 1) ...[
        gap(20),
        if (recipeFilter == 0)
          section(searching ? 'Weitere Treffer' : 'Weitere Rezepte'),
        recipeGrid(
          filtered
              .where((recipe) => recipeFilter != 0 || recipe.id != featured?.id)
              .toList(),
        ),
      ],
      gap(18),
      Text(
        '${filtered.length} von ${dinnerRecipes.length} Rezepten',
        style: muted,
      ),
    ];
  }

  Widget recipeGrid(List<Recipe> items) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 700
          ? 3
          : constraints.maxWidth >= 260
          ? 2
          : 1;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 14,
        children: [
          for (final recipe in items)
            SizedBox(width: width, child: recipeCard(recipe)),
        ],
      );
    },
  );
}
