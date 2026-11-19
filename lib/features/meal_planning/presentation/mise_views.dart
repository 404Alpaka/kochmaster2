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
          child: Stack(children: [ListView(
            key: ValueKey(
              'mise-page-$tab-${dateKey(week)}-${openedRecipe?.id ?? 'overview'}-$surveyStep-${draft != null}-$swappingDay-$shoppingPage-$pantryPage-$householdPage-$cookingPage-$cookingStep-$collectionPage',
            ),
            padding: EdgeInsets.fromLTRB(22, recipeDiscoveryActive ? recipeHeaderHeight + 4 : 18, 22, 28),
            children: [
              if (cookingPage > 0) ...cookingFlow(),
              if (cookingPage == 0) ...[
              if (tab == 5) ...homeView(),
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
              if (tab != 0 && tab != 5) storageStatus(),
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
          if (recipeDiscoveryActive) Positioned(top: 0, left: 0, right: 0, child: recipePinnedHeader()),
          ]),
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
            nav(5, 'Start', Icons.home_outlined),
            nav(0, 'Rezepte', Icons.menu_book_outlined),
            nav(1, 'Plan', Icons.calendar_month_outlined),
            nav(2, 'Vorrat', Icons.kitchen_outlined),
            nav(3, 'Korb', Icons.shopping_cart_outlined),
          ],
        ),
      ),
    ),
      ],
    ),
  );

  Widget nav(int index, String label, IconData icon, {bool enabled = true}) => Expanded(
    child: Semantics(
      selected: tab == index,
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? () => selectTab(index) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 23,
                color: !enabled ? AppColors.muted.withValues(alpha: 0.35) : tab == index ? AppColors.sage : AppColors.muted,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: !enabled ? AppColors.muted.withValues(alpha: 0.35) : tab == index ? AppColors.sage : AppColors.muted,
                  fontWeight: tab == index ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> recipeView() => recipeDiscoveryView();

  void toggleRecipePreference(Set<String> values, Recipe recipe) {
    update(() {
      if (!values.add(recipe.id)) values.remove(recipe.id);
    });
    savePreferences();
  }

  void showRecipeCollection() => update(() { collectionPage = 1; openedRecipe = null; });

  void stopSuggestingRecipe(Recipe recipe) {
    update(() {
      hiddenRecipes.add(recipe.id);
      if (openedRecipe?.id == recipe.id) openedRecipe = null;
    });
    savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Rezept wird nicht mehr vorgeschlagen.'),
      action: SnackBarAction(label: 'Rückgängig', onPressed: () {
        update(() => hiddenRecipes.remove(recipe.id));
        savePreferences();
      }),
    ));
  }

  void recipeMenu(Recipe recipe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(child: Column(
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
                title: Text(rememberedRecipes.contains(recipe.id) ? 'Nicht mehr merken' : 'Merken'),
                leading: Icon(rememberedRecipes.contains(recipe.id) ? Icons.bookmark : Icons.bookmark_border),
                onTap: () {
                  Navigator.pop(context);
                  toggleRecipePreference(rememberedRecipes, recipe);
                },
              ),
              ListTile(
                title: Text(favoriteRecipes.contains(recipe.id) ? 'Aus Favoriten entfernen' : 'Als Favorit speichern'),
                leading: Icon(favoriteRecipes.contains(recipe.id) ? Icons.favorite : Icons.favorite_border),
                onTap: () {
                  Navigator.pop(context);
                  toggleRecipePreference(favoriteRecipes, recipe);
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
                title: const Text('Nicht mehr vorschlagen'),
                leading: const Icon(Icons.visibility_off_outlined),
                onTap: () {
                  Navigator.pop(context);
                  stopSuggestingRecipe(recipe);
                },
              ),
            ],
          )),
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
        if (!featured)
          TextButton.icon(onPressed: () => recipeMenu(recipe),
            icon: const Icon(Icons.more_horiz), label: const Text('Aktionen')),
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
    Widget action(String label, IconData icon, VoidCallback? onPressed, {bool selected = false}) => Expanded(
      child: Semantics(
        selected: selected,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
            minimumSize: const Size(0, 64),
            foregroundColor: selected ? AppColors.sage : AppColors.lightText,
            backgroundColor: selected ? AppColors.softGreen : Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 22),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
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
        child: recipePhoto(recipe, height: recipeImageSource(recipe) == null ? 104 : 240),
      ),
      gap(6),
      if (recipeImageSource(recipe) != null)
        Text(recipeImageCaption(recipe), style: muted.copyWith(fontSize: 10)),
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
      gap(8),
      Text('${recipe.minutes} Min. · ${recipe.ingredients.length} Zutaten', style: muted),
      gap(12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => openCooking(recipe, portions: detailServings),
          icon: const Icon(Icons.restaurant_outlined),
          label: const Text('Jetzt kochen'),
        ),
      ),
      gap(8),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        action(rememberedRecipes.contains(recipe.id) ? 'Gemerkt' : 'Merken',
          rememberedRecipes.contains(recipe.id) ? Icons.bookmark : Icons.bookmark_border,
          () => toggleRecipePreference(rememberedRecipes, recipe), selected: rememberedRecipes.contains(recipe.id)),
        action('Favorit', favoriteRecipes.contains(recipe.id) ? Icons.favorite : Icons.favorite_border,
          () => toggleRecipePreference(favoriteRecipes, recipe), selected: favoriteRecipes.contains(recipe.id)),
        action('Einplanen', Icons.calendar_month_outlined,
          saving || loading || loadError != null ? null : () => addRecipe(recipe, portions: detailServings)),
        action('Ausblenden', Icons.visibility_off_outlined, () => stopSuggestingRecipe(recipe)),
      ]),
      if (personalRecipeRecord(recipe.id) != null) ...[
        gap(12),
        if ((personalRecipeRecord(recipe.id)!['source'] as String? ?? '').isNotEmpty) SelectableText('Quelle: ${personalRecipeRecord(recipe.id)!['source']}', style: muted),
        if ((personalRecipeRecord(recipe.id)!['notes'] as String? ?? '').isNotEmpty) ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Private Notizen'), children: [Align(alignment: Alignment.centerLeft, child: SelectableText(personalRecipeRecord(recipe.id)!['notes'] as String, style: muted))]),
      ],
      if (personalRecipes.any((r) => (r['recipe'] as Map)['id'] == recipe.id)) TextButton(onPressed: () => editPersonalRecipe(personalRecipes.firstWhere((r) => (r['recipe'] as Map)['id'] == recipe.id)), child: const Text('Eigenes Rezept bearbeiten')),
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

  Future<void> pickPlanWeek() async {
    if (saving || loading) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: week,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Woche auswählen',
      confirmText: 'Woche öffnen',
      cancelText: 'Abbrechen',
    );
    if (picked == null || !mounted) return;
    final target = mondayOf(picked);
    final offset = DateTime.utc(target.year, target.month, target.day)
        .difference(DateTime.utc(week.year, week.month, week.day)).inDays ~/ 7;
    if (offset != 0) await changeWeek(offset);
  }

  Widget weekPicker() {
    final current = mondayOf(pantryToday);
    final offset = DateTime.utc(week.year, week.month, week.day)
        .difference(DateTime.utc(current.year, current.month, current.day)).inDays ~/ 7;
    final label = offset == 0 ? 'Diese Woche' : offset == 1 ? 'Nächste Woche' : offset == -1 ? 'Letzte Woche' : offset > 1 ? 'In $offset Wochen' : 'Vor ${-offset} Wochen';
    return Column(children: [Row(
    children: [
      IconButton(
        tooltip: 'Vorherige Woche',
        onPressed: saving || loading ? null : () => changeWeek(-1),
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: TextButton(
          onPressed: saving || loading ? null : pickPlanWeek,
          child: Column(children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text('${displayDate(week)} – ${displayDate(DateTime(week.year, week.month, week.day + 6))}', textAlign: TextAlign.center, style: muted),
            const SizedBox(height: 3),
            const Text('Woche auswählen', style: TextStyle(fontSize: 11)),
          ]),
        ),
      ),
      IconButton(
        tooltip: 'Nächste Woche',
        onPressed: saving || loading ? null : () => changeWeek(1),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
    ),
    if (offset != 0) TextButton(
      onPressed: saving || loading ? null : () => changeWeek(-offset),
      child: const Text('Zur aktuellen Woche'),
    ),
    ]);
  }

  List<Widget> planView() => [
    title('Deine Woche'),
    gap(12),
    weekPicker(),
    gap(12),
    weekActionCard(),
    gap(18),
    primary('Wochenplan bearbeiten', editExistingPlan),
    gap(12),
    TextButton(
      onPressed: () => update(() => surveyStep = 1),
      child: const Text('Planungsantworten ändern'),
    ),
    Row(
      children: [
        Expanded(child: Text('Wochenübersicht', style: Theme.of(context).textTheme.titleLarge)),
        TextButton(onPressed: editBudget, child: const Text('Budget')),
      ],
    ),
    gap(12),
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
                    ? weekSaveUncertain ? 'Speicherstand unklar' : 'Nicht gespeichert'
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
