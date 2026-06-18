/// Weight sample in kg and lbs.
class WeightSample {
  const WeightSample({
    required this.kg,
    this.lbs,
    required this.timestamp,
    required this.source,
    this.device = '',
  });

  final double kg;
  final double? lbs;
  final DateTime timestamp;
  final String source;
  final String device;

  /// lbs value — computed from kg if not provided by native.
  double get poundsValue => lbs ?? kg * 2.20462;

  factory WeightSample.fromMap(Map<String, dynamic> m) => WeightSample(
    kg:        (m['kg'] as num).toDouble(),
    lbs:       (m['lbs'] as num?)?.toDouble(),
    timestamp: DateTime.fromMillisecondsSinceEpoch((m['timeMs'] as num).toInt()),
    source:    m['source'] as String? ?? '',
    device:    m['device'] as String? ?? '',
  );
}

/// Height sample in meters and cm.
class HeightSample {
  const HeightSample({
    required this.meters,
    this.cm,
    required this.timestamp,
    required this.source,
    this.device = '',
  });

  final double meters;
  final double? cm;
  final DateTime timestamp;
  final String source;
  final String device;

  double get centimeters => cm ?? meters * 100;

  factory HeightSample.fromMap(Map<String, dynamic> m) => HeightSample(
    meters:    (m['meters'] as num).toDouble(),
    cm:        (m['cm'] as num?)?.toDouble(),
    timestamp: DateTime.fromMillisecondsSinceEpoch((m['timeMs'] as num).toInt()),
    source:    m['source'] as String? ?? '',
    device:    m['device'] as String? ?? '',
  );
}

/// Body fat percentage sample.
class BodyFatSample {
  const BodyFatSample({
    required this.percentage,
    required this.timestamp,
    required this.source,
    this.device = '',
  });

  final double percentage;
  final DateTime timestamp;
  final String source;
  final String device;

  factory BodyFatSample.fromMap(Map<String, dynamic> m) => BodyFatSample(
    percentage: (m['percentage'] as num).toDouble(),
    timestamp:  DateTime.fromMillisecondsSinceEpoch((m['timeMs'] as num).toInt()),
    source:     m['source'] as String? ?? '',
    device:     m['device'] as String? ?? '',
  );
}
