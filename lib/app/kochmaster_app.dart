import 'package:material_ui/material_ui.dart';

import '../features/recipes/data/demo_recipe_repository.dart';
import 'recipe_loader.dart';

import 'package:supabase/supabase.dart';

import '../features/auth/presentation/account_scope.dart';
import '../features/meal_planning/data/weekly_plan_repository.dart';
import '../features/recipes/domain/recipe.dart';
import '../features/meal_planning/presentation/planning_page.dart';

class KochmasterApp extends StatelessWidget {
  const KochmasterApp({super.key, this.repository, this.client});
  final SupabaseClient? client;
  final RecipeRepository? repository;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kochmaster',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF286348)),
      scaffoldBackgroundColor: const Color(0xFFF8F8F2),
    ),
    home: client != null
        ? AccountScope(
            client: client!,
            storageKey: "kochmaster-${client!.rest.url}-session",
            builder: (user) => RecipeLoader(
              repository: repository!,
              builder: (recipes) => PlanningPage(
                recipes: recipes,
                isDemo: false,
                client: client,
                user: user,
                store: user == null
                    ? null
                    : SupabaseWeeklyPlanRepository(client!, user.id),
              ),
            ),
          )
        : repository == null
        ? PlanningPage(recipes: DemoRecipeRepository().getAll(), isDemo: true)
        : RecipeLoader(
            repository: repository!,
            builder: (recipes) => PlanningPage(recipes: recipes, isDemo: false),
          ),
  );
}
