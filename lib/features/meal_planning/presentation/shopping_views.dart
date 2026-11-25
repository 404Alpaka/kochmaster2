part of 'planning_page.dart';

extension _ShoppingViews on _PlanningPageState {
  String shoppingStockLabel(PantryIngredientMatch match) {
    if (match.availableQuantity <= 0) {
      return 'Kein vergleichbarer Vorrat erfasst';
    }
    return 'Vorrat: ${amountLabel(match.availableQuantity, match.unit)} · Noch nötig: ${amountLabel(match.missingQuantity, match.unit)}';
  }

  Future<void> copyShoppingList() async {
    final items = shoppingBasketItems;
    final stock = compareShoppingPantry(items, pantry, pantryToday);
    final text = StringBuffer(
      'Einkaufsliste · ${displayDate(week)} – ${displayDate(week.add(const Duration(days: 6)))}\n',
    );
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      text.writeln(
        '${checked.contains((item.ingredientId, item.unit)) ? '[x]' : '[ ]'} ${item.name} · ${amountLabel(item.quantity, item.unit)}',
      );
      if (stock[i].availableQuantity > 0) {
        text.writeln('    ${shoppingStockLabel(stock[i])}');
      }
    }
    text.writeln(
      'Vorrat heute: Haltbarkeit vor Verwendung prüfen. Mengen wurden nicht automatisch abgezogen.',
    );
    try {
      await Clipboard.setData(ClipboardData(text: text.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Einkaufsliste kopiert. Du kannst sie jetzt in einer Nachricht einfügen.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kopieren fehlgeschlagen. Bitte erneut versuchen.'),
        ),
      );
    }
  }

  static const _markets = [
    ('Marktgrün', 58.50, 3.90),
    ('Frischmarkt', 60.20, 4.90),
    ('Nahkauf', 62.90, 4.90),
  ];
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
  double get demoArticleTotal =>
      _markets[selectedMarket].$2 - (includeOatDrink ? 0 : 1.49);
  double get demoDeliveryFee => _markets[selectedMarket].$3;
  double get demoShoppingTotal => demoArticleTotal + demoDeliveryFee;
  int get demoProductCount => includeOatDrink ? 18 : 17;

  bool get showingShoppingList =>
      !shoppingExample && shoppingBasketItems.isNotEmpty && shoppingPage != 2;

  bool get showShoppingAction =>
      !showingShoppingList &&
      shoppingPage != 1 &&
      (shoppingPage != 0 || cartHasItems);

  List<Widget> shoppingFlow() => showingShoppingList
      ? selfShoppingView()
      : switch (shoppingPage) {
          1 => selfShoppingView(),
          2 => deliveryView(),
          _ => basketView(),
        };

  List<IngredientAmount> get shoppingBasketItems =>
      buildShoppingList(plan.values, additionalItems: pantryShoppingItems);

  bool get cartHasItems => shoppingExample || shoppingBasketItems.isNotEmpty;
  bool get cartIsExample => shoppingExample;

  Widget shoppingActionBar() {
    if (shoppingPage == 2) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
        child: FilledButton(
          onPressed: demoHandoff,
          child: Text('Weiter zu $marketName · Demo'),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: .5),
          ),
        ),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cartIsExample ? 'Gesamt · Beispiel' : 'Gesamt',
                        style: muted.copyWith(fontSize: 11),
                      ),
                      gap(2),
                      Text(
                        cartIsExample ? euro(demoShoppingTotal) : 'Preis offen',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(176, 52),
                    ),
                    onPressed: () =>
                        update(() => shoppingPage = basketDelivery ? 2 : 1),
                    child: Text(
                      basketDelivery ? 'Lieferung prüfen' : 'Selbst einkaufen',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget shoppingBasketIllustration() => Center(
    child: SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(painter: _ShoppingBasketPainter()),
    ),
  );

  List<Widget> basketView() {
    final items = shoppingBasketItems;
    final empty = !cartHasItems;
    final totals = [
      for (final market in _markets)
        market.$2 + market.$3 - (includeOatDrink ? 0 : 1.49),
    ];
    final savings =
        totals.reduce((a, b) => a > b ? a : b) - totals[selectedMarket];
    return [
      if (empty) ...[weekPicker(), gap(16)],
      Text('Dein Einkauf', style: Theme.of(context).textTheme.headlineMedium),
      gap(4),
      Text(
        empty
            ? 'Für deinen Wochenplan'
            : '${cartIsExample ? demoProductCount : items.length} Zutaten · ${cartIsExample ? 'Beispielwarenkorb' : 'Für deinen Wochenplan'}',
        style: muted,
      ),
      if (empty) ...[
        gap(84),
        shoppingBasketIllustration(),
        gap(30),
        const Text(
          'Dein Korb ist noch leer',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        gap(10),
        Text(
          'Plane Rezepte im Wochenplan. Die Zutaten landen automatisch hier.',
          textAlign: TextAlign.center,
          style: muted.copyWith(fontSize: 14),
        ),
        gap(28),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: () => selectTab(1),
            child: Text(
              'Zum Wochenplan',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        gap(10),
        TextButton(
          onPressed: () => update(() {
            shoppingExample = true;
            selectedMarket = 0;
          }),
          child: const Text('Beispiel-Vergleich ansehen'),
        ),
      ] else ...[
        gap(16),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              for (final delivery in [false, true])
                Expanded(
                  child: Material(
                    color: basketDelivery == delivery
                        ? Theme.of(context).colorScheme.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => update(() => basketDelivery = delivery),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 6,
                        ),
                        child: Text(
                          delivery ? 'Liefern lassen' : 'Selbst einkaufen',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: basketDelivery == delivery
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: basketDelivery == delivery
                                ? AppColors.sage
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        gap(22),
        section(
          'Supermarktvergleich',
          action: Text('Beispielwerte', style: muted.copyWith(fontSize: 11)),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < _markets.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    selected: selectedMarket == index,
                    button: true,
                    label:
                        '${_markets[index].$1}, ${euro(totals[index])}, Beispiel',
                    child: Material(
                      color: selectedMarket == index
                          ? AppColors.sage
                          : Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                        side: BorderSide(
                          color: selectedMarket == index
                              ? AppColors.sage
                              : const Color(0xFFD8DED2),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => update(() => selectedMarket = index),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.textScalerOf(context).scale(10) *
                                    1.4,
                                child: index == 0
                                    ? Text(
                                        'GÜNSTIGSTER',
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: selectedMarket == index
                                              ? const Color(0xFFF4E9BD)
                                              : AppColors.sage,
                                        ),
                                      )
                                    : null,
                              ),
                              gap(4),
                              SizedBox(
                                height:
                                    MediaQuery.textScalerOf(context).scale(12) *
                                    1.3 *
                                    2,
                                child: Text(
                                  _markets[index].$1,
                                  maxLines: 2,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: selectedMarket == index
                                        ? Colors.white
                                        : AppColors.muted,
                                  ),
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  euro(totals[index]),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: selectedMarket == index
                                        ? Colors.white
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                  ),
                                ),
                              ),
                              gap(4),
                              Text(
                                'inkl. ${euro(_markets[index].$3)} Lieferung',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: selectedMarket == index
                                      ? Colors.white
                                      : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        gap(10),
        if (savings > .001) ...[
          panel(
            Text(
              '${euro(savings)} gespart gegenüber dem teuersten Markt',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF80501D),
              ),
            ),
            color: const Color(0xFFF6E7CD),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          gap(12),
        ],
        Text(
          'Beispielvergleich ohne Live-Preise${cartIsExample ? '.' : ' · unabhängig von deinem Wochenplan.'}',
          style: muted.copyWith(fontSize: 11),
        ),
        gap(18),
        Text(
          cartIsExample
              ? 'PRODUKTE BEI ${marketName.toUpperCase()}'
              : 'ZUTATEN FÜR DEINEN WOCHENPLAN',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
            letterSpacing: .3,
          ),
        ),
        gap(8),
        if (cartIsExample) ...[
          for (final product
              in (showAllDemoProducts ? _products : _products.take(2)))
            if (includeOatDrink || product.$1 != 'Haferdrink Natur')
              shoppingProductRow(
                product.$1,
                product.$2.split(' · ').first,
                euro(product.$3),
              ),
          TextButton(
            onPressed: () =>
                update(() => showAllDemoProducts = !showAllDemoProducts),
            child: Text(
              showAllDemoProducts
                  ? 'Weniger anzeigen'
                  : 'Alle $demoProductCount Beispielprodukte anzeigen',
            ),
          ),
          TextButton(
            onPressed: () => update(() => shoppingExample = false),
            child: const Text('Beispiel schließen'),
          ),
        ] else ...[
          for (final item in items)
            shoppingProductRow(
              item.name,
              amountLabel(item.quantity, item.unit),
              'Preis offen',
            ),
        ],
        gap(16),
      ],
    ];
  }

  Widget shoppingProductRow(String name, String amount, String price) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      gap(2),
                      Text(amount, style: muted.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: price == 'Preis offen' ? 11 : 14,
                    fontWeight: FontWeight.w700,
                    color: price == 'Preis offen' ? AppColors.muted : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  List<Widget> demoSelfShoppingView() => [
    proposalBack('Zurück zum Warenkorb', () => update(() => shoppingPage = 0)),
    gap(14),
    title('Beispiel-Einkaufsliste'),
    gap(8),
    Text('Beispieldaten · unabhängig von deinem Wochenplan', style: muted),
    gap(20),
    for (final product in _products)
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(product.$1),
        subtitle: Text(product.$2),
        value: demoShoppingChecked.contains(product.$1),
        onChanged: (value) => update(() {
          if (value == true) {
            demoShoppingChecked.add(product.$1);
          } else {
            demoShoppingChecked.remove(product.$1);
          }
        }),
      ),
  ];

  Widget costRow(String label, String value, {bool emphasis = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: emphasis ? 18 : 14,
            fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        value,
        style: TextStyle(
          fontSize: emphasis ? 26 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  List<Widget> deliveryView() => [
    proposalBack('Zurück zum Warenkorb', () => update(() => shoppingPage = 0)),
    gap(14),
    title('Fast am Esstisch.'),
    gap(6),
    Text('Prüfen, übergeben, beim Händler bezahlen.', style: muted),
    gap(14),
    panel(
      const Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [Text('✓ Plan'), Text('✓ Warenkorb'), Text('3 Bestellung')],
      ),
      color: AppColors.softGreen,
      padding: const EdgeInsets.all(12),
    ),
    gap(14),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  marketName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$demoProductCount / $demoProductCount · Demo',
                style: const TextStyle(fontSize: 12, color: AppColors.sage),
              ),
            ],
          ),
          gap(10),
          Text(
            'Lieferung an $deliveryAddress',
            style: const TextStyle(fontSize: 14),
          ),
          gap(8),
          Text(deliverySlot, style: muted),
          TextButton(
            onPressed: editDemoDelivery,
            child: const Text('Lieferdetails ändern'),
          ),
          const Text(
            'Mindestbestellwert 50 € erreicht ✓ · Beispiel',
            style: TextStyle(color: AppColors.sage, fontSize: 13),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
    ),
    gap(14),
    panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Eine Alternative für deinen Einkauf',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF84531E),
            ),
          ),
          gap(10),
          Text(
            'Haferdrink Barista ist im Beispiel nicht verfügbar.',
            style: muted,
          ),
          gap(10),
          costRow(
            includeOatDrink
                ? '✓ Haferdrink Natur · 1 l'
                : 'Haferdrink weggelassen',
            includeOatDrink ? '1,49 €' : '0,00 €',
          ),
          gap(10),
          Text(
            includeOatDrink
                ? '0,80 € günstiger · im Beispielgesamtpreis enthalten'
                : '1,49 € vom Beispielgesamtpreis abgezogen',
            style: muted.copyWith(fontSize: 12),
          ),
          TextButton(
            onPressed: editDemoAlternative,
            child: const Text('Alternative ändern →'),
          ),
        ],
      ),
      color: const Color(0xFFF6E9CF),
      padding: const EdgeInsets.all(16),
    ),
    gap(14),
    panel(
      Column(
        children: [
          costRow('Artikel ($demoProductCount) · Demo', euro(demoArticleTotal)),
          gap(14),
          costRow('Lieferung', euro(demoDeliveryFee)),
          gap(14),
          costRow('Pfand', '0,00 €'),
          gap(14),
          costRow('Gesamt', euro(demoShoppingTotal), emphasis: true),
          gap(10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${euro((budget - demoShoppingTotal).abs())} ${demoShoppingTotal <= budget ? 'unter' : 'über'} deinem Wochenbudget · Beispielvergleich',
              style: muted.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
    ),
    gap(14),
    surveyCard(
      'Du behältst das letzte Wort.',
      'Bei einer echten Händleranbindung bestätigst du endgültige Preise, Lieferzeit und Zahlung erst beim Händler. Diese Demo überträgt keine Daten und löst keine Bestellung aus.',
    ),
  ];

  Future<void> editDemoDelivery() async {
    var address = deliveryAddress;
    var slot = deliverySlot;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lieferdetails · Demo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: address,
                decoration: const InputDecoration(labelText: 'Lieferadresse'),
                onChanged: (v) => address = v,
              ),
              gap(14),
              TextFormField(
                initialValue: slot,
                decoration: const InputDecoration(
                  labelText: 'Wunsch-Lieferzeit',
                ),
                onChanged: (v) => slot = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              if (address.trim().isNotEmpty && slot.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
    if (save == true && mounted) {
      update(() {
        deliveryAddress = address.trim();
        deliverySlot = slot.trim();
      });
    }
  }

  Future<void> editDemoAlternative() async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Produktalternative · Demo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              gap(14),
              ListTile(
                title: const Text('Haferdrink Natur · 1 l'),
                subtitle: const Text('1,49 € · Beispielpreis'),
                leading: Icon(
                  includeOatDrink
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                title: const Text('Artikel weglassen'),
                subtitle: const Text('Vom Beispielwarenkorb entfernen'),
                leading: Icon(
                  !includeOatDrink
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null && mounted) update(() => includeOatDrink = choice);
  }

  void demoHandoff() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Händlerübergabe · Demo'),
      content: Text(
        'Der Beispielwarenkorb bei $marketName beträgt ${euro(demoShoppingTotal)}. Es ist noch kein Händler angebunden. Es wurden keine Daten übertragen und keine Bestellung aufgegeben.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zurück'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            update(() => shoppingPage = 1);
          },
          child: const Text('Selbst einkaufen'),
        ),
      ],
    ),
  );
}

class _ShoppingBasketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final shape = Path()
      ..moveTo(12, 38)
      ..lineTo(88, 38)
      ..lineTo(79, 90)
      ..lineTo(21, 90)
      ..close();
    canvas.drawPath(shape, Paint()..color = AppColors.softGreen);
    final stroke = Paint()
      ..color = AppColors.sage
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(shape, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(30, 38)
        ..lineTo(46, 16)
        ..moveTo(70, 38)
        ..lineTo(54, 16),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShoppingBasketPainter oldDelegate) => false;
}
