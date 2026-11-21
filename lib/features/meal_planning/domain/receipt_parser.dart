/// Receipt text is untrusted data. Only priced article rows are imported;
/// payment details, footer text and instructions are never executed or stored.
class ParsedReceipt {
  const ParsedReceipt(this.items, this.merchant);
  final List<Map<String, dynamic>> items;
  final String merchant;
}

ParsedReceipt parseReceipt(String text) {
  final lines = text.replaceAll('\r', '').replaceAll('\f', '\n').split('\n');
  final merchant = RegExp(r'\brewe\b', caseSensitive: false).hasMatch(text)
      ? 'REWE'
      : 'Kassenbon';
  final priceRow = RegExp(
    r'^(.+?)\s+(-?\d+[.,]\d{2})\s*(?:[ABCD*]|[ABCD]\s*\*)?\s*$',
    caseSensitive: false,
  );
  final quantityRow = RegExp(
    r'^\s*(\d+(?:[.,]\d+)?)\s*(kg|g|ml|l|stk\.?|stück|st\.?)\s*[x×*]\s*\d+[.,]\d{2}',
    caseSensitive: false,
  );
  final ignored = RegExp(
    r'^(?:summe|gesamt|total|zwischen|geg\.?|gegeben|rückgeld|rueckgeld|betrag|steuer|netto|brutto|rabatt|coupon|bonus|pfand|leergut|retoure|storno|ersparnis|eur\b|bar\b|ec.cash|kartenzahlung)',
    caseSensitive: false,
  );
  final nonFood = RegExp(
    r'toipa|toiletten|taschent|muellb|müllb|teelicht|waschmittel|spuelmittel|spülmittel|haushalts|kuechenrolle|küchenrolle|putzmittel',
    caseSensitive: false,
  );
  final chilled = RegExp(
    r'thunfischsteak|salami|cacciatora|wurst|käse|kaese|mueritz|bresso|butter|quark|joghurt|yoghurt|milchreis|spinat|rosenkohl|radies|gurke|fleisch|hähnchen|haehnchen|lachs|frisch',
    caseSensitive: false,
  );
  final ambiguous = RegExp(
    r'^(?:diverse sorten|original|extra ungesalzen|mixed minis|african blue|beste bohne cl\.?)$',
    caseSensitive: false,
  );
  final items = <Map<String, dynamic>>[];
  Map<String, dynamic>? previous;
  for (final raw in lines) {
    final line = raw.trim();
    if (RegExp(
      r'^(?:summe|gesamtbetrag|total)\b',
      caseSensitive: false,
    ).hasMatch(line)) {
      break;
    }
    final quantity = quantityRow.firstMatch(line);
    if (quantity != null && previous != null) {
      final value = double.tryParse(quantity[1]!.replaceAll(',', '.'));
      if (value != null && value > 0) {
        final unit = quantity[2]!.toLowerCase();
        // On receipts, Stk counts purchased packages, not pieces inside a pack.
        previous['amount'] =
            '${quantity[1]!.replaceAll('.', ',')} ${unit.startsWith('st') ? (value == 1 ? 'Packung' : 'Packungen') : unit}';
        previous['quantityMissing'] = false;
      }
      continue;
    }
    final match = priceRow.firstMatch(line);
    if (match == null || ignored.hasMatch(line)) continue;
    final name = match[1]!.trim();
    final price = double.tryParse(match[2]!.replaceAll(',', '.'));
    if (price == null ||
        price <= 0 ||
        name.length < 2 ||
        !RegExp(r'[a-zäöüß]', caseSensitive: false).hasMatch(name)) {
      continue;
    }
    if (name.contains('=')) {
      continue;
    }
    final excluded = nonFood.hasMatch(name);
    final unclear = ambiguous.hasMatch(name);
    previous = {
      'name': name,
      'amount': '1 Packung',
      'location': chilled.hasMatch(name) ? 'Kühlschrank' : 'Trocken',
      'expires': null,
      'selected': !excluded && !unclear,
      'quantityMissing': true,
      'reviewNote': excluded
          ? 'Haushaltsartikel – nicht vorausgewählt'
          : unclear
          ? 'Artikelbezeichnung unklar – bitte zuordnen'
          : 'Packungsinhalt und Lagerort prüfen',
      'price': price,
    };
    items.add(previous);
  }
  return ParsedReceipt(items, merchant);
}

bool validProductBarcode(String code) {
  if (!RegExp(r'^(?:\d{8}|\d{12}|\d{13}|\d{14})$').hasMatch(code)) return false;
  final digits = code.split('').map(int.parse).toList();
  var sum = 0;
  for (
    var i = digits.length - 2, weight = 3;
    i >= 0;
    i--, weight = weight == 3 ? 1 : 3
  ) {
    sum += digits[i] * weight;
  }
  return (10 - sum % 10) % 10 == digits.last;
}
