/// Aggregated activity data returned by [HealthKitWrapper.aggregateActivity].
///
/// All values are deduplicated by the native SDK's aggregate API —
/// prefer this over manually summing sample records.
class AggregatedActivity {
  const AggregatedActivity({
    required this.steps,
    required this.distanceKm,
    required this.floors,
    required this.activeCaloriesKcal,
    required this.totalCaloriesKcal,
    required this.dataOrigins,
  });

  final int steps;
  final double distanceKm;
  final double floors;

  /// Always in kilocalories — never raw calories.
  final double activeCaloriesKcal;
  final double totalCaloriesKcal;

  /// Package names (Android) or bundle identifiers (iOS) of source apps.
  final List<String> dataOrigins;

  factory AggregatedActivity.empty() => const AggregatedActivity(
    steps: 0,
    distanceKm: 0,
    floors: 0,
    activeCaloriesKcal: 0,
    totalCaloriesKcal: 0,
    dataOrigins: [],
  );

  factory AggregatedActivity.fromMap(Map<String, dynamic> m) {
    return AggregatedActivity(
      steps:              (m['steps'] as num?)?.toInt() ?? 0,
      // Native returns meters — convert to km here
      distanceKm:         ((m['distanceM'] as num?)?.toDouble() ?? 0.0) / 1000,
      floors:             (m['floors'] as num?)?.toDouble() ?? 0.0,
      activeCaloriesKcal: (m['activeKcal'] as num?)?.toDouble() ?? 0.0,
      totalCaloriesKcal:  (m['totalKcal'] as num?)?.toDouble() ?? 0.0,
      dataOrigins:        List<String>.from(m['dataOrigins'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'steps':       steps,
    'distanceM':   distanceKm * 1000,
    'floors':      floors,
    'activeKcal':  activeCaloriesKcal,
    'totalKcal':   totalCaloriesKcal,
    'dataOrigins': dataOrigins,
  };

  @override
  String toString() =>
      'AggregatedActivity(steps: $steps, distanceKm: ${distanceKm.toStringAsFixed(2)}, '
      'floors: ${floors.toStringAsFixed(0)}, activeKcal: ${activeCaloriesKcal.toStringAsFixed(0)}, '
      'sources: ${dataOrigins.length})';
}

/// A single step-count record with source attribution.
class StepsSample {
  const StepsSample({
    required this.count,
    required this.start,
    required this.end,
    required this.source,
    this.device = '',
  });

  final int count;
  final DateTime start;
  final DateTime end;
  final String source;
  final String device;

  factory StepsSample.fromMap(Map<String, dynamic> m) => StepsSample(
    count:  (m['count'] as num?)?.toInt() ?? 0,
    start:  DateTime.fromMillisecondsSinceEpoch((m['startMs'] as num).toInt()),
    end:    DateTime.fromMillisecondsSinceEpoch((m['endMs'] as num).toInt()),
    source: m['source'] as String? ?? '',
    device: m['device'] as String? ?? '',
  );
}
