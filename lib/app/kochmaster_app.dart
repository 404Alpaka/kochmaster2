import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';

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
    title: 'mise.',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: client != null
        ? AccountScope(
            client: client!,
            storageKey: "kochmaster-${client!.rest.url}-session",
            builder: (user) => RecipeLoader(
              repository: repository!,
              builder: (recipes) => PlanningPage(
                key: ValueKey(user?.id ?? 'guest'),
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
