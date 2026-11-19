import 'admin_recipe_repository.dart';

String normalizeIngredientName(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss');

int _distance(String a, String b) {
  final table = List.generate(
    a.length + 1,
    (i) => List.generate(
      b.length + 1,
      (j) => i == 0
          ? j
          : j == 0
          ? i
          : 0,
    ),
  );
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      var best = table[i - 1][j] + 1;
      if (table[i][j - 1] + 1 < best) best = table[i][j - 1] + 1;
      final replacement = table[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      if (replacement < best) best = replacement;
      if (i > 1 &&
          j > 1 &&
          a[i - 1] == b[j - 2] &&
          a[i - 2] == b[j - 1] &&
          table[i - 2][j - 2] + 1 < best) {
        best = table[i - 2][j - 2] + 1;
      }
      table[i][j] = best;
    }
  }
  return table[a.length][b.length];
}

List<CatalogIngredient> suggestIngredients(
  List<CatalogIngredient> catalog,
  String input,
) {
  final query = normalizeIngredientName(input);
  if (query.length < 2 || query.length > 120) return [];
  final ranked = <(int, CatalogIngredient)>[];
  for (final item in catalog) {
    final name = normalizeIngredientName(item.name);
    if (name == query) {
      ranked.add((0, item));
      continue;
    }
    if (name.startsWith(query)) {
      ranked.add((1, item));
      continue;
    }
    if (name.contains(query)) {
      ranked.add((2, item));
      continue;
    }
    if (query.length < 3) continue;
    final tolerance = query.length >= 6 ? 2 : 1;
    var distance = tolerance + 1;
    for (final word in {name, ...name.split(RegExp(r'[\s-]+'))}) {
      if ((word.length - query.length).abs() > tolerance) continue;
      final candidate = _distance(query, word);
      if (candidate < distance) distance = candidate;
    }
    if (distance <= tolerance) ranked.add((3 + distance, item));
  }
  ranked.sort(
    (a, b) => a.$1 != b.$1
        ? a.$1.compareTo(b.$1)
        : a.$2.name.toLowerCase().compareTo(b.$2.name.toLowerCase()),
  );
  return ranked.take(5).map((entry) => entry.$2).toList();
}
