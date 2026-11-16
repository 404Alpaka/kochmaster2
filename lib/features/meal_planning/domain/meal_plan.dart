import '../../recipes/domain/recipe.dart';

class PlannedMeal {
  PlannedMeal(this.recipe, this.servings, {this.preparedMealId, this.preparedConsumed = false}) {
    if (servings <= 0) throw ArgumentError.value(servings, 'servings');
  }
  final Recipe recipe;
  final int servings;
  final String? preparedMealId;
  final bool preparedConsumed;
}
