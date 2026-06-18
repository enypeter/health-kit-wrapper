/// An update event from the health data observer.
///
/// On Android this is driven by Health Connect's ChangesToken polling.
/// On iOS this is driven by HealthKit's push-based HKObserverQuery.
class ObserverUpdate {
  const ObserverUpdate({
    required this.observerId,
    required this.hasChanges,
    required this.insertedTypes,
    required this.deletedTypes,
    required this.timestamp,
  });

  final String observerId;
  final bool hasChanges;
  final List<String> insertedTypes;
  final List<String> deletedTypes;
  final DateTime timestamp;

  factory ObserverUpdate.fromMap(Map<String, dynamic> m) => ObserverUpdate(
    observerId:    m['observerId'] as String? ?? '',
    hasChanges:    m['hasChanges'] as bool? ?? false,
    insertedTypes: List<String>.from(m['insertedTypes'] ?? []),
    deletedTypes:  List<String>.from(m['deletedTypes'] ?? []),
    timestamp:     DateTime.fromMillisecondsSinceEpoch(
      (m['timestampMs'] as num?)?.toInt() ?? 0,
    ),
  );
}
