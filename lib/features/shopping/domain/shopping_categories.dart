const shoppingCategories = [
  'Gemüse & Obst',
  'Kühlregal',
  'Fleisch & Fisch',
  'Backwaren',
  'Vorratsschrank',
  'Getränke',
  'Tiefkühl',
  'Haushalt',
  'Sonstiges',
];

String suggestedShoppingCategory(String name) {
  final value = name.trim().toLowerCase();
  if (RegExp(
    r'paprika|tomat|gurk|zucchin|brokkoli|karott|möhre|zwiebel|knoblauch|salat|spinat|kartoff|apfel|banane|zitrone|beere|obst|gemüse|kohl|pilz|kräuter|petersilie|basilikum',
  ).hasMatch(value)) {
    return 'Gemüse & Obst';
  }
  if (RegExp(
    r'milch|käse|kaese|joghurt|quark|butter|sahne|creme|ei(er)?|tofu|frischkäse|frischkaese',
  ).hasMatch(value)) {
    return 'Kühlregal';
  }
  if (RegExp(r'hähn|haehn|huhn|fleisch|rind|schwein|lachs|fisch|wurst').hasMatch(value)) {
    return 'Fleisch & Fisch';
  }
  if (RegExp(r'brot|brötchen|broetchen|toast|bröt|backwaren|mehl').hasMatch(value)) {
    return 'Backwaren';
  }
  if (RegExp(r'getränk|getraenk|saft|wasser|limonade|drink').hasMatch(value)) {
    return 'Getränke';
  }
  if (RegExp(r'tiefkühl|tiefkuehl|gefroren|eiscreme').hasMatch(value)) {
    return 'Tiefkühl';
  }
  if (RegExp(r'papier|reiniger|spülmittel|spuelmittel|seife|waschmittel|beutel').hasMatch(value)) {
    return 'Haushalt';
  }
  if (RegExp(r'reis|nudel|pasta|linse|bohne|mehl|öl|oel|gewürz|gewuerz|dose|konserve|hafer|zucker|salz|nuss').hasMatch(value)) {
    return 'Vorratsschrank';
  }
  return 'Sonstiges';
}
