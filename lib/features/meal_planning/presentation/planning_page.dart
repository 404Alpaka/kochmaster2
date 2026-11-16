import 'dart:async';
import 'dart:convert';

import '../../auth/data/session_storage.dart';

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';

import '../../recipes/data/admin_recipe_repository.dart';
import '../../recipes/data/supabase_recipe_repository.dart';
import '../../recipes/presentation/admin_recipes_page.dart';

import 'package:supabase/supabase.dart';

import '../../auth/presentation/account_page.dart';
import '../data/weekly_plan_repository.dart';
import '../domain/meal_plan.dart';
import '../../recipes/domain/recipe.dart';
import '../../shopping/domain/build_shopping_list.dart';

part 'mise_views.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({
    super.key,
    required this.recipes,
    required this.isDemo,
    this.client,
    this.user,
    this.store,
  });
  final SupabaseClient? client;
  final User? user;
  final WeeklyPlanRepository? store;
  final List<Recipe> recipes;
  final bool isDemo;
  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  List<Recipe>? refreshedCatalog;
  bool admin = false;
  List<Recipe> get recipes => refreshedCatalog ?? widget.recipes;
  final plan = <int, PlannedMeal>{};
  final checked = <(String, String)>{};
  static const days = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];
  int tab = 0;
  int servings = 2;

  String query = '';
  int recipeFilter = 0;
  int selectedDay = DateTime.now().weekday - 1;
  int saying = 0;
  Timer? sayingTimer;
  double budget = 75;
  final weeklyExpenses = <String, double>{};
  double? get expenses => weeklyExpenses[dateKey(week)];
  set expenses(double? value) {
    if (value == null) {
      weeklyExpenses.remove(dateKey(week));
    } else {
      weeklyExpenses[dateKey(week)] = value;
    }
  }

  String householdName = 'Zuhause';
  String preferences = 'Noch keine Vorlieben hinterlegt';
  String pantryFilter = 'Alle';
  List<Map<String, dynamic>> pantry = [];
  final searchController = TextEditingController();
  static const sayings = [
    'Gutes Essen. Clever geplant.',
    'Dein Vorrat. Dein nächstes Lieblingsgericht.',
    'Weniger Reste. Mehr Genuss.',
    'Zusammen schmeckt der Alltag besser.',
  ];

  String get preferencesKey => 'mise-preferences-${widget.user?.id ?? 'guest'}';

  void update(VoidCallback change) => setState(change);

  void savePreferences() {
    writeSession(
      preferencesKey,
      jsonEncode({
        'budget': budget,
        'weeklyExpenses': weeklyExpenses,
        'household': householdName,
        'servings': servings,
        'preferences': preferences,
        'pantry': pantry,
      }),
    );
  }

  void restorePreferences() {
    try {
      final raw = readSession(preferencesKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      budget = (data['budget'] as num?)?.toDouble() ?? 75;
      final storedExpenses =
          data['weeklyExpenses'] as Map<String, dynamic>? ?? {};
      weeklyExpenses.addAll(
        storedExpenses.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
      );
      householdName = data['household'] as String? ?? 'Zuhause';
      servings = data['servings'] as int? ?? 2;
      preferences = data['preferences'] as String? ?? preferences;
      pantry = (data['pantry'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      /* Invalid local preferences fall back to their defaults. */
    }
  }

  @override
  void dispose() {
    sayingTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  DateTime week = mondayOf(DateTime.now());
  bool loading = false;
  bool saving = false;
  String? loadError;
  String? saveError;
  bool saved = false;
  @override
  void initState() {
    super.initState();
    restorePreferences();
    sayingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && tab == 0) {
        setState(() => saying = (saying + 1) % sayings.length);
      }
    });
    if (widget.store != null) loadWeek();
    if (widget.user != null) checkAdmin();
  }

  Future<void> checkAdmin() async {
    try {
      final allowed = await widget.client!
          .rpc('is_recipe_admin')
          .timeout(const Duration(seconds: 15));
      if (mounted) setState(() => admin = allowed == true);
    } catch (_) {
      if (mounted) setState(() => admin = false);
    }
  }

  Future<void> manageRecipes() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminRecipesPage(
          repository: SupabaseAdminRecipeRepository(widget.client!),
        ),
      ),
    );
    if (!mounted) return;
    try {
      final updated = await SupabaseRecipeRepository(widget.client!).getAll();
      if (mounted) setState(() => refreshedCatalog = updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Katalog konnte nicht aktualisiert werden. Bitte lade die Seite neu.',
            ),
          ),
        );
      }
    }
  }

  String displayDate(DateTime date) => '${date.day}.${date.month}.${date.year}';
  Future<void> loadWeek() async {
    setState(() {
      loading = true;
      loadError = null;
      saveError = null;
    });
    try {
      final result = await widget.store!.load(week, recipes);
      if (!mounted) return;
      setState(() {
        saved = true;
        plan
          ..clear()
          ..addAll(result.meals);
        checked
          ..clear()
          ..addAll(result.checked);
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => loadError = 'Dein Wochenplan konnte nicht geladen werden. Prüfe die Verbindung. Möglicherweise ist ein geplantes Rezept nicht mehr verfügbar.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> account() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountPage(client: widget.client!),
      ),
    );
  }

  Future<void> signOut() async {
    try {
      await widget.client!.auth.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abmeldung fehlgeschlagen. Bitte erneut versuchen.'),
          ),
        );
      }
    }
  }

  Future<bool> persist(
    Map<int, PlannedMeal> nextPlan,
    Set<(String, String)> nextChecked,
  ) async {
    if (saving || loading || loadError != null) return false;
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      await widget.store?.save(
        week,
        WeeklyPlan(meals: nextPlan, checked: nextChecked),
      );
      if (!mounted) return false;
      setState(() {
        saved = true;
        plan
          ..clear()
          ..addAll(nextPlan);
        checked
          ..clear()
          ..addAll(nextChecked);
      });
      return true;
    } catch (_) {
      if (mounted) {
        setState(
          () => saveError = 'Die Änderung wurde nicht gespeichert. Dein letzter gespeicherter Stand bleibt erhalten. Bitte versuche die Änderung erneut.',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nicht gespeichert. Bitte prüfe deine Verbindung und versuche es erneut.',
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> changeWeek(int delta) async {
    if (saving || loading) return;
    setState(() {
      week = DateTime(week.year, week.month, week.day + delta * 7);
      plan.clear();
      checked.clear();
    });
    if (widget.store != null) await loadWeek();
  }

  Future<void> addRecipe(Recipe recipe) async {
    if (widget.client != null && widget.user == null) {
      await account();
      return;
    }
    if (saving || loading || loadError != null) return;
    final day = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Tag auswählen'),
        children: [
          for (var i = 0; i < days.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text(
                '${days[i]}${plan.containsKey(i) ? ' · Gericht ersetzen' : ''}',
              ),
            ),
        ],
      ),
    );
    if (day == null || !mounted) return;
    final next = Map<int, PlannedMeal>.from(plan)
      ..[day] = PlannedMeal(recipe, servings);
    if (!await saveMeals(next)) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${recipe.name} für ${days[day]} geplant')),
    );
  }

  Future<bool> saveMeals(Map<int, PlannedMeal> next) =>
      persist(next, retainCheckedItems(plan.values, next.values, checked));

  Future<void> adjustServings(int day, int delta) async {
    final meal = plan[day];
    if (meal == null || meal.servings + delta < 1) return;
    final next = Map<int, PlannedMeal>.from(plan)
      ..[day] = PlannedMeal(meal.recipe, meal.servings + delta);
    await saveMeals(next);
  }

  void details(Recipe recipe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FRISCH AUF DEINEN TELLER',
                  style: TextStyle(
                    color: AppColors.sage,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  recipe.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '${recipe.minutes} Minuten · ${recipe.servings} Portionen',
                ),
                const SizedBox(height: 16),
                Text('Zutaten', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in recipe.ingredients)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              '${item.quantity.toStringAsFixed(0)} ${item.unit} ${item.name}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'So kommt es auf den Tisch',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < recipe.steps.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text('${i + 1}. ${recipe.steps[i]}'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      addRecipe(recipe);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Zum Wochenplan hinzufügen'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => miseScaffold();
}
