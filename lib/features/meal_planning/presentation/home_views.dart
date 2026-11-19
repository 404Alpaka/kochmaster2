part of 'planning_page.dart';

extension _HomeViews on _PlanningPageState {
  void openHomeHousehold() {
    selectTab(4);
    update(() => householdPage = 0);
  }

  Future<void> openTodayCooking() async {
    if (loading || saving) return;
    final today = pantryToday;
    final currentWeek = mondayOf(today);
    selectTab(1);
    update(() => selectedDay = today.weekday - 1);
    if (dateKey(week) != dateKey(currentWeek)) {
      final offset = DateTime.utc(currentWeek.year, currentWeek.month, currentWeek.day)
          .difference(DateTime.utc(week.year, week.month, week.day)).inDays ~/ 7;
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
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                gap(5),
                Text('Schön, dass du da bist.', style: muted),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Zum Haushalt',
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
      Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 14) / 2;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: homeShortcut(
                        title: 'Wochenplan',
                        subtitle: '${plan.length} von 7 Tagen geplant',
                        icon: Icons.calendar_month_outlined,
                        color: AppColors.softGreen,
                        size: width,
                        onTap: () => selectTab(1),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: homeShortcut(
                        title: 'Kochen starten',
                          subtitle: todayMeal?.recipe.name ??
                              (dateKey(week) == dateKey(mondayOf(today))
                                  ? 'Heute noch nichts geplant'
                                  : 'Heutigen Plan öffnen'),
                        icon: Icons.restaurant_outlined,
                        recipe: todayMeal?.recipe,
                        color: AppColors.cream,
                        size: width,
                        onTap: openTodayCooking,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      gap(28),
      section(
        'Dein Rezept des Tages',
        action: TextButton(
          onPressed: () => selectTab(0),
          child: const Text('Alle Rezepte'),
        ),
      ),
      if (suggestion != null)
        recipeCard(suggestion, featured: true)
      else
        panel(
          Text(
            'Momentan gibt es keine passenden Vorschläge. Schau dir den Katalog an oder passe deine Planungsregeln an.',
            style: muted,
          ),
        ),
      gap(28),
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

  Widget homeShortcut({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onTap,
    Recipe? recipe,
  }) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: size),
    child: Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (recipe != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: recipePhoto(recipe, height: 64),
                )
              else
                Icon(icon, size: 36, color: AppColors.sage),
              gap(22),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              gap(5),
              Text(subtitle, style: muted),
            ],
          ),
        ),
      ),
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
