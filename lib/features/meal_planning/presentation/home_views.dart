part of 'planning_page.dart';

extension _HomeViews on _PlanningPageState {
  Future<bool> editFoodPreferences() async {
    final result = await Navigator.of(context).push<FoodPreferences>(
      MaterialPageRoute(
        builder: (_) => FoodPreferencesPage(
          initial: FoodPreferences(
            diet: diet,
            exclusions: {...exclusions},
            servings: servings,
            days: planningDays,
            minutes: maxMinutes,
            budget: planBudgetInitialized ? planBudget : budget,
          ),
        ),
      ),
    );
    if (result == null || !mounted) return false;
    update(() {
      diet = result.diet;
      exclusions
        ..clear()
        ..addAll(result.exclusions);
      servings = result.servings;
      planningDays = result.days;
      startDay = startDay.clamp(0, 7 - planningDays);
      maxMinutes = result.minutes;
      planBudget = result.budget;
      planBudgetInitialized = true;
      if (result.budget != null) budget = result.budget!;
      surveyCompleted = true;
    });
    savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Präferenzen für neue Wochenplanvorschläge übernommen.'),
      ),
    );
    return true;
  }

  Widget foodPreferencesCard() => LayoutBuilder(
    builder: (context, constraints) => ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: constraints.maxWidth < 380 ? constraints.maxWidth : 320,
      ),
      child: Material(
        color: AppColors.sage,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('food-preferences-card'),
          onTap: editFoodPreferences,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: Colors.white, size: 34),
                    Spacer(),
                    Icon(Icons.arrow_outward_rounded, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'So isst du',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Deine Wünsche. Dein Wochenplan.',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  '$diet · $servings ${servings == 1 ? 'Person' : 'Personen'} · $planningDays Tage',
                  style: const TextStyle(color: Colors.white, height: 1.5),
                ),
                Text(
                  '${maxMinutes == 0 ? 'Flexible Kochzeit' : 'Bis $maxMinutes Min.'} · ${planBudgetInitialized && planBudget == null ? 'Ohne Budgetlimit' : '${euro(planBudgetInitialized ? planBudget! : budget)} pro Woche'}',
                  style: const TextStyle(color: Colors.white, height: 1.5),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Essenspräferenzen festlegen →',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  void openHomeHousehold() {
    selectTab(4);
    update(() => householdPage = 0);
  }

  Future<void> openTodayCooking() async {
    if (loading || saving) return;
    if (cookingRecipe != null && !cookedEntries.contains(cookingKey)) {
      update(() => cookingPage = cookingStep > 0 ? 2 : 1);
      unawaited(CookingRuntime.enableKeepScreenOn());
      return;
    }
    final today = pantryToday;
    final currentWeek = mondayOf(today);
    selectTab(1);
    update(() => selectedDay = today.weekday - 1);
    if (dateKey(week) != dateKey(currentWeek)) {
      final offset =
          DateTime.utc(
            currentWeek.year,
            currentWeek.month,
            currentWeek.day,
          ).difference(DateTime.utc(week.year, week.month, week.day)).inDays ~/
          7;
      await changeWeek(offset);
      if (!mounted) return;
    }
    if (loadError != null) return;
    final meal = plan[today.weekday - 1];
    if (meal == null) return;
    if (cookedEntries.contains('${dateKey(today)}:${meal.recipe.id}') ||
        meal.preparedConsumed) {
      details(meal.recipe);
    } else if (meal.preparedMealId != null) {
      // Prepared portions are handled in the plan instead of cooked again.
      return;
    } else {
      await openCooking(
        meal.recipe,
        portions: meal.servings,
        day: today.weekday - 1,
      );
    }
  }

  List<Widget> homeView() {
    final name = widget.user?.userMetadata?['first_name'];
    final firstName = name is String ? name.trim() : '';
    final candidates = recipes
        .where((recipe) => recipeMatchesPlanning(recipe))
        .toList();
    final today = DateTime.now();
    final dayNumber = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(2026)).inDays;
    final suggestion = candidates.isEmpty
        ? null
        : candidates[dayNumber % candidates.length];
    final todayMeal = dateKey(week) == dateKey(mondayOf(today))
        ? plan[today.weekday - 1]
        : null;
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName.isEmpty ? 'Hallo!' : 'Hallo, $firstName!',
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.8,
                  ),
                ),
                gap(5),
                Text(
                  'Schön, dass du da bist.',
                  style: muted.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Zum Profil',
            onPressed: openHomeHousehold,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.softGreen,
              foregroundColor: AppColors.sage,
              fixedSize: const Size(52, 52),
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.person_outline, size: 28),
          ),
        ],
      ),
      gap(28),
      Text(
        'Dein Alltag. Gut geplant.',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      gap(14),
      homePlanCard(),
      gap(12),
      homeCookingCard(
        cookingRecipe != null && !cookedEntries.contains(cookingKey)
            ? cookingRecipe
            : todayMeal?.recipe,
        cookingRecipe != null && !cookedEntries.contains(cookingKey)
            ? 'Schritt ${cookingStep + 1} von ${cookingRecipe!.steps.length} · ${cookingRecipe!.name}'
            : todayMeal?.recipe.name ??
                  (dateKey(week) == dateKey(mondayOf(today))
                      ? 'Heute noch nichts geplant'
                      : 'Heutigen Plan öffnen'),
      ),
      gap(24),
      section(
        'Dein Rezept des Tages',
        action: TextButton(
          onPressed: () => selectTab(0),
          child: const Text('Alle Rezepte'),
        ),
      ),
      if (suggestion != null)
        homeRecipeCard(suggestion)
      else
        panel(
          Text(
            'Momentan gibt es keine passenden Vorschläge. Schau dir den Katalog an oder passe deine Planungsregeln an.',
            style: muted,
          ),
        ),
      gap(28),
      if (!surveyCompleted) ...[foodPreferencesCard(), gap(28)],
      section('Für deine Woche'),
      if (candidates.length > 1) ...[
        for (final recipe
            in candidates.where((r) => r.id != suggestion?.id).take(2)) ...[
          panel(
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.softGreen,
                child: Icon(Icons.restaurant_outlined, color: AppColors.sage),
              ),
              title: Text(recipe.name),
              subtitle: Text(
                '${recipe.minutes} Min. · ${recipe.servings} Portionen',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                selectTab(0);
                details(recipe);
              },
            ),
          ),
          gap(10),
        ],
      ],
      homeNotice(
        Icons.calendar_today_outlined,
        plan.isEmpty
            ? 'Deine Woche ist noch frei'
            : '${plan.length} Abendessen sind geplant',
        '${displayDate(week)} – ${displayDate(week.add(const Duration(days: 6)))} · Öffne deinen Wochenplan.',
        () => selectTab(1),
      ),
      gap(10),
      homeNotice(
        Icons.kitchen_outlined,
        pantry.isEmpty
            ? 'Was hast du noch zu Hause?'
            : '${pantry.length} Einträge in deinem Vorrat',
        'Behalte deine Vorräte im Blick, bevor du einkaufst.',
        () => selectTab(2),
      ),
      if (widget.user == null && widget.client != null) ...[
        gap(10),
        homeNotice(
          Icons.person_outline,
          'Deine Planung auf allen Geräten',
          'Melde dich an, um deine persönlichen Daten zu speichern.',
          account,
        ),
      ],
    ];
  }

  static const _homeGreen = Color(0xFF193F35);

  Widget homePlanCard() => Material(
    color: _homeGreen,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => selectTab(1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.event_available_outlined,
                color: Color(0xFFDCE8AF),
                size: 27,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Wochenplan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${plan.length} / 7',
                        style: const TextStyle(
                          color: Color(0xFFDCE8AF),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  gap(8),
                  Text(
                    '${plan.length} von 7 Tagen geplant',
                    style: const TextStyle(
                      color: Color(0xFFBDCDC4),
                      fontSize: 14,
                    ),
                  ),
                  gap(9),
                  Row(
                    children: [
                      for (var day = 0; day < 7; day++) ...[
                        if (day > 0) const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: plan.containsKey(day)
                                  ? const Color(0xFFDCE8AF)
                                  : Colors.white.withValues(alpha: .22),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget homeCookingCard(Recipe? recipe, String subtitle) => Material(
    color: Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSurface
        : const Color(0xFFF0EEDF),
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: openTodayCooking,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 88,
                height: 88,
                child: recipe != null
                    ? recipePhoto(recipe, height: 88)
                    : const ColoredBox(
                        color: AppColors.softGreen,
                        child: Icon(
                          Icons.restaurant_outlined,
                          color: _homeGreen,
                          size: 32,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cookingRecipe != null && !cookedEntries.contains(cookingKey)
                        ? 'Kochvorgang fortsetzen'
                        : 'Kochen starten',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  gap(5),
                  Text(subtitle, style: muted.copyWith(fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: _homeGreen),
          ],
        ),
      ),
    ),
  );

  Widget homeRecipeCard(Recipe recipe) => Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(
        color: Theme.of(context).dividerColor.withValues(alpha: .15),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            Tooltip(
              message: 'Rezept ansehen',
              child: InkWell(
                onTap: () => details(recipe),
                child: LayoutBuilder(
                  builder: (context, constraints) => recipePhoto(
                    recipe,
                    height: (constraints.maxWidth * .65).clamp(180, 360),
                  ),
                ),
              ),
            ),
            Positioned(top: 14, right: 14, child: recipeHeartButton(recipe)),
          ],
        ),
        InkWell(
          onTap: () => details(recipe),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 17, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FRISCH AUF DEINEN TELLER',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF63734D),
                  ),
                ),
                gap(9),
                Text(
                  recipe.name,
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                gap(10),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 16,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 7),
                        Text('${recipe.minutes} Min.', style: muted),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 17,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 7),
                        Text('${recipe.servings} Portionen', style: muted),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget homeNotice(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => panel(
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.sage),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
