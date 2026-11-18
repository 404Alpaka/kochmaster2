part of 'planning_page.dart';

extension _MiseViews on _PlanningPageState {
  String euro(double value) =>
      '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
  TextStyle get muted =>
      const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5);
  Widget gap([double size = 20]) => SizedBox(height: size);
  Widget title(String text) =>
      Text(text, style: Theme.of(context).textTheme.headlineMedium);
  Widget section(String text, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?action,
      ],
    ),
  );
  Widget panel(
    Widget child, {
    Color color = Colors.white,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
  Widget primary(
    String text,
    VoidCallback action, {
    IconData icon = Icons.arrow_forward,
  }) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: action,
      icon: Icon(icon, size: 18),
      label: Text(text),
    ),
  );
  void selectTab(int value) => update(() {
    tab = value;
    cookingPage = 0;
    openedRecipe = null;
  });

  Widget miseScaffold() => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            key: ValueKey(
              'mise-page-$tab-${openedRecipe?.id ?? 'overview'}-$surveyStep-${draft != null}-$swappingDay-$shoppingPage-$pantryPage-$householdPage-$cookingPage-$cookingStep-$collectionPage',
            ),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            children: [
              if (cookingPage > 0) ...cookingFlow(),
              if (cookingPage == 0) ...[
              if (cookingRecipe != null && !cookedEntries.contains(cookingKey)) TextButton.icon(onPressed: () => update(() => cookingPage = 1), icon: const Icon(Icons.restaurant), label: const Text('Kochen fortsetzen')),
              if (tab == 0)
                ...openedRecipe == null
                    ? collectionPage == 0 ? recipeView() : recipeCollectionFlow()
                    : recipeDetail(openedRecipe!),
              if(readOnlyShared && tab>=1 && tab<=3) ...sharedReadOnlyFlow(),
              if (!readOnlyShared && tab == 1) ...[
                if (nextWeekHints.containsKey(dateKey(week))) ...[surveyCard('Deine Wünsche für diese Woche', nextWeekHints[dateKey(week)]!['note'] as String? ?? '', color: AppColors.softGreen), gap(14), if (nextWeekHints[dateKey(week)]!['checkPrepared'] == true) ...[recipeAction('Vorhandene Mahlzeiten prüfen →', false, openPreparedMeals), gap(14)]],
                ...planningFlow(),
              ],
              if (!readOnlyShared && tab == 2) ...pantryFlow(),
              if (!readOnlyShared && tab == 3) ...shoppingFlow(),
              if (tab == 4) ...householdFlow(),
              ],
              gap(24),
              if (tab != 0) storageStatus(),
              if (saving) const LinearProgressIndicator(),
              if (loadError != null) ...[
                Text(
                  loadError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: loadWeek,
                  child: const Text('Wochenplan erneut laden'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cookingPage > 0) cookingActionBar(),
        if (cookingPage == 0) ...[
        if (tab == 0 && collectionPage > 0 && openedRecipe == null) recipeCollectionActionBar(),
        if (!readOnlyShared && showPlanningAction) planningActionBar(),
        if (!readOnlyShared && showProposalAction) proposalActionBar(),
        if (!readOnlyShared && tab == 3 && shoppingPage != 1) shoppingActionBar(),
        if (!readOnlyShared && tab == 2 && pantryPage != 0) pantryActionBar(),
        if (tab == 4 && householdPage > 0 && (householdDemoJoined || householdPage >= 5)) householdActionBar(),
        ],
        SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0EB))),
        ),
        child: Row(
          children: [
            nav(0, 'Rezepte', Icons.menu_book_outlined),
            nav(1, 'Plan', Icons.calendar_month_outlined),
            nav(2, 'Vorrat', Icons.kitchen_outlined),
            nav(3, 'Korb', Icons.shopping_cart_outlined),
            nav(4, 'Haushalt', Icons.home_outlined),
          ],
        ),
      ),
    ),
      ],
    ),
  );

  Widget nav(int index, String label, IconData icon) => Expanded(
    child: Semantics(
      selected: tab == index,
      button: true,
      child: InkWell(
        onTap: () => selectTab(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 23,
                color: tab == index ? AppColors.sage : AppColors.muted,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: tab == index ? AppColors.sage : AppColors.muted,
                  fontWeight: tab == index ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> recipeView() {
    final filtered = recipes.where((r) {
      final matches =
          r.name.toLowerCase().contains(query.toLowerCase()) ||
          r.ingredients.any(
            (i) => i.name.toLowerCase().contains(query.toLowerCase()),
          );
      final inStock = r.ingredients.any(
        (i) => pantry.any(
          (p) => (p['name'] as String).toLowerCase() == i.name.toLowerCase(),
        ),
      );
      return matches &&
          !hiddenRecipes.contains(r.id) &&
          (recipeFilter != 1 || rememberedRecipes.contains(r.id)) &&
          (recipeFilter != 2 || favoriteRecipes.contains(r.id)) &&
          (recipeFilter != 3 || inStock);
    }).toList();
    return [
      Row(
        children: [
          const Expanded(
            child: Text(
              'mise.',
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.8,
              ),
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.softGreen,
              foregroundColor: AppColors.lightText,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => selectTab(4),
            icon: const Icon(Icons.home_outlined, size: 14),
            label: Text(
              '$householdName · $servings Personen',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
      gap(14),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, ?current],
        ),
        child: Text(
          _PlanningPageState.sayings[saying],
          key: ValueKey(saying),
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(height: 1.25),
        ),
      ),
      gap(6),
      Text('Dein Geschmack. Dein Budget. Weniger Reste.', style: muted),
      gap(14),
      TextField(
        controller: searchController,
        decoration: const InputDecoration(
          hintText: 'Rezepte, Zutaten oder Gerichte',
          prefixIcon: Icon(Icons.search, size: 18),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        onChanged: (value) => update(() => query = value),
      ),
      gap(14),
      SizedBox(
        width: double.infinity,
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: AppColors.softGreen,
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: showRecipeCollection,
          child: const Text(
            'Meine Rezeptsammlung  →',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      gap(14),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final (index, label) in [
            (0, 'Für dich'),
            (1, 'Gemerkt'),
            (2, 'Favoriten'),
            if (recipeFilter == 3) (3, 'Aus Vorrat'),
          ])
            ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: recipeFilter == index
                      ? Colors.white
                      : AppColors.lightText,
                ),
              ),
              selectedColor: AppColors.sage,
              backgroundColor: AppColors.softGreen,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              selected: recipeFilter == index,
              onSelected: (_) => update(() => recipeFilter = index),
              showCheckmark: false,
            ),
        ],
      ),
      gap(14),
      InkWell(
        onTap: () => selectTab(1),
        borderRadius: BorderRadius.circular(16),
        child: panel(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dein Geschmack. Dein Wochenplan.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    gap(4),
                    Text(
                      'Merke Rezepte, die du gerne kochen möchtest.',
                      style: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                children: [
                  Text(
                    'Zum Plan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 16),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ],
          ),
          color: AppColors.softGreen,
          padding: const EdgeInsets.all(14),
        ),
      ),
      gap(14),
      section(
        'Heute auf deinem Teller',
        action: TextButton(
          onPressed: () => update(() {
            query = '';
            searchController.clear();
            recipeFilter = 0;
          }),
          child: const Text('Alle ansehen', style: TextStyle(fontSize: 12)),
        ),
      ),
      if (filtered.isEmpty)
        panel(
          Text(
            recipes.isEmpty
                ? 'Noch keine veröffentlichten Rezepte vorhanden.'
                : 'Keine passenden Rezepte gefunden.',
            style: muted,
          ),
        ),
      if (filtered.isNotEmpty) recipeCard(filtered.first, featured: true),
      if (filtered.length > 1) ...[
        gap(14),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final recipe in filtered.skip(1))
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
      Text('${filtered.length} von ${recipes.length} Rezepten', style: muted),
      gap(12),
      storageStatus(),
    ];
  }

  void toggleRecipePreference(Set<String> values, Recipe recipe) {
    update(() {
      if (!values.add(recipe.id)) values.remove(recipe.id);
    });
    savePreferences();
  }

  void showRecipeCollection() => update(() { collectionPage = 1; openedRecipe = null; });

  void recipeMenu(Recipe recipe) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Rezept ansehen'),
                leading: const Icon(Icons.menu_book_outlined),
                onTap: () {
                  Navigator.pop(context);
                  details(recipe);
                },
              ),
              ListTile(
                title: const Text('Zum Wochenplan hinzufügen'),
                leading: const Icon(Icons.calendar_month_outlined),
                onTap: saving || loading || loadError != null
                    ? null
                    : () {
                        Navigator.pop(context);
                        addRecipe(recipe);
                      },
              ),
              ListTile(
                title: const Text('Nicht vorschlagen'),
                leading: const Icon(Icons.visibility_off_outlined),
                onTap: () {
                  Navigator.pop(context);
                  update(() => hiddenRecipes.add(recipe.id));
                  savePreferences();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Rezept wird nicht mehr vorgeschlagen.',
                      ),
                      action: SnackBarAction(
                        label: 'Rückgängig',
                        onPressed: () {
                          update(() => hiddenRecipes.remove(recipe.id));
                          savePreferences();
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget recipeCard(Recipe recipe, {bool featured = false}) => Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: 'Rezept ansehen',
          child: InkWell(
            onTap: () => details(recipe),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                recipePhoto(recipe, height: featured ? 198 : 100),
                Padding(
                  padding: EdgeInsets.all(featured ? 13 : 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (featured) ...[
                        Text(
                          recipe.ingredients.any(
                                (i) => pantry.any(
                                  (p) =>
                                      (p['name'] as String).toLowerCase() ==
                                      i.name.toLowerCase(),
                                ),
                              )
                              ? 'PASST ZU DEINEM VORRAT'
                              : 'FRISCH AUF DEINEN TELLER',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF5C783D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        gap(5),
                      ],
                      Text(
                        recipe.name,
                        style: TextStyle(
                          fontSize: featured ? 18 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      gap(4),
                      Text(
                        '${recipe.minutes} Min. · ${recipe.servings} Portionen',
                        style: muted.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (featured)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: recipeAction(
                    rememberedRecipes.contains(recipe.id)
                        ? 'Gemerkt'
                        : 'Merken',
                    rememberedRecipes.contains(recipe.id),
                    () => toggleRecipePreference(rememberedRecipes, recipe),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: recipeAction(
                    'Favorit',
                    favoriteRecipes.contains(recipe.id),
                    () => toggleRecipePreference(favoriteRecipes, recipe),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: recipeAction('Mehr', false, () => recipeMenu(recipe)),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget recipeAction(String label, bool selected, VoidCallback onPressed) =>
      TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: selected ? AppColors.sage : AppColors.softGreen,
          foregroundColor: selected ? Colors.white : AppColors.lightText,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      );

  Widget recipePhoto(Recipe recipe, {required double height}) => RecipeImage(recipeImageSource(recipe), height: height, semanticLabel: 'Rezeptbild für ${recipe.name}');

  List<Widget> recipeDetail(Recipe recipe) {
    final inStock = recipe.ingredients
        .where(
          (item) => pantry.any(
            (p) =>
                (p['name'] as String).toLowerCase() == item.name.toLowerCase(),
          ),
        )
        .length;
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => update(() => openedRecipe = null),
          icon: const Icon(Icons.arrow_back, size: 17),
          label: Text(collectionPage > 0 ? 'Meine Sammlung' : 'Entdecken'),
        ),
      ),
      gap(8),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: recipePhoto(recipe, height: 240),
      ),
      gap(6),
      Text('Stockfoto · Serviervorschlag', style: muted.copyWith(fontSize: 10)),
      gap(16),
      Text(
        inStock > 0 ? 'DEIN VORRAT KOCHT MIT' : 'FRISCH AUF DEINEN TELLER',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: .7,
          color: AppColors.sage,
        ),
      ),
      gap(8),
      title(recipe.name),
      if (personalRecipeRecord(recipe.id) != null) ...[
        gap(12),
        if ((personalRecipeRecord(recipe.id)!['source'] as String? ?? '').isNotEmpty) SelectableText('Quelle: ${personalRecipeRecord(recipe.id)!['source']}', style: muted),
        if ((personalRecipeRecord(recipe.id)!['notes'] as String? ?? '').isNotEmpty) ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Private Notizen'), children: [Align(alignment: Alignment.centerLeft, child: SelectableText(personalRecipeRecord(recipe.id)!['notes'] as String, style: muted))]),
      ],
      if (personalRecipes.any((r) => (r['recipe'] as Map)['id'] == recipe.id)) TextButton(onPressed: () => editPersonalRecipe(personalRecipes.firstWhere((r) => (r['recipe'] as Map)['id'] == recipe.id)), child: const Text('Eigenes Rezept bearbeiten')),
      TextButton.icon(onPressed: () => openCooking(recipe, portions: detailServings), icon: const Icon(Icons.restaurant_outlined), label: const Text('Dieses Gericht kochen')),
      gap(6),
      Text(
        '${recipe.minutes} Min. · ${recipe.servings} Portionen im Original',
        style: muted,
      ),
      gap(18),
      panel(
        Row(
          children: [
            const Icon(Icons.schedule_outlined, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${recipe.minutes} Minuten',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text('${recipe.ingredients.length} Zutaten', style: muted),
          ],
        ),
        color: AppColors.softGreen,
      ),
      gap(20),
      Row(
        children: [
          Expanded(
            child: Text(
              'Zutaten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Weniger Portionen',
            onPressed: detailServings > 1
                ? () => update(() => detailServings--)
                : null,
            icon: const Icon(Icons.remove, size: 16),
          ),
          Text(
            '$detailServings Personen',
            style: const TextStyle(fontSize: 12),
          ),
          IconButton(
            tooltip: 'Mehr Portionen',
            onPressed: detailServings < 30
                ? () => update(() => detailServings++)
                : null,
            icon: const Icon(Icons.add, size: 16),
          ),
        ],
      ),
      gap(10),
      panel(
        Column(
          children: [
            for (final item in recipe.ingredients)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${(item.quantity * detailServings / recipe.servings).toStringAsFixed(1).replaceFirst(RegExp(r"\.0$"), "").replaceAll(".", ",")} ${item.unit} ${item.name}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (pantry.any(
                      (p) =>
                          (p['name'] as String).toLowerCase() ==
                          item.name.toLowerCase(),
                    ))
                      const Text(
                        '✓ Im Vorrat',
                        style: TextStyle(fontSize: 11, color: AppColors.sage),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      gap(16),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'So kommt es auf den Tisch',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            gap(12),
            for (var i = 0; i < recipe.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: AppColors.terracotta,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(renderRecipeStep(recipe, recipe.steps[i], portions: detailServings), style: muted)),
                  ],
                ),
              ),
          ],
        ),
        color: AppColors.cream,
      ),
      gap(18),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: saving || loading || loadError != null
              ? null
              : () => addRecipe(recipe, portions: detailServings),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Zum Wochenplan hinzufügen'),
        ),
      ),
    ];
  }

  Widget budgetCard({bool compact = false}) {
    final remaining = budget - (expenses ?? 0);
    if (compact) {
      return InkWell(
        onTap: editBudget,
        borderRadius: BorderRadius.circular(18),
        child: panel(
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deine Woche schmeckt nach mehr.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    gap(4),
                    Text(
                      expenses == null
                          ? '${euro(budget)} Wochenbudget · Ausgaben eintragen'
                          : '${euro(expenses!)} von ${euro(budget)} erfasst',
                      style: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                expenses == null ? euro(budget) : '${euro(remaining)}\nübrig',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          color: AppColors.softGreen,
        ),
      );
    }
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GUT GEPLANT. IM BUDGET.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          gap(14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  euro(expenses ?? budget),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                expenses == null ? 'Wochenbudget' : 'von ${euro(budget)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          gap(14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: expenses == null || budget <= 0
                  ? 0
                  : (expenses! / budget).clamp(0, 1),
              backgroundColor: const Color(0xFF547F64),
              color: const Color(0xFFB9CEA1),
              minHeight: 6,
            ),
          ),
          gap(10),
          Text(
            expenses == null
                ? 'Trage deine Ausgaben ein, um dein Budget zu verfolgen.'
                : '${euro(remaining.abs())} ${remaining >= 0 ? 'übrig' : 'über Budget'} · selbst erfasste Ausgaben',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
      color: AppColors.sage,
      padding: const EdgeInsets.all(22),
    );
  }

  Widget weekPicker() => Row(
    children: [
      IconButton(
        tooltip: 'Vorherige Woche',
        onPressed: saving || loading ? null : () => changeWeek(-1),
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Text(
          '${displayDate(week)} – ${displayDate(week.add(const Duration(days: 6)))}',
          textAlign: TextAlign.center,
          style: muted,
        ),
      ),
      IconButton(
        tooltip: 'Nächste Woche',
        onPressed: saving || loading ? null : () => changeWeek(1),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  List<Widget> planView() => [
    primary('Wochenplan bearbeiten', editExistingPlan),
    gap(12),
    TextButton(
      onPressed: () => update(() => surveyStep = 1),
      child: const Text('Planungsantworten ändern'),
    ),
    Row(
      children: [
        Expanded(child: title('Deine Woche')),
        TextButton(onPressed: editBudget, child: const Text('Anpassen')),
      ],
    ),
    weekPicker(),
    gap(12),
    budgetCard(),
    gap(20),
    Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => update(() => selectedDay = i),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedDay == i
                        ? AppColors.sage
                        : AppColors.softGreen,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _PlanningPageState.days[i].substring(0, 2),
                        style: TextStyle(
                          fontSize: 11,
                          color: selectedDay == i
                              ? Colors.white
                              : AppColors.muted,
                        ),
                      ),
                      gap(4),
                      Text(
                        '${week.add(Duration(days: i)).day}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selectedDay == i
                              ? Colors.white
                              : AppColors.lightText,
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
    gap(22),
    section(
      '${_PlanningPageState.days[selectedDay]}, ${displayDate(week.add(Duration(days: selectedDay)))}',
    ),
    dayCard(selectedDay),
    gap(18),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Morgen schon mitgedacht',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          gap(6),
          Text(
            'Koche eine Portion mehr und spare morgen Zeit. Passe die Portionen direkt im Plan an.',
            style: muted,
          ),
        ],
      ),
      color: AppColors.cream,
    ),
    gap(18),
    primary('Zum Wocheneinkauf', () => selectTab(3)),
    gap(24),
    section('Deine Woche im Überblick'),
    for (var i = 0; i < 7; i++)
      if (i != selectedDay) ...[dayCard(i), gap(12)],
    Text('${plan.length} von 7 Tagen', style: muted),
    if (widget.store != null || widget.client != null) ...[
      gap(14),
      primary('Wochenplan speichern', () {
        if (widget.store == null) {
          account();
        } else {
          persist(
            Map<int, PlannedMeal>.from(plan),
            Set<(String, String)>.from(checked),
          );
        }
      }, icon: Icons.cloud_upload_outlined),
    ],
  ];

  Widget dayCard(int day) {
    final meal = plan[day];
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _PlanningPageState.days[day].toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              letterSpacing: .8,
            ),
          ),
          gap(10),
          if (meal == null) ...[
            Text(
              'Hier ist noch Platz für Genuss.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            gap(8),
            TextButton.icon(
              onPressed: () => selectTab(0),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Rezept auswählen'),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(
                  Icons.ramen_dining_outlined,
                  size: 34,
                  color: AppColors.sage,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.recipe.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      gap(4),
                      Text(
                        '${meal.recipe.minutes} Min. · ${meal.servings} Portionen',
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            gap(8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  key: ValueKey('decrease-$day'),
                  tooltip: 'Weniger Portionen',
                  onPressed: saving || meal.preparedConsumed || meal.servings <= 1
                      ? null
                      : () => adjustServings(day, -1),
                  icon: const Icon(Icons.remove, size: 18),
                ),
                Text('${meal.servings} Portionen'),
                IconButton(
                  key: ValueKey('increase-$day'),
                  tooltip: 'Mehr Portionen',
                  onPressed: saving || meal.preparedConsumed ? null : () => adjustServings(day, 1),
                  icon: const Icon(Icons.add, size: 18),
                ),
                TextButton(
                  onPressed: () => details(meal.recipe),
                  child: const Text('Rezept'),
                ),
                if (meal.preparedMealId != null) TextButton.icon(onPressed: saving || meal.preparedConsumed ? null : () => consumePreparedMeal(day), icon: const Icon(Icons.check), label: Text(meal.preparedConsumed ? 'Gegessen ✓' : 'Als gegessen markieren')),
                if (meal.preparedMealId == null) TextButton.icon(onPressed: () => openCooking(meal.recipe, portions: meal.servings, day: day), icon: const Icon(Icons.restaurant_outlined, size: 18), label: Text(cookedEntries.contains('${dateKey(week.add(Duration(days: day)))}:${meal.recipe.id}') ? 'Gekocht ✓' : 'Kochen starten')),
                if (meal.preparedMealId == null) TextButton(onPressed: saving ? null : () => openHouseholdMeals(day: day), child: const Text('Pro Person planen')),
                IconButton(
                  key: ValueKey('remove-$day'),
                  tooltip: 'Gericht entfernen',
                  onPressed: saving
                      ? null
                      : () => saveMeals(
                          Map<int, PlannedMeal>.from(plan)..remove(day),
                        ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> selfShoppingView() {
    final shopping = buildShoppingList(plan.values);
    final done = shopping
        .where((i) => checked.contains((i.ingredientId, i.unit)))
        .length;
    return [
      proposalBack('Zurück zum Warenkorb', () => update(() => shoppingPage = 0)),
      title('Deine Einkaufsliste'),
      gap(8),
      Text('${shopping.length} Zutaten · Für euren Wochenplan', style: muted),
      gap(20),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alles drin. Gut vorbereitet.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            gap(6),
            Text(
              'Mengen aus allen Gerichten gebündelt und an deine Portionen angepasst.',
              style: muted,
            ),
          ],
        ),
        color: AppColors.softGreen,
      ),
      gap(16),
      weekPicker(),
      gap(16),
      section('Deine Einkaufsliste'),
      panel(
        Column(
          children: [
            if (shopping.isEmpty) ...[
              Text(
                'Plane zuerst ein Rezept. Deine Zutaten erscheinen dann hier.',
                style: muted,
              ),
              TextButton(
                onPressed: () => selectTab(0),
                child: const Text('Rezepte entdecken'),
              ),
            ],
            for (final item in shopping)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.trailing,
                title: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: checked.contains((item.ingredientId, item.unit))
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Text(
                  '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                  style: muted,
                ),
                value: checked.contains((item.ingredientId, item.unit)),
                onChanged: saving || loading || loadError != null
                    ? null
                    : (value) {
                        final next = Set<(String, String)>.from(checked);
                        if (value == true) {
                          next.add((item.ingredientId, item.unit));
                        } else {
                          next.remove((item.ingredientId, item.unit));
                        }
                        persist(Map<int, PlannedMeal>.from(plan), next);
                      },
              ),
          ],
        ),
      ),
      gap(12),
      Text('$done von ${shopping.length} Zutaten erledigt', style: muted),
      gap(20),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            section('So wird aus Planung ein Einkauf'),
            Text(
              'Prüfe deinen Vorrat vor dem Einkauf. Du kannst vorhandene Zutaten in der Liste abhaken.',
              style: muted,
            ),
          ],
        ),
        color: AppColors.cream,
      ),
      gap(20),
      budgetCard(compact: true),
      gap(14),
      Text(
        'Preise und Händlerangebote sind noch nicht verbunden.',
        style: muted,
      ),
    ];
  }

  List<Widget> householdView() => [
    title('Zusammen isst’s besser.'),
    gap(8),
    Text('Ein Haushalt. Ein Plan. Eure Ziele.', style: muted),
    gap(22),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  householdName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: editHousehold,
                child: const Text(
                  'Ändern',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          Text(
            '$servings Personen',
            style: const TextStyle(color: Colors.white),
          ),
          gap(12),
          Text(
            '${euro(budget)} / Woche',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
      color: AppColors.sage,
    ),
    gap(24),
    section(
      'Euer Wochenbudget',
      action: TextButton(
        onPressed: editBudget,
        child: const Text('Bearbeiten'),
      ),
    ),
    budgetCard(compact: true),
    gap(24),
    section('So teilt ihr euch die Woche'),
    panel(
      Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Rezepte entdecken'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => selectTab(0),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Die Woche planen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => selectTab(1),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.shopping_cart_outlined),
            title: const Text('Einkauf prüfen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => selectTab(3),
          ),
        ],
      ),
      color: AppColors.softGreen,
    ),
    gap(24),
    section(
      'Für alle passend',
      action: TextButton(onPressed: editHousehold, child: const Text('Ändern')),
    ),
    Text(preferences, style: muted),
    gap(6),
    Text(
      'Vorlieben sind eine persönliche Notiz. Eine automatische Allergieprüfung ist noch nicht verfügbar.',
      style: muted,
    ),
    gap(24),
    section('Haushalt gemeinsam verwalten'),
    recipeAction('Mitglieder, Rollen & Einladungen', false, () => update(() => householdPage = 1)),
    gap(12),
    recipeAction('Gemeinsame & persönliche Vorlieben', false, () => update(() => householdPage = 5)),
    gap(12),
    recipeAction('Gerichte & Portionen pro Person', false, openHouseholdMeals),
    gap(12),
    recipeAction('Ausschlüsse & Abneigungen', false, () => update(() => householdPage = 7)),
    gap(24),
    recipeAction('Wochenrückblick · Plan & Ist', false, () => update(() => householdPage = 11)),
    gap(24),
    section('Dein Konto'),
    if (widget.user?.email != null) Text(widget.user!.email!, style: muted),
    if (widget.client != null)
      primary(
        widget.user == null ? 'Anmelden oder registrieren' : 'Abmelden',
        () {
          if (widget.user == null) {
            account();
          } else {
            signOut();
          }
        },
        icon: Icons.person_outline,
      ),
    if (admin)
      TextButton.icon(
        onPressed: manageRecipes,
        icon: const Icon(Icons.admin_panel_settings_outlined),
        label: const Text('Rezepte verwalten'),
      ),
    gap(14),
    Text(
      'Haushaltseinstellungen und Vorräte gelten für diesen Browser. Gemeinsame Haushaltsfreigaben sind noch nicht eingerichtet.',
      style: muted,
    ),
  ];

  Widget storageStatus() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.store != null)
        Row(
          children: [
            Icon(
              saveError == null
                  ? Icons.cloud_done_outlined
                  : Icons.error_outline,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                saving
                    ? 'Wird gespeichert …'
                    : saveError != null
                    ? 'Nicht gespeichert'
                    : loading
                    ? 'Wird geladen …'
                    : 'Gespeichert',
                key: const ValueKey('save-status'),
                style: muted,
              ),
            ),
            IconButton(
              tooltip: 'Gespeicherten Wochenplan neu laden',
              onPressed: saving ? null : loadWeek,
              icon: const Icon(Icons.refresh, size: 18),
            ),
          ],
        ),
      if (saveError != null)
        Text(
          saveError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      Text(
        widget.isDemo
            ? 'Demo · Beispieldaten · Dein Plan bleibt bis zum Neustart erhalten.'
            : widget.user == null
            ? 'Rezepte aus der Datenbank · Zum Speichern bitte anmelden.'
            : 'Dein Wochenplan und Einkaufsstatus werden in deinem Konto gespeichert.',
        style: muted,
      ),
    ],
  );

  Future<void> editBudget() async {
    final target = TextEditingController(
      text: budget.toStringAsFixed(2).replaceAll('.', ','),
    );
    final spent = TextEditingController(
      text: expenses?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
    );
    final form = GlobalKey<FormState>();
    double? number(String? value) =>
        double.tryParse((value ?? '').replaceAll(',', '.'));
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dein Wochenbudget'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: target,
                decoration: const InputDecoration(
                  labelText: 'Wochenbudget in €',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) =>
                    number(v) == null || !number(v)!.isFinite || number(v)! <= 0
                    ? 'Bitte einen Betrag größer als 0 eingeben.'
                    : null,
              ),
              gap(12),
              TextFormField(
                controller: spent,
                decoration: const InputDecoration(
                  labelText: 'Erfasste Ausgaben in € (optional)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => v == null || v.isEmpty
                    ? null
                    : number(v) == null ||
                          !number(v)!.isFinite ||
                          number(v)! < 0
                    ? 'Bitte einen gültigen Betrag eingeben.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      update(() {
        budget = number(target.text)!;
        expenses = number(spent.text);
      });
      savePreferences();
    }
    // Controllers stay alive until the dialog's closing animation completes.
  }

  Future<void> editHousehold() async {
    final name = TextEditingController(text: householdName);
    final people = TextEditingController(text: '$servings');
    final notes = TextEditingController(text: preferences);
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unser Zuhause'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Haushaltsname'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Bitte einen Namen eingeben.'
                      : null,
                ),
                gap(12),
                TextFormField(
                  controller: people,
                  decoration: const InputDecoration(labelText: 'Personen'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ||
                          int.parse(v!) < 1 ||
                          int.parse(v) > 30
                      ? 'Bitte 1 bis 30 Personen eingeben.'
                      : null,
                ),
                gap(12),
                TextFormField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Vorlieben und Allergien',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      update(() {
        householdName = name.text.trim();
        servings = int.parse(people.text);
        preferences = notes.text.trim();
      });
      savePreferences();
    }
  }

  Future<void> addPantryItem() => editPantryProduct();
}
