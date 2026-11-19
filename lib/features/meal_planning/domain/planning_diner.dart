import '../../recipes/domain/recipe.dart';

class PlanningDiner {
  const PlanningDiner({
    required this.id,
    required this.name,
    this.participates = true,
    this.confirmed = false,
    this.diet = 'Ohne Einschränkung',
    this.exclusions = const {},
  });
  final String id, name, diet;
  final bool participates, confirmed;
  final Set<String> exclusions;
  bool get rulesKnown =>
      confirmed &&
      const {'Ohne Einschränkung', 'Vegetarisch', 'Vegan'}.contains(diet);
  bool allows(Recipe recipe) =>
      rulesKnown && matchesVerifiedRestrictions(recipe, diet, exclusions);
  Map<String, dynamic> toJson() => {
    'name': name,
    'participates': participates,
    'confirmed': confirmed,
    'diet': diet,
    'exclusions': exclusions.toList(),
  };
  factory PlanningDiner.fromJson(
    String id,
    String name,
    Map<String, dynamic> data,
  ) => PlanningDiner(
    id: id,
    name: name,
    participates: data['participates'] != false,
    confirmed: data['confirmed'] == true,
    diet: data['diet'] as String? ?? 'Ohne Einschränkung',
    exclusions: (data['exclusions'] as List? ?? []).cast<String>().toSet(),
  );
}
