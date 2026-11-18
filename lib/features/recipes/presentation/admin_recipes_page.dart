import 'package:material_ui/material_ui.dart';

import '../data/admin_recipe_repository.dart';
import '../../../core/theme/app_theme.dart';
import 'recipe_editor_page.dart';
import 'recipe_image.dart';

class AdminRecipesPage extends StatefulWidget {
  const AdminRecipesPage({super.key, required this.repository});
  final AdminRecipeRepository repository;
  @override
  State<AdminRecipesPage> createState() => _AdminRecipesPageState();
}

class _AdminRecipesPageState extends State<AdminRecipesPage> {
  List<AdminRecipe> recipes = [];
  bool busy = true;
  bool trash = false;
  String? error;
  String query = '';
  String status = 'Alle';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final rows = await widget.repository.list();
      if (mounted) {
        setState(() {
          recipes = rows;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Rezepte konnten nicht geladen werden. Prüfe Verbindung und Admin-Rechte.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([AdminRecipe? recipe]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            RecipeEditorPage(repository: widget.repository, existing: recipe),
      ),
    );
    if (result == true && mounted) await load();
  }

  Future<void> setDeleted(AdminRecipe entry) async {
    if (!entry.deleted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rezept löschen?'),
          content: Text(
            '${entry.recipe.name} wird aus dem Katalog entfernt. Im Papierkorb kannst du es wiederherstellen. Gespeicherte Wochenpläne bleiben erhalten.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('In Papierkorb'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      await widget.repository.setDeleted(entry.recipe.id, !entry.deleted);
      if (mounted) await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Änderung fehlgeschlagen. Prüfe Verbindung und Admin-Rechte.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget recipeCard(AdminRecipe entry) {
    final recipe = entry.recipe;
    final label = entry.deleted
        ? 'Im Papierkorb'
        : entry.published
        ? 'Veröffentlicht'
        : 'Entwurf';
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              RecipeImage(
                recipeImageSource(recipe),
                height: 170,
                semanticLabel: 'Rezeptbild für ${recipe.name}',
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: entry.published && !entry.deleted
                        ? AppColors.softGreen
                        : AppColors.cream,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.sage,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (recipe.imageUrl == null ||
                  recipe.imageUrl!.startsWith('assets/'))
                Positioned(
                  bottom: 10,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Beispielbild',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  recipe.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          size: 16,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${recipe.minutes} Min.',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 16,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${recipe.servings} Portionen',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: entry.deleted
                          ? OutlinedButton.icon(
                              onPressed: busy ? null : () => setDeleted(entry),
                              icon: const Icon(Icons.restore),
                              label: const Text('Wiederherstellen'),
                            )
                          : FilledButton.icon(
                              onPressed: busy ? null : () => edit(entry),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text(
                                'Bearbeiten',
                                style: TextStyle(fontFamily: 'Roboto'),
                              ),
                            ),
                    ),
                    if (!entry.deleted) ...[
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: 'Löschen',
                        onPressed: busy ? null : () => setDeleted(entry),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = recipes
        .where(
          (r) =>
              r.deleted == trash &&
              (trash ||
                  status == 'Alle' ||
                  (status == 'Veröffentlicht' ? r.published : !r.published)) &&
              r.recipe.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final active = recipes.where((r) => !r.deleted).length;
    final published = recipes.where((r) => !r.deleted && r.published).length;
    final deleted = recipes.where((r) => r.deleted).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezepte verwalten'),
        actions: [
          IconButton(
            tooltip: 'Neu laden',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Rezept erstellen',
        onPressed: busy ? null : () => edit(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text(
          'Rezept erstellen',
          style: TextStyle(fontFamily: 'Roboto'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final padding = constraints.maxWidth < 600 ? 20.0 : 32.0;
              final columns = constraints.maxWidth >= 720 ? 2 : 1;
              final cardWidth =
                  (constraints.maxWidth - padding * 2 - (columns - 1) * 20) /
                  columns;
              return ListView(
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 112),
                children: [
                  const Text(
                    'DEINE REZEPTKÜCHE',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sage,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Gute Rezepte.\nGut gepflegt.',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: constraints.maxWidth < 600 ? 32 : 40,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$active Rezepte · $published veröffentlicht · ${active - published} Entwürfe',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rezept suchen …',
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Rezepte durchsuchen',
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final label in [
                        'Alle',
                        'Veröffentlicht',
                        'Entwürfe',
                        'Papierkorb',
                      ])
                        ChoiceChip(
                          label: Text(
                            label == 'Alle'
                                ? 'Alle $active'
                                : label == 'Papierkorb'
                                ? 'Papierkorb $deleted'
                                : label,
                          ),
                          selected: label == 'Papierkorb'
                              ? trash
                              : !trash && status == label,
                          onSelected: busy
                              ? null
                              : (_) => setState(() {
                                  trash = label == 'Papierkorb';
                                  status = trash ? 'Alle' : label;
                                }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trash ? 'Im Papierkorb' : 'Dein Rezeptkatalog',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${entries.length} Treffer',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (busy) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (!busy && entries.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            trash
                                ? Icons.delete_outline
                                : Icons.restaurant_outlined,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            query.isNotEmpty
                                ? 'Keine passenden Rezepte gefunden.'
                                : trash
                                ? 'Dein Papierkorb ist leer.'
                                : 'Hier ist Platz für gute Ideen.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            query.isNotEmpty
                                ? 'Versuche einen anderen Suchbegriff oder Filter.'
                                : trash
                                ? 'Entfernte Rezepte kannst du hier wiederherstellen.'
                                : 'Lege dein erstes Rezept an.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      for (final entry in entries)
                        SizedBox(width: cardWidth, child: recipeCard(entry)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
