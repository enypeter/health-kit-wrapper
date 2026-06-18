/// A complete sleep session with stage breakdown.
///
/// On Android, stages come from [SleepSessionRecord.Stage].
/// On iOS (16+), stages come from [HKCategoryValueSleepAnalysis].
class SleepSession {
  const SleepSession({
    required this.start,
    required this.end,
    required this.durationMinutes,
    required this.source,
    this.device = '',
    this.title = '',
    this.notes = '',
    required this.stages,
    required this.breakdown,
  });

  final DateTime start;
  final DateTime end;
  final int durationMinutes;
  final String source;
  final String device;
  final String title;
  final String notes;
  final List<SleepStage> stages;
  final SleepBreakdown breakdown;

  /// Sleep efficiency: ratio of actual sleep to time in bed (0.0–1.0).
  double get efficiency {
    if (durationMinutes == 0) return 0;
    return breakdown.totalSleepMinutes / durationMinutes;
  }

  factory SleepSession.fromMap(Map<String, dynamic> m) {
    final stagesRaw = m['stages'] as List<dynamic>? ?? [];
    final stages = stagesRaw
        .map((s) => SleepStage.fromMap(Map<String, dynamic>.from(s as Map)))
        .toList();

    final breakdownMap = m['breakdown'] as Map?;
    final breakdown = breakdownMap != null
        ? SleepBreakdown.fromMap(Map<String, dynamic>.from(breakdownMap))
        : SleepBreakdown.fromStages(stages);

    return SleepSession(
      start:           DateTime.fromMillisecondsSinceEpoch((m['startMs'] as num).toInt()),
      end:             DateTime.fromMillisecondsSinceEpoch((m['endMs'] as num).toInt()),
      durationMinutes: (m['durationMinutes'] as num?)?.toInt() ?? 0,
      source:          m['source'] as String? ?? '',
      device:          m['device'] as String? ?? '',
      title:           m['title'] as String? ?? '',
      notes:           m['notes'] as String? ?? '',
      stages:          stages,
      breakdown:       breakdown,
    );
  }
}

/// Individual sleep stage within a session.
class SleepStage {
  const SleepStage({
    required this.stage,
    required this.start,
    required this.end,
    required this.durationMinutes,
  });

  /// One of: deep, rem, light, awake, asleep, outOfBed, unknown.
  final String stage;
  final DateTime start;
  final DateTime end;
  final int durationMinutes;

  factory SleepStage.fromMap(Map<String, dynamic> m) => SleepStage(
    stage:           m['stage'] as String? ?? 'unknown',
    start:           DateTime.fromMillisecondsSinceEpoch((m['startMs'] as num).toInt()),
    end:             DateTime.fromMillisecondsSinceEpoch((m['endMs'] as num).toInt()),
    durationMinutes: (m['durationMinutes'] as num?)?.toInt() ?? 0,
  );
}

/// Aggregated sleep stage durations for a session.
class SleepBreakdown {
  const SleepBreakdown({
    required this.deepMinutes,
    required this.remMinutes,
    required this.lightMinutes,
    required this.awakeMinutes,
    required this.asleepMinutes,
  });

  final int deepMinutes;
  final int remMinutes;
  final int lightMinutes;
  final int awakeMinutes;
  final int asleepMinutes;

  /// Total actual sleep time (excludes awake).
  int get totalSleepMinutes =>
      deepMinutes + remMinutes + lightMinutes + asleepMinutes;

  factory SleepBreakdown.fromMap(Map<String, dynamic> m) => SleepBreakdown(
    deepMinutes:   (m['deepMinutes'] as num?)?.toInt() ?? 0,
    remMinutes:    (m['remMinutes'] as num?)?.toInt() ?? 0,
    lightMinutes:  (m['lightMinutes'] as num?)?.toInt() ?? 0,
    awakeMinutes:  (m['awakeMinutes'] as num?)?.toInt() ?? 0,
    asleepMinutes: (m['asleepMinutes'] as num?)?.toInt() ?? 0,
  );

  /// Compute breakdown from a list of stages (fallback when native
  /// doesn't provide a pre-computed breakdown).
  factory SleepBreakdown.fromStages(List<SleepStage> stages) {
    int deep = 0, rem = 0, light = 0, awake = 0, asleep = 0;
    for (final s in stages) {
      switch (s.stage) {
        case 'deep':    deep   += s.durationMinutes;
        case 'rem':     rem    += s.durationMinutes;
        case 'light':   light  += s.durationMinutes;
        case 'awake':   awake  += s.durationMinutes;
        case 'asleep':  asleep += s.durationMinutes;
      }
    }
    return SleepBreakdown(
      deepMinutes: deep,
      remMinutes: rem,
      lightMinutes: light,
      awakeMinutes: awake,
      asleepMinutes: asleep,
    );
  }
}
