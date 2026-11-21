part of 'planning_page.dart';

extension _HouseholdViews on _PlanningPageState {
  List<Widget> householdFlow() {
    if (householdPage == 0) return profileView();
    if (householdPage == 14) {
      return [
        proposalBack('Zurück zum Profil', () => householdGo(0)),
        gap(14),
        ...connectedHouseholdView(),
      ];
    }
    if (householdPage == 15) {
      return [
        proposalBack('Zurück zum Profil', () => householdGo(0)),
        gap(14),
        ...householdView(),
      ];
    }
    if (accountConnected && (householdPage < 7 || readOnlyShared)) {
      return connectedHouseholdView();
    }
    return switch (householdPage) {
      1 => householdMembersView(),
      2 => householdInviteView(),
      3 => householdRoleView(),
      4 => householdLeaveView(),
      5 => householdPreferencesView(),
      6 => householdMealsView(),
      11 => weeklyReviewView(),
      12 => weeklyReviewEditor(),
      13 => weeklyReviewNextView(),
      7 => householdRulesView(),
      8 => householdRuleEditor(),
      9 => hiddenRecipesView(),
      10 => dislikeEditorView(),
      _ => profileView(),
    };
  }

  void householdGo(int page) => update(() => householdPage = page);
  Widget householdBack([int page = 1, String label = 'Mitglieder']) => proposalBack(label, () => householdGo(page));
  bool get canLeaveHouseholdDemo => demoAlexRole == 'Verwaltung' && leaveConfirmed;

  List<Widget> householdMembersView() => [
    householdBack(0, 'Haushalt'), gap(14), title(householdName), gap(12),
    Text(householdDemoJoined ? '2 Beispielmitglieder · du verwaltest den Haushalt' : 'Demo-Haushalt verlassen', style: muted), gap(18),
    surveyCard('Du · Verwaltung', 'Mitglieder und Rollen, gemeinsame Einstellungen sowie Plan, Liste und Vorrat verwalten.'), gap(18),
    if (householdDemoJoined) ...[
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Alex · Beispielmitglied', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)), gap(8),
        Text(demoAlexRole, style: const TextStyle(color: AppColors.sage, fontWeight: FontWeight.w600)), gap(8),
        Text('Lokale Rollen-Demo. Alex ist noch kein verbundenes Benutzerkonto.', style: muted), gap(12),
        recipeAction('Rolle & Rechte verwalten', false, () => update(() { pendingMemberRole = demoAlexRole; roleConfirmed = false; householdPage = 3; })),
      ])), gap(18),
      surveyCard(householdInvitations.isEmpty ? 'Keine offenen Einladungsentwürfe' : '${householdInvitations.length} Einladungsentwürfe', 'Entwürfe werden lokal gespeichert. Es wird keine E-Mail versendet und niemand erhält Zugriff.', color: AppColors.softGreen),
      for (final invitation in householdInvitations) ListTile(title: Text(invitation['email'] as String), subtitle: Text('${invitation['role']} · nicht versendet'), trailing: IconButton(tooltip: 'Entwurf entfernen', icon: const Icon(Icons.close), onPressed: () { update(() => householdInvitations.remove(invitation)); savePreferences(); })), gap(14),
      recipeAction('Gemeinsame & persönliche Vorlieben', false, () => householdGo(5)), gap(12),
      recipeAction('Ausschlüsse & Abneigungen', false, () => householdGo(7)), gap(12),
      recipeAction('Haushalt verlassen', false, () => update(() { leaveConfirmed = false; householdPage = 4; })),
    ] else ...[
      surveyCard('Dein persönliches Konto bleibt bestehen.', 'Der Austritt betrifft nur den lokalen Beispielhaushalt. Dein Wochenplan, Vorrat und deine persönlichen Daten wurden nicht gelöscht.', color: AppColors.softGreen), gap(14),
      recipeAction('Demo-Haushalt wiederherstellen', false, () { update(() => householdDemoJoined = true); savePreferences(); }),
    ], gap(14), Text('Haushaltsfreigabe und Rechteprüfung auf dem Server sind noch nicht angebunden.', style: muted),
  ];

  List<Widget> householdInviteView() => [
    householdBack(), gap(14), title('Zusammen planen.'), gap(12), Text('Lade eine Person in „$householdName“ ein · Demo.', style: muted), gap(18),
    TextFormField(initialValue: invitationEmail, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'E-Mail-Adresse', hintText: 'sam@example.com', errorText: invitationError), onChanged: (v) => invitationEmail = v), gap(18),
    section('Rolle nach Annahme'),
    for (final role in ['Mitglied', 'Nur ansehen']) ...[
      surveyChoice(role, invitationRole == role, () => update(() => invitationRole = role), subtitle: role == 'Mitglied' ? 'Kann Plan, Liste und Vorrat bearbeiten. Keine Mitglieder- oder Rollenverwaltung.' : 'Gemeinsame Daten lesen. Eigenes Profil selbst verwalten.'), gap(14),
    ],
    surveyCard('Verwaltung wird separat vergeben.', 'Eine Einladung allein fügt noch kein Mitglied hinzu. Eigene Rezepte und private Notizen werden nicht automatisch geteilt.', color: AppColors.cream), gap(14),
    recipeAction('Einladungslink · Demo', false, () => showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Einladungslink'), content: const Text('Ein nutzbarer Einladungslink benötigt die Haushaltsanbindung. In dieser Demo wird kein gültiger Link erzeugt.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen'))]))),
  ];

  void saveInvitationDraft() {
    final email = invitationEmail.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) { update(() => invitationError = 'Bitte eine gültige E-Mail-Adresse eingeben.'); return; }
    if (email == widget.user?.email?.toLowerCase() || householdInvitations.any((i) => i['email'] == email)) { update(() => invitationError = 'Für diese Adresse ist kein neuer Entwurf möglich.'); return; }
    update(() { householdInvitations.add({'email': email, 'role': invitationRole}); invitationEmail = ''; invitationError = null; householdPage = 1; });
    savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Einladungsentwurf gespeichert · keine E-Mail versendet.')));
  }

  List<Widget> householdRoleView() => [
    householdBack(), gap(14), title('Alex’ Rolle ändern.'), gap(12), Text('Bisher: $demoAlexRole · lokale Rollen-Demo', style: muted), gap(18),
    for (final (role, description) in [
      ('Verwaltung', 'Mitglieder einladen, Rollen ändern und gemeinsame Einstellungen verwalten. Dazu Plan, Liste und Vorrat bearbeiten.'),
      ('Mitglied', 'Plan, Liste und Vorrat bearbeiten. Keine Rollen- oder Mitgliederverwaltung.'),
      ('Nur ansehen', 'Gemeinsame Daten lesen. Eigene persönliche Regeln selbst pflegen.'),
    ]) ...[surveyChoice(role, pendingMemberRole == role, () => update(() { pendingMemberRole = role; roleConfirmed = false; }), subtitle: description), gap(14)],
    surveyCard('Rolle ist nicht gleich Profilzugriff.', 'Persönliche Allergien anderer Personen werden nicht überschrieben. Die letzte verwaltende Person darf erst mit Nachfolge austreten.', color: AppColors.cream),
    if (pendingMemberRole == 'Verwaltung' && demoAlexRole != 'Verwaltung') CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Erweiterte Rechte für Alex bestätigen'), value: roleConfirmed, onChanged: (v) => update(() => roleConfirmed = v ?? false)),
  ];

  List<Widget> householdLeaveView() => [
    householdBack(), gap(14), title('Haushalt verlassen?'), gap(12), Text('Du verlässt den Demo-Haushalt „$householdName“, nicht dein persönliches Konto.', style: muted), gap(18),
    surveyCard(demoAlexRole == 'Verwaltung' ? '✓ Alex übernimmt die Verwaltung' : 'Zuerst eine Nachfolge festlegen', demoAlexRole == 'Verwaltung' ? 'Eine weitere Verwaltung bleibt im Beispielhaushalt.' : 'Vergib zuerst die Rolle Verwaltung an Alex. Ohne Nachfolge bleibt der Austritt gesperrt.', color: AppColors.softGreen), gap(18),
    surveyCard('Das bedeutet der Austritt', 'Bei einer echten Haushaltsfreigabe endet dein Zugriff auf gemeinsame Pläne, Liste und Vorrat. Deine eigenen Rezepte und persönlichen Vorlieben bleiben bei dir. In dieser lokalen Demo werden keine echten Daten oder Zugriffsrechte verändert.'), gap(18),
    surveyCard('Gemeinsame Planung wird neu geprüft.', 'Gemeinsame Regeln werden nicht still gelöscht. Dein persönlicher Wochenplan und Vorrat bleiben erhalten.', color: AppColors.cream), gap(14),
    CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Ich möchte diesen Demo-Haushalt verlassen.'), value: leaveConfirmed, onChanged: (v) => update(() => leaveConfirmed = v ?? false)),
  ];

  List<Widget> householdPreferencesView() => [
    householdBack(0, 'Haushalt'), gap(14), title('Deins. Unseres.'), gap(12), Text('Persönliche Vorlieben und gemeinsame Planregeln bleiben unterscheidbar.', style: muted), gap(18),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${householdName.toUpperCase()} · PLANREGELN', style: const TextStyle(color: Colors.white, fontSize: 13)), gap(10),
      Text('$planningDays Abendessen · $servings Personen', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w600)), gap(10),
      Text('${planBudget == null ? 'Kein Planbudget' : euro(planBudget!)} · $diet\n${maxMinutes == 0 ? 'Flexible Kochzeit' : 'Bis $maxMinutes Minuten'}', style: const TextStyle(color: Colors.white, fontSize: 15)), gap(10),
      Text(exclusions.isEmpty ? 'Keine gemeinsamen Ausschlüsse' : 'Fest ausgeschlossen: ${exclusions.join(', ')}', style: const TextStyle(color: Colors.white, fontSize: 14)),
    ]), color: AppColors.sage), gap(18),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      section('Du · persönlich'), Text('Eigene Ausschlüsse: ${personalExclusions.isEmpty ? 'keine hinterlegt' : personalExclusions.join(', ')}', style: muted),
      Text('Abneigungen: ${personalDislikes.isEmpty ? 'keine hinterlegt' : personalDislikes.join(', ')}', style: muted), gap(10),
      recipeAction('Meine Vorlieben bearbeiten', false, () => householdGo(7)),
    ])), gap(18),
    surveyCard('Alex · Beispielprofil', 'Noch keine persönlichen Gesundheitsregeln hinterlegt. Ein verbundenes Mitglied würde sein Profil selbst verwalten.'), gap(18),
    surveyCard('Gemeinsam kochen, niemanden übergehen.', 'Feste Ausschlüsse gelten immer. Abneigungen beeinflussen die Reihenfolge. Eine persönliche Abneigung ändert kein anderes Mitglied und löscht keine Rezeptausblendung.', color: AppColors.softGreen), gap(14),
    recipeAction('Gerichte & Portionen pro Person', false, openHouseholdMeals),
  ];

  void openHouseholdMeals({int? day}) {
    final available = eligibleRecipes;
    update(() {
      tab = 4; householdPage = 6; householdMealDay = day ?? selectedDay;
      firstHouseholdRecipe = plan[householdMealDay]?.recipe ?? (available.isEmpty ? null : available.first);
      secondHouseholdRecipe = available.length > 1 ? available[1] : firstHouseholdRecipe;
      firstHouseholdPortions = 2; secondHouseholdPortions = 1;
    });
  }
  List<PlannedMeal> get householdMealsDraft => [
    if (firstHouseholdRecipe != null) PlannedMeal(firstHouseholdRecipe!, separateHouseholdMeals ? firstHouseholdPortions : firstHouseholdPortions + secondHouseholdPortions),
    if (separateHouseholdMeals && secondHouseholdRecipe != null) PlannedMeal(secondHouseholdRecipe!, secondHouseholdPortions),
  ];

  List<Widget> householdMealsView() => [
    householdBack(5, 'Gemeinsame Planung'), gap(14), title('Zwei Personen. ${firstHouseholdPortions + secondHouseholdPortions} Portionen.'), gap(12),
    DropdownButtonFormField<int>(initialValue: householdMealDay, decoration: const InputDecoration(labelText: 'Geplanten Tag bearbeiten'), items: [for (var i = 0; i < 7; i++) DropdownMenuItem(value: i, child: Text('${_PlanningPageState.days[i]} · ${displayDate(week.add(Duration(days: i)))}'))], onChanged: (v) { if (v != null) update(() => householdMealDay = v); }), gap(18),
    Row(children: [Expanded(child: recipeAction('Gemeinsam', !separateHouseholdMeals, () => update(() => separateHouseholdMeals = false))), const SizedBox(width: 8), Expanded(child: recipeAction('Getrennte Gerichte', separateHouseholdMeals, () => update(() => separateHouseholdMeals = true)))]), gap(18),
    for (var person = 0; person < 2; person++) ...[
      panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        section(person == 0 ? 'Du' : 'Alex · Demo'),
        Text((person == 0 || !separateHouseholdMeals ? firstHouseholdRecipe : secondHouseholdRecipe)?.name ?? 'Noch kein passendes Gericht', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), gap(10),
        if (person == 0 || separateHouseholdMeals) recipeAction('Anderes Gericht wählen', false, () => chooseHouseholdRecipe(person)), gap(10),
        Row(children: [IconButton.filledTonal(tooltip: 'Weniger Portionen', onPressed: (person == 0 ? firstHouseholdPortions : secondHouseholdPortions) <= 1 ? null : () => update(() { if (person == 0) { firstHouseholdPortions--; } else { secondHouseholdPortions--; } }), icon: const Icon(Icons.remove)),
          Expanded(child: Text('${person == 0 ? firstHouseholdPortions : secondHouseholdPortions} Portionen', textAlign: TextAlign.center)),
          IconButton.filledTonal(tooltip: 'Mehr Portionen', onPressed: (person == 0 ? firstHouseholdPortions : secondHouseholdPortions) >= 20 ? null : () => update(() { if (person == 0) { firstHouseholdPortions++; } else { secondHouseholdPortions++; } }), icon: const Icon(Icons.add))]),
        gap(8), Text(person == 0 ? 'Eigene feste Regeln und Abneigungen berücksichtigen.' : 'Beispielprofil ohne eigene Gesundheitsangaben.', style: muted),
      ])), gap(18),
    ],
    surveyCard('Gesamt: ${householdMealsDraft.length} ${householdMealsDraft.length == 1 ? 'Gericht' : 'Gerichte'} · ${firstHouseholdPortions + secondHouseholdPortions} Portionen', 'Mengen je Gericht skalieren und gleiche Zutaten für die Einkaufsliste bündeln.', color: AppColors.softGreen), gap(18),
    surveyCard('Feste Ausschlüsse sind keine Kompromisse.', 'Fehlende geprüfte Angaben bei festen Ausschlüssen sperren die Übernahme. Kosten sind ohne Produktpreise nicht berechenbar.', color: AppColors.cream),
  ];

  Future<void> chooseHouseholdRecipe(int person) async {
    final available = recipes.where((r) => recipeMatchesPlanning(r, includePersonal: person == 0 || !separateHouseholdMeals)).toList();
    if (person == 0 || !separateHouseholdMeals) available.sort((a, b) => dislikeScore(a).compareTo(dislikeScore(b)));
    final recipe = await showModalBottomSheet<Recipe>(context: context, isScrollControlled: true, builder: (context) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .65, child: ListView(padding: const EdgeInsets.all(22), children: [
      Text('Gericht auswählen', style: Theme.of(context).textTheme.headlineSmall), gap(14),
      if (available.isEmpty) const Text('Keine passenden Gerichte. Deine festen Regeln bleiben bestehen.'),
      for (final r in available) ListTile(title: Text(r.name), subtitle: Text('${r.minutes} Minuten'), onTap: () => Navigator.pop(context, r)),
    ]))));
    if (recipe != null && mounted) update(() { if (person == 0) { firstHouseholdRecipe = recipe; } else { secondHouseholdRecipe = recipe; } });
  }

  Future<void> reviewHouseholdMeals() async {
    final meals = householdMealsDraft;
    if (firstHouseholdRecipe == null || (separateHouseholdMeals && secondHouseholdRecipe == null)) return;
    if (!recipeMatchesPlanning(firstHouseholdRecipe!) || (separateHouseholdMeals && !recipeMatchesPlanning(secondHouseholdRecipe!, includePersonal: false))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Die Auswahl erfüllt deine aktuellen festen Planregeln nicht. Bitte wähle erneut.'))); return;
    }
    final ingredients = buildShoppingList(meals);
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Portionen & Budget prüfen'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_PlanningPageState.days[householdMealDay]} · ${firstHouseholdPortions + secondHouseholdPortions} Portionen'), gap(12),
        for (final i in ingredients) Text('${amountLabel(i.quantity, i.unit)} ${i.name}'), gap(14),
        const Text('Preise fehlen noch. Das Budget kann nicht geprüft werden. Beim Übernehmen ersetzt diese Auswahl das bisherige Gericht an diesem Tag.'),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zurück')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Trotzdem übernehmen'))],
    ));
    if (confirmed != true || !mounted || saving) return;
    final total = firstHouseholdPortions + secondHouseholdPortions;
    // Store a combined meal snapshot so existing week persistence and shopping aggregation remain compatible.
    final combined = Recipe(id: 'household-${dateKey(week)}-$householdMealDay', name: meals.map((m) => m.recipe.name).toSet().join(' + '), minutes: meals.map((m) => m.recipe.minutes).reduce((a, b) => a > b ? a : b), servings: total,
      ingredients: ingredients, steps: [for (final m in meals) ...['${m.recipe.name} · ${m.servings} Portionen', ...renderedRecipeSteps(m.recipe, portions: m.servings)]],
      verifiedAllergens: meals.every((m) => m.recipe.verifiedAllergens != null) ? {for (final m in meals) ...m.recipe.verifiedAllergens!} : null,
      verifiedDiets: meals.every((m) => m.recipe.verifiedDiets != null) ? meals.first.recipe.verifiedDiets!.where((d) => meals.every((m) => m.recipe.verifiedDiets!.contains(d))).toSet() : null);
    if (!await saveMeals({...plan, householdMealDay: PlannedMeal(combined, total)}) || !mounted) return;
    update(() { tab = 1; householdPage = 0; proposalConfirmed = false; draft = null; swappingDay = null; selectedDay = householdMealDay; });
  }

  Future<void> editCommonRules() async {
    var newDiet = diet; var minutes = maxMinutes; var newBudget = planBudget; var validBudget = true;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      title: const Text('Gemeinsame Planregeln'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(isExpanded: true, initialValue: newDiet, decoration: const InputDecoration(labelText: 'Ernährungsweise'), items: [for (final d in ['Ohne Einschränkung', 'Vegetarisch', 'Vegan']) DropdownMenuItem(value: d, child: Text(d, maxLines: 1, overflow: TextOverflow.ellipsis))], onChanged: (v) => newDiet = v!), gap(12),
        DropdownButtonFormField<int>(isExpanded: true, initialValue: minutes, decoration: const InputDecoration(labelText: 'Kochzeit'), items: [for (final m in [15, 30, 45, 0]) DropdownMenuItem(value: m, child: Text(m == 0 ? 'Flexibel' : 'Bis $m Minuten', maxLines: 1, overflow: TextOverflow.ellipsis))], onChanged: (v) => minutes = v!), gap(12),
        TextFormField(initialValue: newBudget?.toStringAsFixed(2) ?? '', decoration: const InputDecoration(labelText: 'Planbudget · leer = kein Limit'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) { newBudget = v.trim().isEmpty ? null : double.tryParse(v.replaceAll(',', '.')); setDialog(() => validBudget = v.trim().isEmpty || (newBudget != null && newBudget!.isFinite && newBudget! > 0)); }),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')), TextButton(onPressed: () { if (validBudget) Navigator.pop(context, true); }, child: const Text('Speichern'))],
    )));
    if (confirmed == true && mounted) { update(() { diet = newDiet; maxMinutes = minutes; planBudget = newBudget; planBudgetInitialized = true; }); savePreferences(); }
  }

  Widget householdActionBar() {
    if (householdPage >= 14) return const SizedBox.shrink();
    if(widget.client != null && widget.user == null) return const SizedBox.shrink();
    if(accountConnected && (householdPage < 7 || readOnlyShared)) return const SizedBox.shrink();
    if (householdPage >= 11) return weeklyReviewActionBar();
    if (householdPage >= 7) return rulesActionBar();
    final label = switch (householdPage) { 1 => 'Mitglied einladen +', 2 => 'Einladungsentwurf speichern', 3 => 'Rolle für Alex speichern', 4 => 'Demo-Haushalt verlassen', 5 => 'Gemeinsame Planregeln bearbeiten', _ => 'Portionen & Budget prüfen' };
    final disabled = saving || loading || (householdPage == 4 && !canLeaveHouseholdDemo) || (householdPage == 3 && pendingMemberRole == 'Verwaltung' && demoAlexRole != 'Verwaltung' && !roleConfirmed);
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: Padding(padding: const EdgeInsets.fromLTRB(22, 12, 22, 12), child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: double.infinity, child: FilledButton(onPressed: disabled ? null : () {
        switch (householdPage) {
          case 1: update(() { householdPage = 2; invitationError = null; }); break;
          case 2: saveInvitationDraft(); break;
          case 3: update(() { demoAlexRole = pendingMemberRole; householdPage = 1; }); savePreferences(); break;
          case 4: if (canLeaveHouseholdDemo) { update(() { householdDemoJoined = false; householdPage = 1; }); savePreferences(); } break;
          case 5: editCommonRules(); break;
          case 6: reviewHouseholdMeals(); break;
        }
      }, style: FilledButton.styleFrom(minimumSize: const Size(0, 56), backgroundColor: householdPage == 4 ? const Color(0xFF8A3A2C) : AppColors.sage), child: Text(label, textAlign: TextAlign.center))), gap(8),
      Text(householdPage == 6 ? 'Mengen prüfen und erst danach deinen Wochenplan ändern.' : 'Lokale Demo · keine Einladungen oder Rechte auf dem Server.', textAlign: TextAlign.center, style: muted.copyWith(fontSize: 12)),
    ]))));
  }
}
