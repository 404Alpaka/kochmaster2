part of 'planning_page.dart';

extension _RecipeDiscovery on _PlanningPageState {
  bool get recipeDiscoveryActive =>
      tab == 0 &&
      collectionPage == 0 &&
      openedRecipe == null &&
      cookingPage == 0;
  double get recipeHeaderHeight {
    final width = MediaQuery.sizeOf(context).width.clamp(0, 1100).toDouble();
    final painter = TextPainter(
      text: TextSpan(
        text: 'Rezepte entdecken',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontSize: 25),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: (width - 98).clamp(1, 1100).toDouble());
    final titleHeight = painter.height < 46 ? 46.0 : painter.height;
    painter.dispose();
    return 20 +
        titleHeight +
        8 +
        MediaQuery.textScalerOf(context).scale(16) * 1.5 +
        32;
  }

  Widget recipePinnedHeader() => ClipRect(
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        height: recipeHeaderHeight,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.lightBackground.withValues(alpha: .86),
              AppColors.lightBackground.withValues(alpha: .66),
              AppColors.lightBackground.withValues(alpha: .55),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Rezepte entdecken',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontSize: 25),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Meine Rezeptsammlung',
                  onPressed: showRecipeCollection,
                  icon: const Icon(Icons.favorite_border),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.softGreen,
                    foregroundColor: AppColors.sage,
                    fixedSize: const Size(46, 46),
                  ),
                ),
              ],
            ),
            gap(8),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Rezept oder Zutat suchen',
                filled: true,
                fillColor: Colors.white.withValues(alpha: .88),
                prefixIcon: const Icon(Icons.search_rounded),
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
                  horizontal: 18,
                  vertical: 16,
                ),
              ),
              onChanged: (value) => update(() => query = value),
            ),
          ],
        ),
      ),
    ),
  );

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
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in <String, String>{
              'all': 'Alle',
              for (final entry in recipeCategoryLabels.entries)
                if (entry.key != 'breakfast') entry.key: entry.value,
            }.entries)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 78,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => update(
                      () => recipeCategory =
                          entry.key == 'all' || recipeCategory == entry.key
                          ? null
                          : entry.key,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor:
                                (recipeCategory ?? 'all') == entry.key
                                ? AppColors.sage
                                : AppColors.softGreen,
                            child: Icon(
                              entry.key == 'all'
                                  ? Icons.apps_rounded
                                  : categoryIcon(entry.key),
                              color: (recipeCategory ?? 'all') == entry.key
                                  ? Colors.white
                                  : AppColors.sage,
                            ),
                          ),
                          gap(8),
                          Text(
                            entry.value,
                            maxLines: 1,
                            style: muted.copyWith(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
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
      gap(14),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final (index, label) in [
            (0, 'Entdecken'),
            (1, 'Gemerkt'),
            (2, 'Favoriten'),
            (3, 'Aus Vorrat'),
          ])
            ChoiceChip(
              label: Text(label),
              selected: recipeFilter == index,
              onSelected: (_) => update(() => recipeFilter = index),
            ),
        ],
      ),
      gap(22),
      if (searching)
        section(
          'Suchergebnisse',
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
                : 'Keine passenden Rezepte. Probiere einen anderen Suchbegriff oder eine andere Kategorie.',
            style: muted,
          ),
        ),
      if (featured != null) recipeCard(featured, featured: true),
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
        for (final recipe in popular.take(4)) ...[
          panel(
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 60,
                  child: recipePhoto(recipe, height: 60),
                ),
              ),
              title: Text(recipe.name),
              subtitle: Text(
                '${recipe.favoriteCount} Favoriten · ${recipe.minutes} Min.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => details(recipe),
            ),
          ),
          gap(10),
        ],
      ],
      if (filtered.length > 1) ...[
        gap(20),
        section(searching ? 'Weitere Treffer' : 'Weitere Rezepte'),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final recipe in filtered.where(
                (recipe) => recipe.id != featured?.id,
              ))
                SizedBox(
                  width: constraints.maxWidth >= 700
                      ? (constraints.maxWidth - 28) / 3
                      : constraints.maxWidth >= 340
                      ? (constraints.maxWidth - 14) / 2
                      : constraints.maxWidth,
                  child: recipeCard(recipe),
                ),
            ],
          ),
        ),
      ],
      gap(18),
      Text(
        '${filtered.length} von ${dinnerRecipes.length} Rezepten',
        style: muted,
      ),
    ];
  }
}
