part of 'planning_page.dart';

extension _ShoppingViews on _PlanningPageState {
  static const _markets = [('Marktgrün', 58.50, 3.90), ('Frischmarkt', 60.20, 4.90), ('Nahkauf', 62.90, 4.90)];
  static const _products = [
    ('Basmatireis', '1 × 500 g · 3,58 € / kg', 1.79),
    ('Kichererbsen', '2 × 400 g · je 0,79 €', 1.58),
    ('Cherry-Tomaten · Angebot', '2 × 250 g · je 1,49 €', 2.98),
    ('Haferflocken', '1 × 500 g · 1,98 € / kg', 0.99),
    ('Haferdrink Natur', '1 × 1 l · Alternative zum Barista-Drink', 1.49),
    ('Zucchini', '2 Stück · Beispielpackung', 2.49),
    ('Babyspinat', '2 × 200 g', 3.49),
    ('Kartoffeln', '1 × 2 kg', 4.49),
    ('Olivenöl', '1 × 500 ml', 5.49),
    ('Rote Linsen', '1 × 500 g', 2.99),
    ('Kokosmilch', '2 × 400 ml', 3.99),
    ('Nüsse', '1 × 250 g', 4.99),
    ('Zitronen', '1 Netz', 2.19),
    ('Reisnudeln', '1 × 500 g', 3.29),
    ('Kräuter', '2 Bund', 4.59),
    ('Brokkoli', '2 Stück', 3.79),
    ('Paprika', '1 Packung', 2.79),
    ('Gewürze', '1 Beispielpackung', 5.09),
  ];
  String get marketName => _markets[selectedMarket].$1;
  double get demoArticleTotal => _markets[selectedMarket].$2 - (includeOatDrink ? 0 : 1.49);
  double get demoDeliveryFee => _markets[selectedMarket].$3;
  double get demoShoppingTotal => demoArticleTotal + demoDeliveryFee;
  int get demoProductCount => includeOatDrink ? 18 : 17;

  List<Widget> shoppingFlow() => switch (shoppingPage) {
    1 => selfShoppingView(),
    2 => deliveryView(),
    _ => basketView(),
  };

  Widget shoppingActionBar() => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 1100),
    child: Padding(padding: const EdgeInsets.fromLTRB(22, 12, 22, 12), child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: double.infinity, child: FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
        onPressed: () { if (shoppingPage == 2) { demoHandoff(); } else { update(() => shoppingPage = 1); } },
        icon: Icon(shoppingPage == 2 ? Icons.north_east : Icons.shopping_basket_outlined, size: 18),
        label: Text(shoppingPage == 2 ? 'Weiter zu $marketName' : 'Selbst einkaufen'),
      )),
      gap(8),
      Text(shoppingPage == 2 ? 'Noch keine Bestellung · Demo ohne Händleranbindung' : 'Ohne Lieferdienst. Mit deiner Einkaufsliste.', textAlign: TextAlign.center, style: muted.copyWith(fontSize: 12)),
    ])),
  ));

  List<Widget> basketView() => [
    title('Dein smarter Einkauf'), gap(8),
    Text('${buildShoppingList(plan.values).length} Zutaten · Für euren Wochenplan', style: muted), gap(14),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Du entscheidest, wie.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), gap(10),
      recipeAction('Selbst einkaufen', true, () => update(() => shoppingPage = 1)), gap(10),
      recipeAction('Vergleichen & liefern lassen', false, () => update(() => shoppingPage = 2)),
    ]), padding: const EdgeInsets.all(16)), gap(14),
    surveyCard('8,20 € gespart. Alles drin.', 'Demo-Beispiel: 62,40 € statt 70,60 €. Die Ersparnis gehört zum Beispielwarenkorb und wird nicht aus deinem Wochenplan berechnet.', color: AppColors.softGreen), gap(14),
    section('Dein Supermarktvergleich', action: const Text('3 Märkte · Demo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < _markets.length; i++) ...[
        if (i > 0) const SizedBox(width: 9),
        Expanded(child: Semantics(selected: selectedMarket == i, button: true, child: InkWell(
          onTap: () => update(() => selectedMarket = i), borderRadius: BorderRadius.circular(17),
          child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: selectedMarket == i ? AppColors.sage : Colors.white, borderRadius: BorderRadius.circular(17)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_markets[i].$1, style: TextStyle(fontSize: 12, color: selectedMarket == i ? Colors.white : AppColors.lightText)), gap(7),
              Text(euro(_markets[i].$2 + _markets[i].$3 - (includeOatDrink ? 0 : 1.49)), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: selectedMarket == i ? Colors.white : AppColors.lightText)), gap(7),
              Text('inkl. ${euro(_markets[i].$3)}', style: TextStyle(fontSize: 12, color: selectedMarket == i ? Colors.white : AppColors.muted)),
            ])),
        ))),
      ],
    ]), gap(14),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      section('Passende Produkte'),
      Text('Produktbeispiele aus Marktgrün · unabhängig von deinem Plan und deinen Ausschlüssen. Andere Märkte haben abweichende Beispielpreise.', style: muted), gap(14),
      for (final product in (showAllDemoProducts ? _products : _products.take(4)))
        if (includeOatDrink || product.$1 != 'Haferdrink Natur') ...[
          costRow(product.$1, euro(product.$3)), gap(4), Text(product.$2, style: muted.copyWith(fontSize: 12)), gap(14),
        ],
      TextButton(onPressed: () => update(() => showAllDemoProducts = !showAllDemoProducts), child: Text(showAllDemoProducts ? 'Weniger anzeigen ↑' : 'Alle $demoProductCount Artikel anzeigen ↓')),
    ]), padding: const EdgeInsets.all(16)), gap(14),
    surveyCard('So wird aus dem Rezept ein Produkt', 'Beispiel: 650 g Reis benötigt − 150 g im Vorrat = 500 g Einkauf → 1 Packung à 500 g. Dein tatsächlicher Vorrat wird noch nicht automatisch abgezogen.', color: AppColors.cream), gap(14),
    costRow('Mit Lieferung · Demo', euro(demoShoppingTotal), emphasis: true), gap(14),
    recipeAction('Lieferung bei $marketName prüfen', false, () => update(() => shoppingPage = 2)), gap(14),
    Text('Beispielmärkte und -preise · keine Live-Verbindung. Deine echte Einkaufsliste erreichst du über „Selbst einkaufen“.', style: muted),
  ];

  Widget costRow(String label, String value, {bool emphasis = false}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(child: Text(label, style: TextStyle(fontSize: emphasis ? 18 : 14, fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400))),
    const SizedBox(width: 12), Text(value, style: TextStyle(fontSize: emphasis ? 26 : 14, fontWeight: FontWeight.w600)),
  ]);

  List<Widget> deliveryView() => [
    proposalBack('Zurück zum Warenkorb', () => update(() => shoppingPage = 0)), gap(14),
    title('Fast am Esstisch.'), gap(6), Text('Prüfen, übergeben, beim Händler bezahlen.', style: muted), gap(14),
    panel(const Wrap(spacing: 16, runSpacing: 8, children: [Text('✓ Plan'), Text('✓ Warenkorb'), Text('3 Bestellung')]), color: AppColors.softGreen, padding: const EdgeInsets.all(12)), gap(14),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(marketName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))), Text('$demoProductCount / $demoProductCount · Demo', style: const TextStyle(fontSize: 12, color: AppColors.sage))]), gap(10),
      Text('Lieferung an $deliveryAddress', style: const TextStyle(fontSize: 14)), gap(8),
      Text(deliverySlot, style: muted),
      TextButton(onPressed: editDemoDelivery, child: const Text('Lieferdetails ändern')),
      const Text('Mindestbestellwert 50 € erreicht ✓ · Beispiel', style: TextStyle(color: AppColors.sage, fontSize: 13)),
    ]), padding: const EdgeInsets.all(16)), gap(14),
    panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Eine Alternative für deinen Einkauf', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF84531E))), gap(10),
      Text('Haferdrink Barista ist im Beispiel nicht verfügbar.', style: muted), gap(10),
      costRow(includeOatDrink ? '✓ Haferdrink Natur · 1 l' : 'Haferdrink weggelassen', includeOatDrink ? '1,49 €' : '0,00 €'), gap(10),
      Text(includeOatDrink ? '0,80 € günstiger · im Beispielgesamtpreis enthalten' : '1,49 € vom Beispielgesamtpreis abgezogen', style: muted.copyWith(fontSize: 12)),
      TextButton(onPressed: editDemoAlternative, child: const Text('Alternative ändern →')),
    ]), color: const Color(0xFFF6E9CF), padding: const EdgeInsets.all(16)), gap(14),
    panel(Column(children: [
      costRow('Artikel ($demoProductCount) · Demo', euro(demoArticleTotal)), gap(14),
      costRow('Lieferung', euro(demoDeliveryFee)), gap(14), costRow('Pfand', '0,00 €'), gap(14),
      costRow('Gesamt', euro(demoShoppingTotal), emphasis: true), gap(10),
      Align(alignment: Alignment.centerLeft, child: Text('${euro((budget - demoShoppingTotal).abs())} ${demoShoppingTotal <= budget ? 'unter' : 'über'} deinem Wochenbudget · Beispielvergleich', style: muted.copyWith(fontSize: 13))),
    ]), padding: const EdgeInsets.all(16)), gap(14),
    surveyCard('Du behältst das letzte Wort.', 'Bei einer echten Händleranbindung bestätigst du endgültige Preise, Lieferzeit und Zahlung erst beim Händler. Diese Demo überträgt keine Daten und löst keine Bestellung aus.'),
  ];

  Future<void> editDemoDelivery() async {
    var address = deliveryAddress;
    var slot = deliverySlot;
    final save = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Lieferdetails · Demo'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(initialValue: address, decoration: const InputDecoration(labelText: 'Lieferadresse'), onChanged: (v) => address = v), gap(14),
        TextFormField(initialValue: slot, decoration: const InputDecoration(labelText: 'Wunsch-Lieferzeit'), onChanged: (v) => slot = v),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')), TextButton(onPressed: () { if (address.trim().isNotEmpty && slot.trim().isNotEmpty) Navigator.pop(context, true); }, child: const Text('Übernehmen'))],
    ));
    if (save == true && mounted) update(() { deliveryAddress = address.trim(); deliverySlot = slot.trim(); });
  }

  Future<void> editDemoAlternative() async {
    final choice = await showModalBottomSheet<bool>(context: context, builder: (context) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Produktalternative · Demo', style: Theme.of(context).textTheme.titleLarge), gap(14),
      ListTile(title: const Text('Haferdrink Natur · 1 l'), subtitle: const Text('1,49 € · Beispielpreis'), leading: Icon(includeOatDrink ? Icons.radio_button_checked : Icons.radio_button_off), onTap: () => Navigator.pop(context, true)),
      ListTile(title: const Text('Artikel weglassen'), subtitle: const Text('Vom Beispielwarenkorb entfernen'), leading: Icon(!includeOatDrink ? Icons.radio_button_checked : Icons.radio_button_off), onTap: () => Navigator.pop(context, false)),
    ]))));
    if (choice != null && mounted) update(() => includeOatDrink = choice);
  }

  void demoHandoff() => showDialog<void>(context: context, builder: (context) => AlertDialog(
    title: const Text('Händlerübergabe · Demo'),
    content: Text('Der Beispielwarenkorb bei $marketName beträgt ${euro(demoShoppingTotal)}. Es ist noch kein Händler angebunden. Es wurden keine Daten übertragen und keine Bestellung aufgegeben.'),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zurück')), TextButton(onPressed: () { Navigator.pop(context); update(() => shoppingPage = 1); }, child: const Text('Selbst einkaufen'))],
  ));
}
