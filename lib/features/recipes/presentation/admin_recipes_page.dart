import 'package:material_ui/material_ui.dart';

import '../data/admin_recipe_repository.dart';
import 'recipe_editor_page.dart';

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

  @override
  Widget build(BuildContext context) {
    final entries = recipes.where(
      (r) =>
          r.deleted == trash &&
          r.recipe.name.toLowerCase().contains(query.toLowerCase()),
    );
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
      floatingActionButton: trash
          ? null
          : FloatingActionButton.extended(
              onPressed: busy ? null : () => edit(),
              icon: const Icon(Icons.add),
              label: const Text('Neues Rezept'),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
            children: [
              SwitchListTile(
                title: const Text('Papierkorb anzeigen'),
                value: trash,
                onChanged: busy ? null : (v) => setState(() => trash = v),
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Rezepte durchsuchen',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => query = v),
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(error!),
                ),
              if (!busy && entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Keine Rezepte vorhanden.'),
                ),
              for (final entry in entries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.recipe.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          entry.deleted
                              ? 'Im Papierkorb'
                              : entry.published
                              ? 'Veröffentlicht'
                              : 'Entwurf',
                        ),
                        Wrap(
                          spacing: 12,
                          children: [
                            if (!entry.deleted)
                              TextButton.icon(
                                onPressed: busy ? null : () => edit(entry),
                                icon: const Icon(Icons.edit),
                                label: const Text('Bearbeiten'),
                              ),
                            TextButton.icon(
                              onPressed: busy ? null : () => setDeleted(entry),
                              icon: Icon(
                                entry.deleted
                                    ? Icons.restore
                                    : Icons.delete_outline,
                              ),
                              label: Text(
                                entry.deleted ? 'Wiederherstellen' : 'Löschen',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
