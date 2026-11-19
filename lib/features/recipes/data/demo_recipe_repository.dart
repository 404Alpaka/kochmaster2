import '../domain/recipe.dart';

class DemoRecipeRepository implements RecipeRepository {
  @override
  List<Recipe> getAll() => const [
    Recipe(
      id: 'pasta',
      name: 'Tomaten-Spinat-Pasta',
      imageUrl: 'assets/images/pasta.jpg',
      categories: {'vegetarian', 'main'},
      minutes: 20,
      servings: 2,
      ingredients: [
        IngredientAmount('pasta', 'Nudeln', 200, 'g'),
        IngredientAmount('tomato', 'Tomaten', 300, 'g'),
        IngredientAmount('spinach', 'Spinat', 150, 'g'),
      ],
      steps: [
        'Nudeln nach Packungsangabe kochen.',
        'Tomaten klein schneiden und in einer Pfanne erhitzen.',
        'Spinat zugeben, zusammenfallen lassen und mit den Nudeln mischen.',
      ],
    ),
    Recipe(
      id: 'rice',
      name: 'Brokkoli-Reis-Pfanne',
      imageUrl: 'assets/images/rice.jpg',
      categories: {'vegetarian', 'vegan', 'main'},
      minutes: 25,
      servings: 2,
      ingredients: [
        IngredientAmount('rice', 'Reis', 150, 'g'),
        IngredientAmount('broccoli', 'Brokkoli', 300, 'g'),
        IngredientAmount('tomato', 'Tomaten', 200, 'g'),
      ],
      steps: [
        'Reis nach Packungsangabe garen.',
        'Brokkoli in Röschen teilen und in wenig Wasser garen.',
        'Tomaten würfeln, erhitzen und mit Reis und Brokkoli vermengen.',
      ],
    ),
  ];
}
