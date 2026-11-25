import '../../recipes/domain/recipe.dart';
import 'cooking_timer.dart';

class CookingProgress {
  const CookingProgress({
    required this.recipe,
    required this.portions,
    required this.step,
    required this.key,
    required this.date,
    required this.day,
    required this.timers,
  });

  factory CookingProgress.fromJson(Map<String, dynamic> data) {
    final timerData = data['timers'] as Map? ?? {};
    final key = data['key'] as String;
    final day = (data['day'] as num?)?.toInt();
    if (key.isEmpty || (day != null && (day < 0 || day > 6))) {
      throw const FormatException('Ungültiger Kochfortschritt.');
    }
    return CookingProgress(
      recipe: recipeFromSnapshot(
        Map<String, dynamic>.from(data['recipe'] as Map),
      ),
      portions: (data['portions'] as num).toInt(),
      step: (data['step'] as num).toInt(),
      key: key,
      date: DateTime.parse(data['date'] as String),
      day: day,
      timers: {
        for (final entry in timerData.entries)
          int.parse(entry.key as String):
              CookingTimer.fromJson(Map<String, dynamic>.from(entry.value as Map)),
      },
    );
  }

  final Recipe recipe;
  final int portions;
  final int step;
  final String key;
  final DateTime date;
  final int? day;
  final Map<int, CookingTimer> timers;

  Map<String, dynamic> toJson() => {
    'recipe': recipeSnapshot(recipe),
    'portions': portions,
    'step': step,
    'key': key,
    'date': date.toIso8601String(),
    'day': day,
    'timers': {
      for (final entry in timers.entries)
        entry.key.toString(): entry.value.toJson(),
    },
  };
}
