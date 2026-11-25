/// Consistent spellings without changing the size of a quantity.
String quantityUnit(String unit) => switch (unit.trim().toLowerCase()) {
  'kg' => 'kg',
  'g' => 'g',
  'l' => 'l',
  'ml' => 'ml',
  'stück' || 'stueck' || 'stk' || 'stk.' || 'piece' => 'Stück',
  'packung' || 'packungen' => 'Packung',
  'el' => 'EL',
  'tl' => 'TL',
  _ => unit.trim(),
};

(double, String)? _baseUnit(String unit) => switch (quantityUnit(unit)) {
  'kg' => (1000, 'g'),
  'g' => (1, 'g'),
  'l' => (1000, 'ml'),
  'ml' => (1, 'ml'),
  'Stück' => (1, 'Stück'),
  _ => null,
};

String canonicalQuantityUnit(String unit) =>
    _baseUnit(unit)?.$2 ?? quantityUnit(unit);

/// Only known dimensions are converted. Opaque units can be added together
/// explicitly, but never imply a weight, volume or package content.
(double, String)? normalizeQuantity(
  double quantity,
  String unit, {
  bool allowUnknown = false,
}) {
  if (!quantity.isFinite || quantity <= 0) return null;
  final base = _baseUnit(unit);
  if (base == null) {
    return allowUnknown ? (quantity, quantityUnit(unit)) : null;
  }
  final amount = quantity * base.$1;
  return amount.isFinite ? (amount, base.$2) : null;
}

/// Pantry text and recipe quantities use the same base units.
(double, String)? parseQuantity(String? value) {
  final match = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*(.*?)\s*$')
      .firstMatch(value ?? '');
  if (match == null) return null;
  final amount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  if (amount == null) return null;
  return normalizeQuantity(amount, match.group(2)!, allowUnknown: true);
}

bool sameQuantity(double a, double b) =>
    a.isFinite && b.isFinite && (a - b).abs() < 0.000001;
