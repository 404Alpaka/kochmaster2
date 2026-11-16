import 'package:material_ui/material_ui.dart';

import '../../recipes/data/admin_recipe_repository.dart';
import '../../recipes/data/supabase_recipe_repository.dart';
import '../../recipes/presentation/admin_recipes_page.dart';

import 'package:supabase/supabase.dart';

import '../../auth/presentation/account_page.dart';
import '../data/weekly_plan_repository.dart';
import '../domain/meal_plan.dart';
import '../../recipes/domain/recipe.dart';
import '../../shopping/domain/build_shopping_list.dart';

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

  DateTime week = mondayOf(DateTime.now());
  bool loading = false;
  bool saving = false;
  String? loadError;
  String? saveError;
  bool saved = false;
  @override
  void initState() {
    super.initState();
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
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  recipe.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '${recipe.minutes} Minuten · ${recipe.servings} Portionen',
                ),
                const SizedBox(height: 16),
                for (final item in recipe.ingredients)
                  Text(
                    '${item.quantity.toStringAsFixed(0)} ${item.unit} ${item.name}',
                  ),
                const SizedBox(height: 16),
                for (var i = 0; i < recipe.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('${i + 1}. ${recipe.steps[i]}'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopping = buildShoppingList(plan.values);
    final filtered = recipes.where(
      (r) => r.name.toLowerCase().contains(query.toLowerCase()),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kochmaster'),
        actions: [
          if (admin)
            IconButton(
              tooltip: 'Rezepte verwalten',
              onPressed: saving ? null : manageRecipes,
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          if (widget.client != null && widget.user == null)
            TextButton(onPressed: account, child: const Text('Anmelden')),
          if (widget.user != null)
            TextButton(
              onPressed: saving ? null : signOut,
              child: const Text('Abmelden'),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loadError!),
                    FilledButton(
                      onPressed: loadWeek,
                      child: const Text('Wochenplan erneut laden'),
                    ),
                  ],
                ),
              ),
            )
          : AbsorbPointer(
              absorbing: saving,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          [
                            'Was kochen wir heute?',
                            'Deine Woche, dein Geschmack.',
                            'Alles für deinen Einkauf.',
                          ][tab],
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isDemo
                              ? 'Demo · Beispieldaten · Änderungen bleiben nur bis zum Neustart erhalten.'
                              : widget.user == null
                              ? 'Rezepte aus der Datenbank · Zum Speichern bitte anmelden.'
                              : 'Dein Wochenplan und Einkaufsstatus werden in deinem Konto gespeichert.',
                        ),
                        if (widget.user?.email != null)
                          Text(widget.user!.email!),
                        if (widget.store != null) ...[
                          Row(
                            children: [
                              Icon(
                                saving
                                    ? Icons.cloud_upload_outlined
                                    : saveError != null
                                    ? Icons.error_outline
                                    : Icons.cloud_done_outlined,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  saving
                                      ? 'Wird gespeichert …'
                                      : saveError != null
                                      ? 'Nicht gespeichert'
                                      : saved
                                      ? 'Gespeichert'
                                      : 'Wird geladen …',
                                  key: const ValueKey('save-status'),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Gespeicherten Wochenplan neu laden',
                                onPressed: saving ? null : loadWeek,
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                          if (saveError != null)
                            Text(
                              saveError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                        ],
                        if (saving) const LinearProgressIndicator(),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Vorherige Woche',
                              onPressed: () => changeWeek(-1),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Text(
                                'Woche ${displayDate(week)} – ${displayDate(DateTime(week.year, week.month, week.day + 6))}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Nächste Woche',
                              onPressed: () => changeWeek(1),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (tab == 0) ...[
                          Text(
                            "${filtered.length} von ${recipes.length} Rezepten",
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Rezepte suchen',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => setState(() => query = value),
                          ),
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Portionen für neue Planeinträge'),
                              ),
                              IconButton(
                                onPressed: servings > 1
                                    ? () => setState(() => servings--)
                                    : null,
                                icon: const Icon(Icons.remove),
                              ),
                              Text('$servings'),
                              IconButton(
                                onPressed: () => setState(() => servings++),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                          if (filtered.isEmpty)
                            Text(
                              recipes.isEmpty
                                  ? 'Noch keine veröffentlichten Rezepte vorhanden.'
                                  : 'Keine passenden Rezepte gefunden.',
                            ),
                          for (final recipe in filtered)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recipe.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    Text(
                                      '${recipe.minutes} Minuten · ${recipe.servings} Basisportionen',
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      children: [
                                        TextButton(
                                          onPressed: () => details(recipe),
                                          child: const Text('Rezept ansehen'),
                                        ),
                                        FilledButton.icon(
                                          onPressed: () => addRecipe(recipe),
                                          icon: const Icon(Icons.add),
                                          label: const Text('Wochenplan'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        if (tab == 1) ...[
                          Text('${plan.length} von 7 Tagen geplant'),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: widget.store != null
                                ? () => persist(
                                    Map<int, PlannedMeal>.from(plan),
                                    Set<(String, String)>.from(checked),
                                  )
                                : widget.client != null
                                ? account
                                : null,
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Wochenplan speichern'),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Ein Gericht pro Tag. Rezepte fügst du im Bereich Rezepte hinzu.',
                          ),
                          if (plan.isEmpty)
                            TextButton.icon(
                              onPressed: () => setState(() => tab = 0),
                              icon: const Icon(Icons.add),
                              label: const Text('Erstes Rezept auswählen'),
                            ),
                          for (var i = 0; i < days.length; i++)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${days[i]} · ${displayDate(DateTime(week.year, week.month, week.day + i))}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(plan[i]?.recipe.name ?? 'Noch frei'),
                                    if (plan[i] != null)
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        children: [
                                          IconButton(
                                            key: ValueKey('decrease-$i'),
                                            tooltip: 'Weniger Portionen',
                                            onPressed: plan[i]!.servings > 1
                                                ? () => adjustServings(i, -1)
                                                : null,
                                            icon: const Icon(Icons.remove),
                                          ),
                                          Text(
                                            '${plan[i]!.servings} Portionen',
                                          ),
                                          IconButton(
                                            key: ValueKey('increase-$i'),
                                            tooltip: 'Mehr Portionen',
                                            onPressed: () =>
                                                adjustServings(i, 1),
                                            icon: const Icon(Icons.add),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                details(plan[i]!.recipe),
                                            child: const Text('Rezept'),
                                          ),
                                          IconButton(
                                            key: ValueKey('remove-$i'),
                                            tooltip: 'Gericht entfernen',
                                            onPressed: () => saveMeals(
                                              Map<int, PlannedMeal>.from(plan)
                                                ..remove(i),
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        if (tab == 2) ...[
                          if (shopping.isNotEmpty) ...[
                            Text(
                              '${shopping.where((item) => checked.contains((item.ingredientId, item.unit))).length} von ${shopping.length} Zutaten erledigt',
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Mengen aus allen geplanten Gerichten, angepasst an deine Portionen.',
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (shopping.isEmpty)
                            const Text(
                              'Plane zuerst ein Rezept. Deine Zutaten erscheinen dann hier.',
                            ),
                          for (final item in shopping)
                            CheckboxListTile(
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  decoration:
                                      checked.contains((
                                        item.ingredientId,
                                        item.unit,
                                      ))
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                              ),
                              value: checked.contains((
                                item.ingredientId,
                                item.unit,
                              )),
                              onChanged: (value) {
                                final next = Set<(String, String)>.from(
                                  checked,
                                );
                                final key = (item.ingredientId, item.unit);
                                if (value == true) {
                                  next.add(key);
                                } else {
                                  next.remove(key);
                                }
                                persist(Map<int, PlannedMeal>.from(plan), next);
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: 'Rezepte',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Wochenplan',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_basket_outlined),
            label: 'Einkaufsliste',
          ),
        ],
      ),
    );
  }
}
