import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/data/session_storage.dart';

import '../features/recipes/data/demo_recipe_repository.dart';
import 'recipe_loader.dart';

import 'package:supabase/supabase.dart';

import '../features/auth/presentation/account_scope.dart';
import '../features/meal_planning/data/weekly_plan_repository.dart';
import '../features/recipes/domain/recipe.dart';
import '../features/meal_planning/presentation/planning_page.dart';

class KochmasterApp extends StatefulWidget {
  const KochmasterApp({super.key, this.repository, this.client});
  final SupabaseClient? client;
  final RecipeRepository? repository;
  @override
  State<KochmasterApp> createState() => _KochmasterAppState();
}

class _KochmasterAppState extends State<KochmasterApp> {
  @override
  void initState() {
    super.initState();
    appThemeMode.value = readSession('mise-theme-mode') == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: appThemeMode,
    builder: (context, mode, _) => MaterialApp(
      title: 'mise.',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      home: widget.client != null
          ? AccountScope(
              client: widget.client!,
              storageKey: 'kochmaster-${widget.client!.rest.url}-session',
              builder: (user) => _AccountCatalog(
                key: ValueKey((widget.client, user?.id)),
                repository: widget.repository!,
                client: widget.client!,
                user: user,
              ),
            )
          : widget.repository == null
          ? PlanningPage(recipes: DemoRecipeRepository().getAll(), isDemo: true)
          : RecipeLoader(
              repository: widget.repository!,
              builder: (recipes) =>
                  PlanningPage(recipes: recipes, isDemo: false),
            ),
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
