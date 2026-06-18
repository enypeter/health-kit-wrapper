/// Health data types supported by both HealthKit (iOS) and Health Connect (Android).
///
/// The [identifier] string is the key exchanged over the platform channel —
/// both native sides map it to the appropriate SDK type.
enum RecordType {
  // Activity
  steps('steps'),
  distance('distance'),
  floors('floors'),
  activeCalories('activeCalories'),
  totalCalories('totalCalories'),
  exercise('exercise'),
  speed('speed'),
  power('power'),

  // Sleep
  sleep('sleep'),

  // Vitals
  heartRate('heartRate'),
  restingHeartRate('restingHeartRate'),
  heartRateVariability('heartRateVariability'),
  oxygenSaturation('oxygenSaturation'),
  bloodPressure('bloodPressure'),
  bloodGlucose('bloodGlucose'),
  respiratoryRate('respiratoryRate'),
  vo2Max('vo2Max'),
  bodyTemperature('bodyTemperature'),

  // Body
  height('height'),
  weight('weight'),
  bodyFat('bodyFat'),
  leanBodyMass('leanBodyMass'),
  boneMass('boneMass'),
  basalMetabolicRate('basalMetabolicRate'),

  // Nutrition
  nutrition('nutrition'),
  hydration('hydration');

  const RecordType(this.identifier);

  /// The string sent over the platform channel to identify this type.
  final String identifier;

  /// Look up a [RecordType] by its channel identifier string.
  /// Returns `null` if the identifier is not recognised.
  static RecordType? fromIdentifier(String id) {
    for (final type in values) {
      if (type.identifier == id) return type;
    }
    return null;
  }
}
