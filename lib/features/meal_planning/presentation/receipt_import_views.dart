part of 'planning_page.dart';

extension _ReceiptImportViews on _PlanningPageState {
  Future<T> pantryTask<T>(Future<T> Function() action, String label) async {
    final future = action();
    final navigator = Navigator.of(context);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LinearProgressIndicator(),
              gap(18),
              Text(label),
              gap(8),
              const Text('Die erste Fotoerkennung kann etwas länger dauern.'),
            ],
          ),
        ),
      ),
    );
    unawaited(navigator.push(route));
    try {
      return await future.timeout(const Duration(minutes: 4));
    } finally {
      if (route.isActive) navigator.removeRoute(route);
    }
  }

  void pantryImportError(Object error) {
    if (!mounted) return;
    final message = error is PlatformException
        ? error.message ?? 'Die Erkennung konnte nicht abgeschlossen werden.'
        : error is FormatException
        ? error.message
        : error.toString().replaceFirst(
            RegExp(r'^(?:Error|Bad state|Exception|Unsupported operation):\s*'),
            '',
          );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
      );
  }

  bool receiptAlreadyImported(String id) =>
      importedReceiptIds.contains(id) ||
      pantry.any(
        (item) => (item['sourceReceiptIds'] as List? ?? []).contains(id),
      );

  void previewReceiptText(
    String text, {
    required String source,
    String? fingerprint,
  }) {
    fingerprint ??= sha256
        .convert(utf8.encode(text.replaceAll(RegExp(r'\s+'), ' ').trim()))
        .toString();
    if (receiptAlreadyImported(fingerprint)) {
      throw const FormatException(
        'Dieser Bon wurde bereits übernommen. Dein Vorrat wurde nicht verändert.',
      );
    }
    final parsed = parseReceipt(text);
    if (parsed.items.isEmpty) {
      throw const FormatException(
        'Keine Artikelzeilen mit Preisen erkannt. Bitte einen lesbaren Bon wählen oder den Bontext einfügen.',
      );
    }
    update(() {
      receiptDraft = parsed.items;
      receiptIsDemo = false;
      receiptSource = parsed.merchant == 'REWE' ? 'REWE · $source' : source;
      receiptFingerprint = fingerprint;
      receiptResolved = false;
      showAllReceiptItems = false;
      pantryPage = 1;
      tab = 2;
    });
  }

  Future<void> importReceiptFile({bool camera = false}) async {
    try {
      final document = await pantryTask(
        () => readReceiptFile(camera: camera),
        camera ? 'Bonfoto wird gelesen …' : 'Digitaler Bon wird gelesen …',
      );
      if (document == null || !mounted) return;
      previewReceiptText(
        document['text'] as String,
        source: document['name'] as String,
        fingerprint: document['fingerprint'] as String,
      );
    } catch (error) {
      pantryImportError(error);
    }
  }

  void receiptCaptureInfo() => importReceiptFile(camera: true);

  Future<void> pasteReceiptText() async {
    String text = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bontext einfügen'),
        content: SizedBox(
          width: 500,
          child: TextField(
            onChanged: (value) => text = value,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText:
                  'Artikel und Preise aus deinem digitalen Bon hier einfügen',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text),
            child: const Text('Artikel erkennen'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty || !mounted) return;
    try {
      previewReceiptText(result, source: 'Eingefügter Bontext');
    } catch (error) {
      pantryImportError(error);
    }
  }

  Future<void> barcodeInfo() async {
    String number = '';
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Barcode erfassen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scanne den Produktbarcode oder gib seine Nummer ein. Produktdaten werden bei Open Food Facts abgefragt.',
            ),
            gap(16),
            TextField(
              onChanged: (value) => number = value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'EAN / Barcode'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'photo'),
            child: const Text('Barcode-Foto'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'camera'),
            child: const Text('Kamera'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, number.trim()),
            child: const Text('Produkt suchen'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    try {
      final code = choice == 'camera' || choice == 'photo'
          ? await pantryTask(
              () => scanProductBarcode(camera: choice == 'camera'),
              'Barcode wird erkannt …',
            )
          : choice;
      if (code == null || !mounted) return;
      if (!validProductBarcode(code)) {
        throw const FormatException(
          'Bitte eine gültige EAN mit 8, 12, 13 oder 14 Ziffern eingeben.',
        );
      }
      final product = await pantryTask(
        () => lookupProductBarcode(code),
        'Produkt wird gesucht …',
      );
      if (!mounted) return;
      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Produkt nicht gefunden. Bitte die Angaben manuell ergänzen.',
            ),
          ),
        );
      }
      await editPantryProduct(
        initial: {
          'name':
              (product?['product_name_de'] as String?)?.trim().isNotEmpty ==
                  true
              ? product!['product_name_de']
              : product?['product_name'] ?? '',
          'amount': (product?['quantity'] as String?)?.isNotEmpty == true
              ? product!['quantity']
              : '1 Packung',
          'location': 'Kühlschrank',
        },
      );
    } catch (error) {
      pantryImportError(error);
    }
  }
}
