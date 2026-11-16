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
  void selectTab(int value) => update(() => tab = value);

  Widget miseScaffold() => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            key: ValueKey('mise-page-$tab'),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            children: [
              if (tab == 0) ...recipeView(),
              if (tab == 1) ...planView(),
              if (tab == 2) ...pantryView(),
              if (tab == 3) ...basketView(),
              if (tab == 4) ...householdView(),
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
    bottomNavigationBar: SafeArea(
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
          (recipeFilter != 1 || r.minutes <= 30) &&
          (recipeFilter != 2 || inStock);
    }).toList();
    return [
      Row(
        children: [
          const Expanded(
            child: Text(
              'mise.',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.8,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => selectTab(4),
            icon: const Icon(Icons.home_outlined, size: 14),
            label: Text(
              '$householdName · $servings Personen',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
      gap(24),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, ?current],
        ),
        child: Text(
          _PlanningPageState.sayings[saying],
          key: ValueKey(saying),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      gap(6),
      Text('Dein Geschmack. Dein Budget. Weniger Reste.', style: muted),
      gap(22),
      TextField(
        controller: searchController,
        decoration: const InputDecoration(
          hintText: 'Rezepte, Zutaten oder Gerichte',
          prefixIcon: Icon(Icons.search, size: 20),
        ),
        onChanged: (value) => update(() => query = value),
      ),
      gap(12),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final (index, label) in [
            (0, 'Für dich'),
            (1, 'Bis 30 Min.'),
            (2, 'Aus Vorrat'),
          ])
            ChoiceChip(
              label: Text(label, style: const TextStyle(fontSize: 12)),
              selected: recipeFilter == index,
              onSelected: (_) => update(() => recipeFilter = index),
              showCheckmark: false,
            ),
        ],
      ),
      gap(20),
      budgetCard(compact: true),
      gap(24),
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

  Widget recipeCard(Recipe recipe, {bool featured = false}) => Card(
    margin: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Recipe records currently have no image field. Keep this slot honest.
        InkWell(
          onTap: () => details(recipe),
          child: Container(
            height: featured ? 175 : 105,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE5EAD8), Color(0xFFF1E7D5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.ramen_dining_outlined,
                size: featured ? 64 : 42,
                color: AppColors.sage.withValues(alpha: .55),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(featured ? 16 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (featured) ...[
                const Text(
                  'FRISCH AUF DEINEN TELLER',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.sage,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
                gap(7),
              ],
              Text(
                recipe.name,
                style: TextStyle(
                  fontSize: featured ? 19 : 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              gap(6),
              Text(
                '${recipe.minutes} Min. · ${recipe.servings} Portionen',
                style: muted,
              ),
              gap(12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: () => details(recipe),
                    child: const Text('Rezept ansehen'),
                  ),
                  FilledButton.icon(
                    onPressed: saving || loading || loadError != null
                        ? null
                        : () => addRecipe(recipe),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Wochenplan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

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
                  onPressed: saving || meal.servings <= 1
                      ? null
                      : () => adjustServings(day, -1),
                  icon: const Icon(Icons.remove, size: 18),
                ),
                Text('${meal.servings} Portionen'),
                IconButton(
                  key: ValueKey('increase-$day'),
                  tooltip: 'Mehr Portionen',
                  onPressed: saving ? null : () => adjustServings(day, 1),
                  icon: const Icon(Icons.add, size: 18),
                ),
                TextButton(
                  onPressed: () => details(meal.recipe),
                  child: const Text('Rezept'),
                ),
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

  List<Widget> pantryView() => [
    title('Dein Vorrat'),
    gap(8),
    Text('Weniger wegwerfen. Mehr draus machen.', style: muted),
    gap(22),
    primary('Lebensmittel erfassen', addPantryItem, icon: Icons.add),
    gap(18),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dein Vorrat kocht mit',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          gap(6),
          Text(
            'Finde Rezepte mit den Zutaten, die du schon zu Hause hast.',
            style: muted,
          ),
          TextButton(
            onPressed: () => update(() {
              recipeFilter = 2;
              query = '';
              searchController.clear();
              tab = 0;
            }),
            child: const Text('Passende Rezepte entdecken →'),
          ),
        ],
      ),
      color: AppColors.cream,
    ),
    gap(18),
    Wrap(
      spacing: 8,
      children: [
        for (final label in ['Alle', 'Kühlschrank', 'Trocken'])
          ChoiceChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            selected: pantryFilter == label,
            onSelected: (_) => update(() => pantryFilter = label),
            showCheckmark: false,
          ),
      ],
    ),
    gap(16),
    panel(
      Column(
        children: [
          if (pantry
              .where(
                (p) => pantryFilter == 'Alle' || p['location'] == pantryFilter,
              )
              .isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Hier ist noch Platz. Erfasse deine ersten Lebensmittel.',
                style: muted,
              ),
            ),
          for (final item in pantry)
            if (pantryFilter == 'Alle' || item['location'] == pantryFilter)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item['name'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${item['amount']} · ${item['location']}',
                  style: muted,
                ),
                trailing: IconButton(
                  tooltip: 'Lebensmittel entfernen',
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: () {
                    update(() => pantry.remove(item));
                    savePreferences();
                  },
                ),
              ),
        ],
      ),
    ),
    gap(18),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('Auch Gekochtes zählt'),
          Text(
            'Reste vom Vortag? Erfasse sie im Vorrat und plane sie für morgen ein.',
            style: muted,
          ),
        ],
      ),
      color: AppColors.softGreen,
    ),
    gap(14),
    Text('Vorräte werden in diesem Browser gespeichert.', style: muted),
  ];

  List<Widget> basketView() {
    final shopping = buildShoppingList(plan.values);
    final done = shopping
        .where((i) => checked.contains((i.ingredientId, i.unit)))
        .length;
    return [
      title('Dein smarter Einkauf'),
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

  Future<void> addPantryItem() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    String location = 'Kühlschrank';
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lebensmittel erfassen'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Lebensmittel'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Bitte ein Lebensmittel eingeben.'
                      : null,
                ),
                gap(12),
                TextFormField(
                  controller: amount,
                  decoration: const InputDecoration(
                    labelText: 'Menge, z. B. 500 g',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Bitte eine Menge eingeben.'
                      : null,
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
                    DropdownMenuItem(value: 'Trocken', child: Text('Trocken')),
                  ],
                  onChanged: (v) => location = v ?? location,
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
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      update(
        () => pantry.add({
          'name': name.text.trim(),
          'amount': amount.text.trim(),
          'location': location,
        }),
      );
      savePreferences();
    }
  }
}
