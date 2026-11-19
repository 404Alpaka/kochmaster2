import '../../recipes/domain/recipe.dart';
import 'planning_resources.dart';
import 'planning_diner.dart';

/// Dates are compared as calendar days, independent of DST and time of day.
int calendarDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

class PlanningOccurrence {
  const PlanningOccurrence(this.recipeId, this.date, {this.skipped = false});
  final String recipeId;
  final DateTime date;
  final bool skipped;
}

class PlannerProfile {
  const PlannerProfile({
    this.diet = 'Ohne Einschränkung',
    this.exclusions = const {},
    this.hidden = const {},
    this.ratings = const {},
    this.favorites = const {},
    this.cooked = const {},
    this.tasteAdjustments = const {},
    this.effortPenalties = const {},
    this.resources = const PlanningResources(),
    this.diners = const [],
  });
  final PlanningResources resources;
  final List<PlanningDiner> diners;
  final String diet;
  final Set<String> exclusions, hidden, favorites, cooked;
  final Map<String, int> ratings;
  final Map<String, double> tasteAdjustments, effortPenalties;
}

class PlannerDay {
  const PlannerDay(
    this.date, {
    this.maxMinutes = 0,
    this.maxActiveMinutes = 0,
    this.servings = 2,
  }) : assert(servings > 0),
       assert(maxMinutes >= 0),
       assert(maxActiveMinutes >= 0);
  final DateTime date;
  final int maxMinutes;
  final int maxActiveMinutes;
  final int servings;
}

class PlannerResult {
  const PlannerResult(this.recipes, this.reasons, this.warnings, this.seed);
  final Map<int, Recipe> recipes;
  final Map<int, List<String>> reasons;
  final List<String> warnings;
  final int seed;
}

class WeeklyPlanner {
  const WeeklyPlanner({this.beamWidth = 50}) : assert(beamWidth > 0);
  final int beamWidth;

  bool repeats(
    Recipe recipe,
    DateTime date,
    Iterable<PlanningOccurrence> history,
  ) => history.any(
    (h) =>
        !h.skipped &&
        h.recipeId == recipe.id &&
        (calendarDay(date) - calendarDay(h.date)).abs() < 30,
  );

  bool eligible(
    Recipe recipe,
    PlannerDay day,
    PlannerProfile profile,
    Iterable<PlanningOccurrence> history, {
    bool allowRepeats = false,
  }) =>
      isDinnerRecipe(recipe) &&
      recipe.ingredients.isNotEmpty &&
      (profile.diners.isEmpty || profile.diners.any((d) => d.participates)) &&
      profile.diners
          .where((d) => d.participates)
          .every((d) => d.allows(recipe)) &&
      (day.maxActiveMinutes == 0 ||
          (recipe.activeMinutes != null &&
              recipe.activeMinutes! <= day.maxActiveMinutes)) &&
      !profile.hidden.contains(recipe.id) &&
      profile.ratings[recipe.id] != 1 &&
      (day.maxMinutes == 0 || recipe.minutes <= day.maxMinutes) &&
      matchesVerifiedRestrictions(recipe, profile.diet, profile.exclusions) &&
      (allowRepeats || !repeats(recipe, day.date, history));

  double learnedTaste(
    Recipe recipe,
    List<Recipe> catalog,
    PlannerProfile profile,
  ) {
    final features = <String>{
      ...recipe.flavors.map((f) => 'flavor:$f'),
      if (recipe.dishType != null) 'dish:${recipe.dishType}',
      if (recipe.mainIngredient != null) 'main:${recipe.mainIngredient}',
    };
    final observations = <double>[];
    for (final other in {for (final r in catalog) r.id: r}.values) {
      final rating = profile.ratings[other.id];
      if (rating == null || other.id == recipe.id) continue;
      final otherFeatures = <String>{
        ...other.flavors.map((f) => 'flavor:$f'),
        if (other.dishType != null) 'dish:${other.dishType}',
        if (other.mainIngredient != null) 'main:${other.mainIngredient}',
      };
      if (features.intersection(otherFeatures).isNotEmpty) {
        observations.add((rating - 3) * 5.0);
      }
    }
    return observations.length < 3
        ? 0
        : (observations.reduce((a, b) => a + b) / observations.length).clamp(
            -10,
            10,
          );
  }

  double score(
    Recipe recipe,
    PlannerDay day,
    PlannerProfile profile, {
    double? pantryScore,
    int plannedServings = 0,
  }) {
    final rating = profile.ratings[recipe.id];
    final taste =
        ((rating == null
                    ? 50.0
                    : const {2: 15.0, 3: 50.0, 4: 80.0, 5: 100.0}[rating] ??
                          0) +
                (profile.favorites.contains(recipe.id) ? 5 : 0) +
                (profile.tasteAdjustments[recipe.id] ?? 0))
            .clamp(0, 100);
    final time = day.maxMinutes == 0
        ? 70.0
        : (100 - 30 * recipe.minutes / day.maxMinutes).clamp(0, 100);
    final stockWeight = profile.resources.hasStock ? 15 : 0;
    final budgetWeight = profile.resources.hasBudget ? 10 : 0;
    final stockFit =
        pantryScore ??
        profile.resources.pantryScores(
          {0: recipe},
          {0: (day.date, day.servings)},
        )[0] ??
        50;
    return (50 * taste +
            20 *
                (time - (profile.effortPenalties[recipe.id] ?? 0)).clamp(
                  0,
                  100,
                ) +
            stockWeight * stockFit +
            budgetWeight *
                profile.resources.budgetScore(
                  recipe,
                  day.servings,
                  plannedServings == 0 ? day.servings : plannedServings,
                ) +
            5 * (profile.cooked.contains(recipe.id) ? 50 : 70)) /
        (75 + stockWeight + budgetWeight);
  }

  PlannerResult generate({
    required List<Recipe> catalog,
    required Map<int, PlannerDay> days,
    required PlannerProfile profile,
    List<PlanningOccurrence> history = const [],
    Map<int, Recipe> fixed = const {},
    bool allowRepeats = false,
    int seed = 0,
  }) {
    final pool = {for (final r in catalog) r.id: r}.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final candidates = {
      for (final d in days.entries)
        if (!fixed.containsKey(d.key))
          d.key: pool
              .where(
                (r) =>
                    eligible(
                      r,
                      d.value,
                      profile,
                      history,
                      allowRepeats: allowRepeats,
                    ) &&
                    !fixed.entries.any(
                      (f) =>
                          f.value.id == r.id &&
                          (calendarDay(days[f.key]!.date) -
                                      calendarDay(d.value.date))
                                  .abs() <
                              30,
                    ),
              )
              .toList(),
    };
    final order = candidates.keys.toList()
      ..sort((a, b) {
        final c = candidates[a]!.length.compareTo(candidates[b]!.length);
        return c == 0 ? a.compareTo(b) : c;
      });
    var beam = [Map<int, Recipe>.from(fixed)];
    final plannedServings = days.values.fold<int>(
      0,
      (sum, d) => sum + d.servings,
    );
    final baseScores = {
      for (final d in days.entries)
        d.key: {
          for (final r in [...pool, ...fixed.values])
            r.id: score(
              r,
              d.value,
              profile,
              pantryScore: 50,
              plannedServings: plannedServings,
            ),
        },
    };
    final scoreCache = Expando<double>();
    double evaluate(Map<int, Recipe> meals) {
      var total = 0.0;
      final sides = <String, int>{},
          types = <String, int>{},
          ingredients = <String, int>{};
      var discoveries = 0;
      for (final e in meals.entries) {
        total += baseScores[e.key]![e.value.id]!;
        if (!profile.cooked.contains(e.value.id)) discoveries++;
        final side = e.value.primarySide;
        if (side != null && side != 'none') {
          sides[side] = (sides[side] ?? 0) + 1;
        }
        final type = e.value.dishType;
        if (type != null) types[type] = (types[type] ?? 0) + 1;
        for (final i
            in e.value.ingredients.map((i) => i.ingredientId).toSet()) {
          ingredients[i] = (ingredients[i] ?? 0) + 1;
        }
        for (final other in meals.entries.where(
          (o) =>
              o.key < e.key &&
              (calendarDay(days[e.key]!.date) - calendarDay(days[o.key]!.date))
                      .abs() ==
                  1,
        )) {
          if (side != null &&
              side != 'none' &&
              side == other.value.primarySide) {
            total -= 12;
          }
          if (e.value.mainIngredient != null &&
              e.value.mainIngredient == other.value.mainIngredient) {
            total -= 10;
          }
        }
      }
      for (final n in [...sides.values, ...types.values]) {
        if (n > 2) total -= (n - 2) * 18;
      }
      total += ingredients.values.where((n) => n == 2).length.clamp(0, 4) * 2;
      final target = days.length < 2 ? days.length : 2;
      total -= (discoveries - target).abs() * 4;
      if (profile.resources.hasStock) {
        final stockScores = profile.resources.pantryScores(meals, {
          for (final d in days.entries) d.key: (d.value.date, d.value.servings),
        });
        final denominator = 90 + (profile.resources.hasBudget ? 10 : 0);
        total += stockScores.values.fold<double>(
          0,
          (sum, s) => sum + (s - 50) * 15 / denominator,
        );
      }
      return total;
    }

    double value(Map<int, Recipe> meals) =>
        scoreCache[meals] ??= evaluate(meals);

    String signature(Map<int, Recipe> m) =>
        (m.keys.toList()..sort()).map((k) => '$k:${m[k]!.id}').join('|');
    int tie(Map<int, Recipe> m) =>
        signature(m).codeUnits
            .fold(seed & 0x7fffffff, (a, b) => (a * 31 + b) & 0x7fffffff);
    for (final day in order) {
      final next = <Map<int, Recipe>>[];
      for (final partial in beam) {
        for (final r in candidates[day]!) {
          if (partial.values.any((v) => v.id == r.id)) continue;
          next.add({...partial, day: r});
        }
        next.add({
          ...partial,
        }); // Keep a valid partial plan if constraints exhaust the pool.
      }
      next.sort((a, b) {
        final count = b.length.compareTo(a.length);
        if (count != 0) return count;
        final s = value(b).compareTo(value(a));
        if (s != 0) return s;
        for (final day in days.keys.toList()..sort()) {
          if (a.containsKey(day) != b.containsKey(day)) {
            return a.containsKey(day) ? -1 : 1;
          }
        }
        return tie(a).compareTo(tie(b));
      });
      beam = next.take(beamWidth).toList();
    }
    final best = beam.first;
    final warnings = <String>[];
    if (profile.diners.isNotEmpty &&
        !profile.diners.any((d) => d.participates)) {
      warnings.add(
        'Keine mitessende Person ausgewählt. Bitte die Auswahl im Haushalt prüfen.',
      );
    }
    final unknownDiners = profile.diners
        .where((d) => d.participates && !d.rulesKnown)
        .toList();
    if (unknownDiners.isNotEmpty) {
      warnings.add(
        'Für ${unknownDiners.map((d) => d.name).join(', ')} fehlen bestätigte Ernährungsregeln. Bitte die Angaben im Haushalt ergänzen.',
      );
    }
    final stockScores = profile.resources.pantryScores(best, {
      for (final d in days.entries) d.key: (d.value.date, d.value.servings),
    });
    final knownCosts = {
      for (final e in best.entries)
        if (profile.resources.estimatedCost(e.value, days[e.key]!.servings) !=
            null)
          e.key: profile.resources.estimatedCost(
            e.value,
            days[e.key]!.servings,
          )!,
    };
    if (profile.resources.hasBudget) {
      if (knownCosts.isNotEmpty) {
        final total = knownCosts.values.fold<double>(0, (a, b) => a + b);
        warnings.add(
          'Eigene Kostenschätzungen: ${total.toStringAsFixed(2).replaceAll('.', ',')} € für ${knownCosts.length} von ${best.length} Gerichten. Keine Live-Preise oder Packungskosten.',
        );
        if (profile.resources.budget != null &&
            total > profile.resources.budget!) {
          warnings.add(
            'Schon die bekannten Kostenschätzungen überschreiten dein Planbudget.',
          );
        }
      }
      if (knownCosts.length < best.length && profile.resources.budget != null) {
        warnings.add(
          'Das Planbudget lässt sich wegen fehlender Kostenschätzungen nicht vollständig prüfen. Fehlende Kosten werden neutral bewertet.',
        );
      }
    }
    if (best.values.any((r) => r.primarySide == null || r.dishType == null)) {
      warnings.add(
        'Bei einigen Rezepten fehlen geprüfte Angaben zu Hauptbeilage oder Gerichtsart. Die Abwechslung lässt sich dort nur teilweise prüfen.',
      );
    }
    if (best.length < days.length) {
      final blocked = candidates.entries
          .where(
            (e) =>
                e.value.isEmpty &&
                pool.any(
                  (r) => eligible(
                    r,
                    days[e.key]!,
                    profile,
                    history,
                    allowRepeats: true,
                  ),
                ),
          )
          .length;
      warnings.add(
        'Für ${days.length - best.length} Tage fehlen passende Rezepte.${blocked > 0 ? ' Geeignete Gerichte liegen noch in der 30-Tage-Pause.' : ' Ausschlüsse, Kochzeit oder fehlende geeignete Rezepte begrenzen die Auswahl.'}',
      );
    }
    final sides = <String, int>{};
    for (final r in best.values) {
      if (r.primarySide != null && r.primarySide != 'none') {
        sides[r.primarySide!] = (sides[r.primarySide!] ?? 0) + 1;
      }
    }
    if (sides.values.any((n) => n > 2)) {
      warnings.add('Eine Hauptbeilage kommt häufiger als zweimal vor.');
    }
    final types = <String, int>{};
    for (final r in best.values) {
      if (r.dishType != null) {
        types[r.dishType!] = (types[r.dishType!] ?? 0) + 1;
      }
    }
    if (types.values.any((n) => n > 2)) {
      warnings.add('Eine Gerichtsart kommt häufiger als zweimal vor.');
    }
    var adjacentSide = false, adjacentMain = false;
    for (final e in best.entries) {
      for (final other in best.entries.where(
        (o) =>
            o.key < e.key &&
            (calendarDay(days[e.key]!.date) - calendarDay(days[o.key]!.date))
                    .abs() ==
                1,
      )) {
        if (e.value.primarySide != null &&
            e.value.primarySide != 'none' &&
            e.value.primarySide == other.value.primarySide) {
          adjacentSide = true;
        }
        if (e.value.mainIngredient != null &&
            e.value.mainIngredient == other.value.mainIngredient) {
          adjacentMain = true;
        }
      }
      if (fixed.containsKey(e.key) &&
          !eligible(
            e.value,
            days[e.key]!,
            profile,
            history,
            allowRepeats: true,
          )) {
        warnings.add(
          'Das fixierte Gericht „${e.value.name}“ steht im Konflikt mit aktuellen Vorgaben oder ist nicht verlässlich geprüft. Bitte selbst prüfen oder austauschen.',
        );
      }
    }
    if (adjacentSide) {
      warnings.add('An Folgetagen wiederholt sich eine Hauptbeilage.');
    }
    if (adjacentMain) {
      warnings.add('An Folgetagen wiederholt sich eine dominante Hauptzutat.');
    }
    final newCount = best.values
        .where((r) => !profile.cooked.contains(r.id))
        .length;
    final targetNew = days.length < 2 ? days.length : 2;
    if (newCount != targetNew) {
      warnings.add(
        '$newCount statt $targetNew bisher nicht als gekocht erfasste Gerichte im Vorschlag.',
      );
    }
    return PlannerResult(
      best,
      {
        for (final e in best.entries)
          e.key: [
            if (profile.ratings[e.value.id] != null)
              'Deine Bewertung: ${profile.ratings[e.value.id]} Sterne',
            if (profile.favorites.contains(e.value.id)) 'Dein Favorit',
            if (!profile.cooked.contains(e.value.id))
              'Bisher nicht als gekocht erfasst',
            if ((stockScores[e.key] ?? 50) > 50)
              'Nutzt mengenmäßig verfügbare Vorräte am Kochtag',
            if (knownCosts.containsKey(e.key))
              'Eigene Kostenschätzung: ${knownCosts[e.key]!.toStringAsFixed(2).replaceAll('.', ',')} €',
            if (profile.resources.costClass != null &&
                PlanningResources.costRank(e.value.costClass) != null)
              'Kostenklasse bei der Auswahl berücksichtigt',
            if (eligible(
              e.value,
              days[e.key]!,
              profile,
              history,
              allowRepeats: true,
            ))
              'Passt zur Kochzeit und zu deinen festen Regeln'
            else
              'Fixiertes Gericht: aktuelle Vorgaben bitte prüfen',
          ],
      },
      warnings,
      seed,
    );
  }
}
