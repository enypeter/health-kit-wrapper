/// A nutrition record with macro breakdown.
class NutritionRecord {
  const NutritionRecord({
    required this.name,
    required this.mealType,
    required this.energyKcal,
    required this.start,
    required this.end,
    required this.source,
    this.proteinG = 0,
    this.carbohydratesG = 0,
    this.fatG = 0,
    this.fiberG = 0,
    this.sugarG = 0,
    this.sodiumMg = 0,
  });

  final String name;
  final String mealType;
  final double energyKcal;
  final double proteinG;
  final double carbohydratesG;
  final double fatG;
  final double fiberG;
  final double sugarG;
  final double sodiumMg;
  final DateTime start;
  final DateTime end;
  final String source;

  factory NutritionRecord.fromMap(Map<String, dynamic> m) => NutritionRecord(
    name:           m['name'] as String? ?? '',
    mealType:       m['mealType'] as String? ?? '',
    energyKcal:     (m['energyKcal'] as num?)?.toDouble() ?? 0,
    proteinG:       (m['proteinG'] as num?)?.toDouble() ?? 0,
    carbohydratesG: (m['carbohydratesG'] as num?)?.toDouble() ?? 0,
    fatG:           (m['fatG'] as num?)?.toDouble() ?? 0,
    fiberG:         (m['fiberG'] as num?)?.toDouble() ?? 0,
    sugarG:         (m['sugarG'] as num?)?.toDouble() ?? 0,
    sodiumMg:       (m['sodiumMg'] as num?)?.toDouble() ?? 0,
    start:          DateTime.fromMillisecondsSinceEpoch((m['startMs'] as num).toInt()),
    end:            DateTime.fromMillisecondsSinceEpoch((m['endMs'] as num).toInt()),
    source:         m['source'] as String? ?? '',
  );
}

/// A hydration record.
class HydrationRecord {
  const HydrationRecord({
    required this.volumeLiters,
    required this.start,
    required this.end,
    required this.source,
  });

  final double volumeLiters;
  final DateTime start;
  final DateTime end;
  final String source;

  double get volumeMl => volumeLiters * 1000;

  factory HydrationRecord.fromMap(Map<String, dynamic> m) => HydrationRecord(
    volumeLiters: (m['volumeLiters'] as num?)?.toDouble() ?? 0,
    start:        DateTime.fromMillisecondsSinceEpoch((m['startMs'] as num).toInt()),
    end:          DateTime.fromMillisecondsSinceEpoch((m['endMs'] as num).toInt()),
    source:       m['source'] as String? ?? '',
  );
}
