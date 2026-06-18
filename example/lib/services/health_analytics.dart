import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:health_kit_wrapper/health_kit_wrapper.dart';
import '../models/user_profile.dart';

// ─────────────────────────────────────────────────────────────
// Score result types
// ─────────────────────────────────────────────────────────────

class SleepScore {
  const SleepScore({
    required this.total,
    required this.durationPts,
    required this.efficiencyPts,
    required this.deepPts,
    required this.remPts,
    required this.awakePenaltyPts,
    required this.durationHours,
    required this.efficiency,
    required this.deepPct,
    required this.remPct,
    required this.awakeMinutes,
  });
  final int total;
  final int durationPts, efficiencyPts, deepPts, remPts, awakePenaltyPts;
  final double durationHours, efficiency, deepPct, remPct;
  final int awakeMinutes;

  String get label => switch (total) {
    >= 85 => 'Excellent',
    >= 70 => 'Good',
    >= 50 => 'Fair',
    _ => 'Poor',
  };
}

class RecoveryScore {
  const RecoveryScore({
    required this.total,
    required this.hrvPts,
    required this.restingHrPts,
    required this.sleepPts,
    required this.activityLoadPts,
    required this.hrvToday,
    required this.hrvAvg,
    required this.restingHrToday,
    required this.restingHrAvg,
  });
  final int total;
  final int hrvPts, restingHrPts, sleepPts, activityLoadPts;
  final double hrvToday, hrvAvg, restingHrToday, restingHrAvg;

  String get label => switch (total) {
    >= 80 => 'Fully Recovered',
    >= 60 => 'Moderate',
    >= 40 => 'Compromised',
    _ => 'Rest Recommended',
  };
}

class BmiResult {
  const BmiResult({
    required this.bmi,
    required this.weightKg,
    required this.heightM,
  });
  final double bmi;
  final double weightKg;
  final double heightM;

  String get category => switch (bmi) {
    < 18.5 => 'Underweight',
    < 25.0 => 'Normal',
    < 30.0 => 'Overweight',
    < 35.0 => 'Obese I',
    < 40.0 => 'Obese II',
    _ => 'Obese III',
  };
}

class CalorieTrend {
  const CalorieTrend({required this.days});
  final List<DayCalories> days;

  double get avgActive =>
      days.isEmpty ? 0 : days.map((d) => d.active).reduce((a, b) => a + b) / days.length;
  double get avgTotal =>
      days.isEmpty ? 0 : days.map((d) => d.total).reduce((a, b) => a + b) / days.length;
}

class DayCalories {
  const DayCalories({required this.date, required this.active, required this.total, required this.steps});
  final DateTime date;
  final double active;
  final double total;
  final int steps;
}

class HydrationScore {
  const HydrationScore({
    required this.actualLiters,
    required this.targetLiters,
    required this.score,
  });
  final double actualLiters;
  final double targetLiters;
  final int score; // 0-100
}

class MacroBalance {
  const MacroBalance({
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.totalKcal,
  });
  final double proteinPct, carbsPct, fatPct;
  final double proteinG, carbsG, fatG, totalKcal;
}

class BpStage {
  const BpStage({required this.systolic, required this.diastolic});
  final double systolic, diastolic;

  String get category {
    if (systolic > 180 || diastolic > 120) return 'Crisis';
    if (systolic >= 140 || diastolic >= 90) return 'HTN Stage 2';
    if (systolic >= 130 || diastolic >= 80) return 'HTN Stage 1';
    if (systolic >= 120 && diastolic < 80) return 'Elevated';
    return 'Normal';
  }
}

class ExerciseSuggestion {
  const ExerciseSuggestion({
    required this.focus,
    required this.type,
    required this.intensity,
    required this.durationMin,
    required this.rationale,
  });
  final String focus, type, intensity, rationale;
  final int durationMin;
}

class VitalsSnapshot {
  const VitalsSnapshot({
    this.avgHr,
    this.minHr,
    this.maxHr,
    this.latestHrv,
    this.latestSpO2,
    this.latestBp,
    this.latestVo2Max,
    this.latestRespRate,
    this.latestTemp,
    this.latestGlucose,
    this.restingHr,
  });
  final int? avgHr, minHr, maxHr, restingHr;
  final double? latestHrv, latestSpO2, latestRespRate, latestTemp;
  final Vo2MaxSample? latestVo2Max;
  final BloodPressureSample? latestBp;
  final BloodGlucoseSample? latestGlucose;

  String get hrvLabel => Platform.isIOS ? 'SDNN' : 'RMSSD';
}

// ─────────────────────────────────────────────────────────────
// Analytics Engine
// ─────────────────────────────────────────────────────────────

class HealthAnalytics {
  HealthAnalytics._();

  // ── Sleep Score ────────────────────────────────────────────

  static SleepScore computeSleepScore(SleepSession session) {
    final dur = session.durationMinutes;
    final hours = dur / 60.0;
    final b = session.breakdown;
    final sleepMins = b.totalSleepMinutes;
    final eff = dur > 0 ? sleepMins / dur : 0.0;
    final deepPct = dur > 0 ? b.deepMinutes / dur : 0.0;
    final remPct = dur > 0 ? b.remMinutes / dur : 0.0;

    // Duration (25 pts)
    final durationPts = switch (hours) {
      >= 7.0 && <= 9.0 => 25,
      >= 6.0 && < 7.0 || > 9.0 && <= 10.0 => 20,
      >= 5.0 && < 6.0 || > 10.0 && <= 11.0 => 12,
      _ => 5,
    };

    // Efficiency (25 pts)
    final efficiencyPts = (eff * 25).round().clamp(0, 25);

    // Deep sleep (20 pts)
    final deepPts = switch (deepPct) {
      >= 0.20 => 20,
      >= 0.15 => 16,
      >= 0.10 => 10,
      _ => 5,
    };

    // REM (20 pts)
    final remPts = switch (remPct) {
      >= 0.20 => 20,
      >= 0.15 => 16,
      >= 0.10 => 10,
      _ => 5,
    };

    // Awake penalty (10 pts)
    final awakePts = switch (b.awakeMinutes) {
      <= 10 => 10,
      <= 20 => 7,
      <= 40 => 4,
      _ => 0,
    };

    return SleepScore(
      total: (durationPts + efficiencyPts + deepPts + remPts + awakePts).clamp(0, 100),
      durationPts: durationPts,
      efficiencyPts: efficiencyPts,
      deepPts: deepPts,
      remPts: remPts,
      awakePenaltyPts: awakePts,
      durationHours: hours,
      efficiency: eff,
      deepPct: deepPct,
      remPct: remPct,
      awakeMinutes: b.awakeMinutes,
    );
  }

  // ── Recovery Score ─────────────────────────────────────────

  static Future<RecoveryScore> computeRecoveryScore() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    final results = await Future.wait([
      HealthKitWrapper.readHeartRateVariability(from: weekAgo, to: now),
      HealthKitWrapper.readRestingHeartRate(from: weekAgo, to: now),
      HealthKitWrapper.readSleep(from: today.subtract(const Duration(hours: 14)), to: now),
      HealthKitWrapper.getActivityHistory(7),
    ]);

    final hrvSamples = results[0] as List<HrvSample>;
    final restingHrSamples = results[1] as List<HeartRateSample>;
    final sleepSessions = results[2] as List<SleepSession>;
    final activityHistory = results[3] as List<({DateTime date, AggregatedActivity activity})>;

    // HRV component (30 pts)
    double hrvToday = 0, hrvAvg = 0;
    int hrvPts = 15; // default if no data
    if (hrvSamples.isNotEmpty) {
      final todaySamples = hrvSamples.where(
        (s) => s.timestamp.isAfter(today),
      );
      hrvToday = todaySamples.isNotEmpty
          ? todaySamples.last.valueMs
          : hrvSamples.last.valueMs;
      hrvAvg = hrvSamples.map((s) => s.valueMs).reduce((a, b) => a + b) / hrvSamples.length;
      final ratio = hrvAvg > 0 ? hrvToday / hrvAvg : 1.0;
      hrvPts = switch (ratio) {
        >= 1.10 => 30,
        >= 0.90 => 22,
        >= 0.70 => 12,
        _ => 5,
      };
    }

    // Resting HR component (25 pts)
    double rhrToday = 0, rhrAvg = 0;
    int rhrPts = 12;
    if (restingHrSamples.isNotEmpty) {
      final todayRhr = restingHrSamples.where((s) => s.timestamp.isAfter(today));
      rhrToday = todayRhr.isNotEmpty
          ? todayRhr.last.bpm.toDouble()
          : restingHrSamples.last.bpm.toDouble();
      rhrAvg = restingHrSamples.map((s) => s.bpm).reduce((a, b) => a + b) / restingHrSamples.length;
      final ratio = rhrAvg > 0 ? rhrToday / rhrAvg : 1.0;
      rhrPts = switch (ratio) {
        <= 0.95 => 25,
        <= 1.05 => 18,
        <= 1.15 => 10,
        _ => 3,
      };
    }

    // Sleep quality (25 pts)
    int sleepPts = 12;
    if (sleepSessions.isNotEmpty) {
      final score = computeSleepScore(sleepSessions.last);
      sleepPts = (score.total * 0.25).round();
    }

    // Activity load (20 pts)
    int loadPts = 14;
    if (activityHistory.length >= 2) {
      final avgCal = activityHistory.map((d) => d.activity.totalCaloriesKcal)
          .reduce((a, b) => a + b) / activityHistory.length;
      final yesterdayCal = activityHistory.length > 1
          ? activityHistory[1].activity.totalCaloriesKcal
          : avgCal;
      final ratio = avgCal > 0 ? yesterdayCal / avgCal : 1.0;
      loadPts = switch (ratio) {
        < 0.80 => 20,
        < 1.20 => 14,
        < 1.50 => 8,
        _ => 3,
      };
    }

    return RecoveryScore(
      total: (hrvPts + rhrPts + sleepPts + loadPts).clamp(0, 100),
      hrvPts: hrvPts,
      restingHrPts: rhrPts,
      sleepPts: sleepPts,
      activityLoadPts: loadPts,
      hrvToday: hrvToday,
      hrvAvg: hrvAvg,
      restingHrToday: rhrToday,
      restingHrAvg: rhrAvg,
    );
  }

  // ── BMI ────────────────────────────────────────────────────

  /// Compute BMI from health data, falling back to user profile if no
  /// recent weight/height samples exist.
  static Future<BmiResult?> computeBmi({UserProfile? profile}) async {
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 90));
    final results = await Future.wait([
      HealthKitWrapper.readWeight(from: past, to: now),
      HealthKitWrapper.readHeight(from: past, to: now),
    ]);
    final weights = results[0] as List<WeightSample>;
    final heights = results[1] as List<HeightSample>;

    final w = weights.isNotEmpty ? weights.last.kg
        : (profile != null && profile.hasWeight ? profile.weightKg : 0.0);
    final h = heights.isNotEmpty ? heights.last.meters
        : (profile != null && profile.hasHeight ? profile.heightM : 0.0);
    if (w <= 0 || h <= 0) return null;

    return BmiResult(bmi: w / (h * h), weightKg: w, heightM: h);
  }

  // ── Calorie Trend ──────────────────────────────────────────

  static Future<CalorieTrend> getCalorieTrend(int days) async {
    final history = await HealthKitWrapper.getActivityHistory(days);
    final dayList = history.map((d) => DayCalories(
      date: d.date,
      active: d.activity.activeCaloriesKcal,
      total: d.activity.totalCaloriesKcal,
      steps: d.activity.steps,
    )).toList();
    return CalorieTrend(days: dayList);
  }

  // ── Hydration ──────────────────────────────────────────────

  /// Compute hydration score. Uses profile's daily water target if set,
  /// otherwise calculates from body weight + exercise adjustment.
  static Future<HydrationScore> computeHydration({UserProfile? profile}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final results = await Future.wait([
      HealthKitWrapper.readHydration(from: today, to: now),
      HealthKitWrapper.readWeight(from: now.subtract(const Duration(days: 90)), to: now),
      HealthKitWrapper.readExerciseSessions(from: today, to: now),
    ]);

    final hydration = results[0] as List<HydrationRecord>;
    final weights = results[1] as List<WeightSample>;
    final exercises = results[2] as List<ExerciseSession>;

    final actualL = hydration.fold(0.0, (sum, r) => sum + r.volumeLiters);

    double targetL;
    if (profile != null && profile.dailyWaterLiters > 0) {
      targetL = profile.dailyWaterLiters;
    } else {
      final weightKg = weights.isNotEmpty ? weights.last.kg
          : (profile != null && profile.hasWeight ? profile.weightKg : 70.0);
      targetL = weightKg * 0.033;
    }
    // Add 0.5L per 30min of exercise
    final exerciseMins = exercises.fold(0, (sum, e) => sum + e.durationMinutes);
    targetL += (exerciseMins / 30) * 0.5;

    final score = targetL > 0 ? ((actualL / targetL) * 100).round().clamp(0, 100) : 0;
    return HydrationScore(actualLiters: actualL, targetLiters: targetL, score: score);
  }

  // ── Macro Balance ──────────────────────────────────────────

  static Future<MacroBalance?> computeMacros() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nutrition = await HealthKitWrapper.readNutrition(from: today, to: now);
    if (nutrition.isEmpty) return null;

    final totalProtein = nutrition.fold(0.0, (s, r) => s + r.proteinG);
    final totalCarbs = nutrition.fold(0.0, (s, r) => s + r.carbohydratesG);
    final totalFat = nutrition.fold(0.0, (s, r) => s + r.fatG);
    final totalKcal = nutrition.fold(0.0, (s, r) => s + r.energyKcal);

    final computedKcal = (totalProtein * 4) + (totalCarbs * 4) + (totalFat * 9);
    final base = computedKcal > 0 ? computedKcal : (totalKcal > 0 ? totalKcal : 1);

    return MacroBalance(
      proteinPct: (totalProtein * 4 / base) * 100,
      carbsPct: (totalCarbs * 4 / base) * 100,
      fatPct: (totalFat * 9 / base) * 100,
      proteinG: totalProtein,
      carbsG: totalCarbs,
      fatG: totalFat,
      totalKcal: totalKcal > 0 ? totalKcal : computedKcal,
    );
  }

  // ── Vitals Snapshot ────────────────────────────────────────

  static Future<VitalsSnapshot> getVitalsSnapshot() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final past90 = now.subtract(const Duration(days: 90));

    final results = await Future.wait([
      HealthKitWrapper.readHeartRate(from: today, to: now),
      HealthKitWrapper.readHeartRateVariability(from: today, to: now),
      HealthKitWrapper.readOxygenSaturation(from: today, to: now),
      HealthKitWrapper.readBloodPressure(from: past90, to: now),
      HealthKitWrapper.readVo2Max(from: past90, to: now),
      HealthKitWrapper.readRespiratoryRate(from: today, to: now),
      HealthKitWrapper.readBodyTemperature(from: today, to: now),
      HealthKitWrapper.readBloodGlucose(from: past90, to: now),
      HealthKitWrapper.readRestingHeartRate(from: today, to: now),
    ]);

    final hr = results[0] as List<HeartRateSample>;
    final hrv = results[1] as List<HrvSample>;
    final spo2 = results[2] as List<OxygenSaturationSample>;
    final bp = results[3] as List<BloodPressureSample>;
    final vo2 = results[4] as List<Vo2MaxSample>;
    final resp = results[5] as List<RespiratoryRateSample>;
    final temp = results[6] as List<BodyTemperatureSample>;
    final glucose = results[7] as List<BloodGlucoseSample>;
    final rhr = results[8] as List<HeartRateSample>;

    int? avgHr, minHr, maxHr;
    if (hr.isNotEmpty) {
      final bpms = hr.map((s) => s.bpm).toList();
      avgHr = (bpms.reduce((a, b) => a + b) / bpms.length).round();
      minHr = bpms.reduce(math.min);
      maxHr = bpms.reduce(math.max);
    }

    return VitalsSnapshot(
      avgHr: avgHr,
      minHr: minHr,
      maxHr: maxHr,
      restingHr: rhr.isNotEmpty ? rhr.last.bpm : null,
      latestHrv: hrv.isNotEmpty ? hrv.last.valueMs : null,
      latestSpO2: spo2.isNotEmpty ? spo2.last.percentage : null,
      latestBp: bp.isNotEmpty ? bp.last : null,
      latestVo2Max: vo2.isNotEmpty ? vo2.last : null,
      latestRespRate: resp.isNotEmpty ? resp.last.rate : null,
      latestTemp: temp.isNotEmpty ? temp.last.celsius : null,
      latestGlucose: glucose.isNotEmpty ? glucose.last : null,
    );
  }

  // ── Exercise Suggestions ───────────────────────────────────

  static Future<List<ExerciseSuggestion>> getSuggestions() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week = today.subtract(const Duration(days: 7));

    final results = await Future.wait([
      computeRecoveryScore(),
      computeBmi(),
      HealthKitWrapper.readExerciseSessions(from: week, to: now),
      HealthKitWrapper.getActivityHistory(7),
    ]);

    final recovery = results[0] as RecoveryScore;
    final bmi = results[1] as BmiResult?;
    final exercises = results[2] as List<ExerciseSession>;
    final history = results[3] as List<({DateTime date, AggregatedActivity activity})>;

    final suggestions = <ExerciseSuggestion>[];
    final avgSteps = history.isEmpty ? 0 :
        history.map((d) => d.activity.steps).reduce((a, b) => a + b) ~/ history.length;
    final recentTypes = exercises.map((e) => e.exerciseType).toSet();

    // Recovery-based intensity
    final intensity = recovery.total >= 80 ? 'Vigorous' :
        recovery.total >= 60 ? 'Moderate' : 'Light';
    final durMin = recovery.total >= 80 ? 45 : recovery.total >= 60 ? 30 : 20;

    if (recovery.total < 40) {
      suggestions.add(ExerciseSuggestion(
        focus: 'Active Recovery',
        type: 'Walking or gentle yoga',
        intensity: 'Light',
        durationMin: 20,
        rationale: 'Recovery score is ${recovery.total}/100. Your body needs rest. '
            'Light movement aids recovery without adding stress.',
      ));
      return suggestions;
    }

    // Cardio suggestion
    if (avgSteps < 8000) {
      suggestions.add(ExerciseSuggestion(
        focus: 'Increase Daily Movement',
        type: 'Brisk walking or light jogging',
        intensity: intensity,
        durationMin: durMin,
        rationale: 'Averaging $avgSteps steps/day (below 8,000 target). '
            'Adding a ${durMin}min walk will boost daily activity.',
      ));
    } else {
      suggestions.add(ExerciseSuggestion(
        focus: 'Cardio Endurance',
        type: recentTypes.contains('running') ? 'Cycling or swimming' : 'Running',
        intensity: intensity,
        durationMin: durMin,
        rationale: 'Good step count ($avgSteps/day). Try cross-training with a '
            'different modality to build balanced fitness.',
      ));
    }

    // Strength suggestion
    final hasStrength = recentTypes.any((t) =>
        t.contains('strength') || t.contains('weight') || t.contains('calisthenics'));
    if (!hasStrength) {
      suggestions.add(ExerciseSuggestion(
        focus: 'Add Strength Training',
        type: 'Bodyweight or weight training',
        intensity: intensity,
        durationMin: 30,
        rationale: 'No strength sessions this week. 2-3 sessions/week builds '
            'lean mass and supports metabolic health.',
      ));
    }

    // BMI-based suggestion
    if (bmi != null && bmi.bmi >= 25) {
      suggestions.add(ExerciseSuggestion(
        focus: 'Fat Loss Support',
        type: 'HIIT or circuit training',
        intensity: recovery.total >= 60 ? 'Moderate-to-Vigorous' : 'Moderate',
        durationMin: 25,
        rationale: 'BMI is ${bmi.bmi.toStringAsFixed(1)} (${bmi.category}). '
            'High-intensity intervals are time-efficient for calorie burn.',
      ));
    }

    // Flexibility
    final hasYoga = recentTypes.contains('yoga') || recentTypes.contains('pilates');
    if (!hasYoga) {
      suggestions.add(ExerciseSuggestion(
        focus: 'Flexibility & Mobility',
        type: 'Yoga or stretching',
        intensity: 'Light',
        durationMin: 15,
        rationale: 'No flexibility work this week. 15 minutes improves '
            'range of motion and aids recovery.',
      ));
    }

    return suggestions;
  }

  // ── Did user exercise today? ───────────────────────────────

  static Future<bool> hasExercisedToday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exercises = await HealthKitWrapper.readExerciseSessions(from: today, to: now);
    if (exercises.isNotEmpty) return true;
    // Also check if steps are above a reasonable threshold
    final activity = await HealthKitWrapper.aggregateActivity(from: today, to: now);
    return activity.steps >= 5000;
  }
}
