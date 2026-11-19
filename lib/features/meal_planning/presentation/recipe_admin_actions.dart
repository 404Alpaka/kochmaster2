part of 'planning_page.dart';

extension _RecipeAdminActions on _PlanningPageState {
  AdminRecipeRepository get recipeAdminRepository =>
      widget.adminRepository ?? SupabaseAdminRecipeRepository(widget.client!);

  bool canManageRecipe(Recipe recipe) =>
      admin && personalRecipeRecord(recipe.id) == null;

  Future<void> reloadAdminCatalog() async {
    final updated = widget.adminRepository != null
        ? (await recipeAdminRepository.list())
              .where((entry) => entry.published && !entry.deleted)
              .map((entry) => entry.recipe)
              .toList()
        : await SupabaseRecipeRepository(widget.client!).getAll();
    if (mounted) {
      update(() {
        refreshedCatalog = updated;
        openedRecipe = null;
      });
    }
  }

  Future<void> adminRecipeAction(String action, [Recipe? recipe]) async {
    if (!admin ||
        adminActionBusy ||
        (recipe != null && !canManageRecipe(recipe))) {
      return;
    }
    update(() => adminActionBusy = true);
    try {
      AdminRecipe? entry;
      if (recipe != null) {
        final entries = await recipeAdminRepository.list();
        if (!mounted) return;
        entry = entries.firstWhere((entry) => entry.recipe.id == recipe.id);
        if (entry.deleted) throw StateError('Recipe is in bin');
      }
      if (action == 'create' || action == 'edit') {
        if (!mounted) return;
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => RecipeEditorPage(
              repository: recipeAdminRepository,
              existing: entry,
            ),
          ),
        );
        if (saved == true) await reloadAdminCatalog();
      } else {
        if (!mounted || entry == null) return;
        final deleting = action == 'delete';
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              deleting ? 'Rezept löschen?' : 'In Entwürfe verschieben?',
            ),
            content: Text(
              deleting
                  ? '${entry!.recipe.name} wird in den Papierkorb verschoben und kann dort wiederhergestellt werden. Gespeicherte Wochenpläne bleiben erhalten.'
                  : '${entry!.recipe.name} ist danach nicht mehr öffentlich sichtbar. Du findest es unter „Rezepte verwalten“ bei den Entwürfen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  deleting ? 'In Papierkorb' : 'In Entwürfe verschieben',
                ),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        if (deleting) {
          await recipeAdminRepository.setDeleted(entry.recipe.id, true);
        } else {
          await recipeAdminRepository.save({
            ...recipeSnapshot(entry.recipe),
            'is_published': false,
          });
        }
        await reloadAdminCatalog();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                deleting
                    ? 'Rezept ist im Papierkorb.'
                    : 'Rezept ist jetzt ein Entwurf.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Änderung fehlgeschlagen. Bitte Verbindung und Admin-Rechte prüfen.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) update(() => adminActionBusy = false);
    }
  }
}

