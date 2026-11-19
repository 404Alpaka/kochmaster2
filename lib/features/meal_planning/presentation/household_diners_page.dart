import 'package:material_ui/material_ui.dart';

import '../../recipes/domain/recipe.dart';
import '../domain/planning_diner.dart';

class HouseholdDinersPage extends StatefulWidget {
  const HouseholdDinersPage({
    super.key,
    required this.initial,
    this.readOnly = false,
  });
  final List<PlanningDiner> initial;
  final bool readOnly;
  @override
  State<HouseholdDinersPage> createState() => _HouseholdDinersPageState();
}

class _HouseholdDinersPageState extends State<HouseholdDinersPage> {
  late final diners = [...widget.initial];

  Future<void> edit(int index) async {
    final existing = diners[index];
    var diet =
        const {
          'Ohne Einschränkung',
          'Vegetarisch',
          'Vegan',
        }.contains(existing.diet)
        ? existing.diet
        : 'Ohne Einschränkung';
    final exclusions = {...existing.exclusions};
    var extra = exclusions
        .where((e) => !planningAllergens.contains(e))
        .join(', ');
    var confirmed = existing.rulesKnown;
    final result = await showDialog<PlanningDiner>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Essensregeln · ${existing.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Diese Angaben gelten verbindlich für gemeinsame Vorschläge und sind im Haushalt sichtbar.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: diet,
                  decoration: const InputDecoration(
                    labelText: 'Ernährungsweise',
                  ),
                  isExpanded: true,
                  items: [
                    for (final d in ['Ohne Einschränkung', ...planningDiets])
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (v) => setDialog(() {
                    diet = v!;
                    confirmed = false;
                  }),
                ),
                const SizedBox(height: 12),
                const Text('Allergien und feste Ausschlüsse'),
                for (final allergen in planningAllergens)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(allergen),
                    value: exclusions.contains(allergen),
                    onChanged: (v) => setDialog(() {
                      if (v == true) {
                        exclusions.add(allergen);
                      } else {
                        exclusions.remove(allergen);
                      }
                      confirmed = false;
                    }),
                  ),
                TextFormField(
                  initialValue: extra,
                  decoration: const InputDecoration(
                    labelText: 'Weitere feste Ausschlüsse, mit Komma',
                  ),
                  onChanged: (v) => setDialog(() {
                    extra = v;
                    confirmed = false;
                  }),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Weitere Ausschlüsse erfordern entsprechend geprüfte Rezeptangaben. Solange diese fehlen, gibt es keine automatische Freigabe.',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Angaben geprüft – auch keine Allergien ist eine ausdrückliche Angabe.',
                  ),
                  value: confirmed,
                  onChanged: (v) => setDialog(() => confirmed = v == true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                PlanningDiner(
                  id: existing.id,
                  name: existing.name,
                  participates: existing.participates,
                  confirmed: confirmed,
                  diet: diet,
                  exclusions: {
                    ...exclusions.where(planningAllergens.contains),
                    ...extra
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty),
                  },
                ),
              ),
              child: const Text('Übernehmen'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) setState(() => diners[index] = result);
  }

  Future<void> addGuest() async {
    var name = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weitere mitessende Person'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Name'),
          onChanged: (v) => name = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name.trim()),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    setState(
      () => diners.add(
        PlanningDiner(
          id: 'guest:${DateTime.now().microsecondsSinceEpoch}',
          name: result,
        ),
      ),
    );
    await edit(diners.length - 1);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mitessende & feste Regeln')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Wähle alle mitessenden Personen. Für jede aktive Person müssen die festen Regeln bestätigt sein. Der Geschmack richtet sich weiterhin nach einem persönlichen Profil.',
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < diners.length; i++)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(diners[i].name),
                        subtitle: Text(
                          !diners[i].participates
                              ? 'Isst nicht mit'
                              : !diners[i].rulesKnown
                              ? 'Feste Regeln noch unbekannt'
                              : '${diners[i].diet} · ${diners[i].exclusions.isEmpty ? 'keine festen Ausschlüsse' : diners[i].exclusions.join(', ')}',
                        ),
                        value: diners[i].participates,
                        onChanged: widget.readOnly
                            ? null
                            : (v) => setState(() {
                                final d = diners[i];
                                diners[i] = PlanningDiner(
                                  id: d.id,
                                  name: d.name,
                                  participates: v,
                                  confirmed: d.confirmed,
                                  diet: d.diet,
                                  exclusions: d.exclusions,
                                );
                              }),
                      ),
                      TextButton(
                        onPressed: widget.readOnly ? null : () => edit(i),
                        child: const Text('Feste Regeln bearbeiten'),
                      ),
                      if (diners[i].id.startsWith('guest:'))
                        TextButton(
                          onPressed: widget.readOnly
                              ? null
                              : () => setState(() => diners.removeAt(i)),
                          child: const Text('Weitere Person entfernen'),
                        ),
                    ],
                  ),
                ),
              ),
            if (!widget.readOnly)
              OutlinedButton.icon(
                onPressed: addGuest,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Weitere mitessende Person'),
              ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: widget.readOnly
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, diners),
                child: const Text('Gemeinsame Regeln speichern'),
              ),
            ),
          ),
  );
}
