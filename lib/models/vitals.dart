/// Heart rate sample — individual BPM reading with source.
class HeartRateSample {
  const HeartRateSample({
    required this.bpm,
    required this.timestamp,
    required this.source,
    this.device = '',
  });

  final int bpm;
  final DateTime timestamp;
  final String source;
  final String device;

  factory HeartRateSample.fromMap(Map<String, dynamic> m) => HeartRateSample(
    bpm:       (m['bpm'] as num).toInt(),
    timestamp: DateTime.fromMillisecondsSinceEpoch((m['timeMs'] as num).toInt()),
    source:    m['source'] as String? ?? '',
    device:    m['device'] as String? ?? '',
  );
}

/// Heart rate variability sample.
///
/// **Platform difference:**
/// - Android Health Connect returns RMSSD (ms)
/// - iOS HealthKit returns SDNN (ms)
/// These are different statistical measures — do not compare directly.
class HrvSample {
  const HrvSample({
    this.rmssdMs,
    this.sdnnMs,
    required this.timestamp,
    required this.source,
    this.device = '',
  });

  /// RMSSD in milliseconds (Android). Null on iOS.
  final double? rmssdMs;

  /// SDNN in milliseconds (iOS). Null on Android.
  final double? sdnnMs;

  /// The platform-available HRV value in ms, regardless of metric type.
  double get valueMs => rmssdMs ?? sdnnMs ?? 0;

  final DateTime timestamp;
  final String source;
  final String device;

  factory HrvSample.fromMap(Map<String, dynamic> m) => HrvSample(
    rmssdMs:   (m['rmssdMs'] as num?)?.toDouble(),
    sdnnMs:    (m['sdnnMs'] as num?)?.toDouble(),
    timestamp: DateTime.fromMillisecondsSinceEpoch((m['timeMs'] as num).toInt()),
    source:    m['source'] as String? ?? '',
    device:    m['device'] as String? ?? '',
  );
}

/// Blood oxygen saturation (SpO2) sample.
class OxygenSaturationSample {
  const OxygenSaturationSample({
    required this.percentage,
    required this.timestamp,
    required this.source,
    this.device = '',
  });

  final double percentage;
  final DateTime timestamp;
  final String source;
  final String device;

  factory OxygenSaturationSample.fromMap(Map<String, dynamic> m) =>
      OxygenSaturationSample(
        percentage: (m['percentage'] as num).toDouble(),
        timestamp:  DateTime.fromMillisecondsSinceEpoch((m['timeMs'] as num).toInt()),
        source:     m['source'] as String? ?? '',
        device:     m['device'] as String? ?? '',
      );
}

/// Blood pressure reading — systolic and diastolic always paired.
class BloodPressureSample {
  const BloodPressureSample({
    required this.systolicMmhg,
    required this.diastolicMmhg,
    required this.timestamp,
    required this.source,
    this.bodyPosition = '',
    this.measurementLocation = '',
    this.device = '',
  });

  final double systolicMmhg;
  final double diastolicMmhg;
  final DateTime timestamp;
  final String source;
  final String bodyPosition;
  final String measurementLocation;
  final String device;

  factory BloodPressureSample.fromMap(Map<String, dynamic> m) =>
      BloodPressureSample(
        systolicMmhg:        (m['systolicMmhg'] as num).toDouble(),
        diastolicMmhg:       (m['diastolicMmhg'] as num).toDouble(),
        timestamp:           DateTime.fromMillisecondsSinceEpoch((m['timeMs'] as num).toInt()),
        source:              m['source'] as String? ?? '',
        bodyPosition:        m['bodyPosition'] as String? ?? '',
        measurementLocation: m['measurementLoc'] as String? ?? '',
        device:              m['device'] as String? ?? '',
      );
}

/// Blood glucose reading with meal context.
class BloodGlucoseSample {
  const BloodGlucoseSample({
    required this.mmolPerL,
    required this.mgPerDl,
    required this.timestamp,
    required this.source,
    this.mealType = '',
    this.specimenSource = '',
    this.relationToMeal = '',
    this.device = '',
  });

  final double mmolPerL;
  final double mgPerDl;
  final DateTime timestamp;
  final String source;
  final String mealType;
  final String specimenSource;
  final String relationToMeal;
  final String device;

  factory BloodGlucoseSample.fromMap(Map<String, dynamic> m) =>
      BloodGlucoseSample(
        mmolPerL:       (m['mmolPerL'] as num).toDouble(),
        mgPerDl:        (m['mgPerDl'] as num).toDouble(),
        timestamp:      DateTime.fromMillisecondsSinceEpoch((m['timeMs'] as num).toInt()),
        source:         m['source'] as String? ?? '',
        mealType:       m['mealType'] as String? ?? '',
        specimenSource: m['specimenSource'] as String? ?? '',
        relationToMeal: m['relationToMeal'] as String? ?? '',
        device:         m['device'] as String? ?? '',
      );
}

/// Respiratory rate in breaths per minute.
class RespiratoryRateSample {
  const RespiratoryRateSample({
    required this.rate,
    required this.timestamp,
    required this.source,
    this.device = '',
  });

  final double rate;
  final DateTime timestamp;
  final String source;
  final String device;

  factory RespiratoryRateSample.fromMap(Map<String, dynamic> m) =>
      RespiratoryRateSample(
        rate:      (m['rate'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch((m['timeMs'] as num).toInt()),
        source:    m['source'] as String? ?? '',
        device:    m['device'] as String? ?? '',
      );
}

/// VO2 max in ml/min/kg.
class Vo2MaxSample {
  const Vo2MaxSample({
    required this.vo2Max,
    required this.timestamp,
    required this.source,
    this.measurementMethod = '',
    this.device = '',
  });

  final double vo2Max;
  final DateTime timestamp;
  final String source;
  final String measurementMethod;
  final String device;

  factory Vo2MaxSample.fromMap(Map<String, dynamic> m) => Vo2MaxSample(
    vo2Max:            (m['vo2Max'] as num).toDouble(),
    timestamp:         DateTime.fromMillisecondsSinceEpoch((m['timeMs'] as num).toInt()),
    source:            m['source'] as String? ?? '',
    measurementMethod: m['measurementMethod'] as String? ?? '',
    device:            m['device'] as String? ?? '',
  );
}

/// Body temperature in Celsius.
class BodyTemperatureSample {
  const BodyTemperatureSample({
    required this.celsius,
    required this.timestamp,
    required this.source,
    this.measurementLocation = '',
    this.device = '',
  });

  final double celsius;
  final DateTime timestamp;
  final String source;
  final String measurementLocation;
  final String device;

  factory BodyTemperatureSample.fromMap(Map<String, dynamic> m) =>
      BodyTemperatureSample(
        celsius:             (m['celsius'] as num).toDouble(),
        timestamp:           DateTime.fromMillisecondsSinceEpoch((m['timeMs'] as num).toInt()),
        source:              m['source'] as String? ?? '',
        measurementLocation: m['measurementLoc'] as String? ?? '',
        device:              m['device'] as String? ?? '',
      );
}
