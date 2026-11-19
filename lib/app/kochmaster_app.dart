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
            builder: (user) => _AccountCatalog(
              key: ValueKey((client, user?.id)),
              repository: repository!,
              client: client!,
              user: user,
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

/// Keep loaded week revisions across token refreshes and auth metadata updates.
/// A different client or account gets a separate state through the parent key.
class _AccountCatalog extends StatefulWidget {
  const _AccountCatalog({
    super.key,
    required this.repository,
    required this.client,
    required this.user,
  });
  final RecipeRepository repository;
  final SupabaseClient client;
  final User? user;
  @override
  State<_AccountCatalog> createState() => _AccountCatalogState();
}

class _AccountCatalogState extends State<_AccountCatalog> {
  late final WeeklyPlanRepository? store = widget.user == null
      ? null
      : SupabaseWeeklyPlanRepository(widget.client, widget.user!.id);
  @override
  Widget build(BuildContext context) => RecipeLoader(
    repository: widget.repository,
    builder: (recipes) => PlanningPage(
      key: ValueKey(widget.user?.id ?? 'guest'),
      recipes: recipes,
      isDemo: false,
      client: widget.client,
      user: widget.user,
      store: store,
    ),
  );
}
