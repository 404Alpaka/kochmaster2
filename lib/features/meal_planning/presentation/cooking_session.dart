import 'dart:async';

import '../domain/cooking_timer.dart';
import '../../recipes/domain/recipe.dart';

class CookingUse {
  CookingUse(this.item, this.used, this.unit);

  final Map<String, dynamic> item;
  double used;
  final String unit;
}

class CookingSession {
  int page = 0;
  Recipe? recipe;
  int portions = 2;
  int step = 0;
  int? day;
  DateTime? date;
  String key = '';
  Timer? ticker;
  final timers = <int, CookingTimer>{};
  final uses = <CookingUse>[];
  bool deductStock = true;
  int remainingCookedPortions = 0;
  String cookedStorage = 'Kühlschrank';
  DateTime? cookedOn;
  final cookedEntries = <String>{};
}
