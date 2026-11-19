part of 'planning_page.dart';

extension _WeekActionCard on _PlanningPageState {
  Widget weekActionCard() {
    final date = week.add(Duration(days: selectedDay));
    final isToday = dateKey(date) == dateKey(pantryToday);
    final meal = plan[selectedDay];
    final cooked =
        meal != null &&
        (meal.preparedMealId != null
            ? meal.preparedConsumed
            : cookedEntries.contains('${dateKey(date)}:${meal.recipe.id}'));
    final blocked =
        loading ||
        saving ||
        (plan.isNotEmpty && (loadError != null || weekConflict)) ||
        readOnlyShared;
    final heading = plan.isEmpty
        ? 'Wochenplan erstellen'
        : cooked
        ? (isToday ? 'Heute erledigt ✓' : 'Bereits erledigt ✓')
        : isToday
        ? 'Heute auf dem Teller'
        : '${_PlanningPageState.days[selectedDay]} auf dem Teller';
    final action = plan.isEmpty
        ? 'Los geht’s'
        : meal == null
        ? 'Gericht hinzufügen'
        : cooked
        ? 'Rezept ansehen'
        : meal.preparedMealId != null
        ? 'Als gegessen markieren'
        : 'Jetzt kochen';
    void open() {
      if (plan.isEmpty) {
        startPlanning();
      } else if (meal == null) {
        selectTab(0);
      } else if (cooked) {
        details(meal.recipe);
      } else if (meal.preparedMealId != null) {
        consumePreparedMeal(selectedDay);
      } else {
        openCooking(meal.recipe, portions: meal.servings, day: selectedDay);
      }
    }

    return Material(
      color: AppColors.sage,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('week-primary-action'),
        onTap: blocked ? null : open,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              gap(7),
              Text(
                plan.isEmpty
                    ? '${displayDate(week)} – ${displayDate(week.add(const Duration(days: 6)))}'
                    : '${_PlanningPageState.days[selectedDay]} · ${displayDate(date)}',
                style: const TextStyle(color: Color(0xFFD5E3C8), fontSize: 13),
              ),
              gap(18),
              if (meal != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: recipePhoto(meal.recipe, height: 165),
                ),
                gap(14),
                Text(
                  meal.recipe.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                gap(6),
                Text(
                  '${meal.recipe.minutes} Min. · ${meal.servings} Portionen${meal.preparedMealId != null ? ' · vorbereitet' : ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ] else
                Text(
                  plan.isEmpty
                      ? 'Deine Vorlieben, deine Woche. Erstelle einen Vorschlag und passe ihn nach deinem Geschmack an.'
                      : isToday
                      ? 'Heute ist nichts geplant. Wähle ein Gericht oder genieße deinen freien Tag.'
                      : 'An diesem Tag ist nichts geplant. Du kannst jederzeit ein Gericht hinzufügen.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              gap(20),
            if (loadError != null && plan.isEmpty) ...[
              const Text(
                'Der gespeicherte Plan konnte nicht geladen werden. Du kannst einen Vorschlag vorbereiten; zum Speichern muss der Ladefehler zuerst behoben werden.',
                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              ),
              gap(14),
            ],
              Row(
                children: [
                  Icon(
                    cooked
                        ? Icons.check_circle_outline
                        : meal == null
                        ? Icons.add_circle_outline
                        : Icons.restaurant_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      action,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (blocked)
                    const Icon(
                      Icons.lock_outline,
                      color: Colors.white,
                      size: 18,
                    )
                  else
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 20,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
