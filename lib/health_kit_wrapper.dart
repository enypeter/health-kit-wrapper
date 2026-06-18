import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'types/record_type.dart';
import 'types/sdk_status.dart';
import 'models/activity.dart';
import 'models/sleep.dart';
import 'models/vitals.dart';
import 'models/body.dart';
import 'models/exercise.dart';
import 'models/nutrition.dart';
import 'models/observer_update.dart';

// Re-export models so consumers only need one import.
export 'types/record_type.dart';
export 'types/sdk_status.dart';
export 'models/activity.dart';
export 'models/sleep.dart';
export 'models/vitals.dart';
export 'models/body.dart';
export 'models/exercise.dart';
export 'models/nutrition.dart';
export 'models/observer_update.dart';

/// Unified health data API for iOS (HealthKit) and Android (Health Connect).
///
/// Both platforms respond to the same method names and return identical
/// Map structures — the Dart layer is platform-agnostic.
///
/// Usage:
/// ```dart
/// final status = await HealthKitWrapper.getSdkStatus();
/// final granted = await HealthKitWrapper.requestPermissions(
///   readTypes: [RecordType.steps, RecordType.sleep, RecordType.heartRate],
/// );
/// final activity = await HealthKitWrapper.aggregateActivity(
///   from: DateTime.now().subtract(const Duration(days: 1)),
///   to:   DateTime.now(),
/// );
/// ```
class HealthKitWrapper {
  HealthKitWrapper._();

  // ── Channels ─────────────────────────────────────────────────
  static const _manager  = MethodChannel('com.healthkitwrapper/manager');
  static const _reader   = MethodChannel('com.healthkitwrapper/reader');
  static const _observer = EventChannel('com.healthkitwrapper/observer');

  /// Whether we are running on iOS (HealthKit) or Android (Health Connect).
  static bool get isIOS => Platform.isIOS;

  // ─────────────────────────────────────────────────────────────
  // MANAGER
  // ─────────────────────────────────────────────────────────────

  /// Check if the platform health SDK is available.
  ///
  /// On Android, returns [SdkStatus.notInstalled] if Health Connect needs
  /// to be downloaded. On iOS, returns [SdkStatus.available] or
  /// [SdkStatus.unavailable].
  static Future<SdkStatus> getSdkStatus() async {
    try {
      final result = await _manager.invokeMethod<String>('getSdkStatus');
      return SdkStatus.fromString(result ?? '');
    } on PlatformException catch (e) {
      debugPrint('[HealthKitWrapper] getSdkStatus error: ${e.message}');
      return SdkStatus.unavailable;
    }
  }

  /// Request read/write permissions.
  ///
  /// **Android:** Shows the Health Connect permission dialog every time
  /// if permissions are not yet granted. Call [hasPermissions] first.
  ///
  /// **iOS:** Shows the HealthKit authorization sheet once. Subsequent calls
  /// are no-ops if the user has already made a choice.
  static Future<bool> requestPermissions({
    required List<RecordType> readTypes,
    List<RecordType> writeTypes = const [],
  }) async {
    try {
      final result = await _manager.invokeMethod<bool>('requestPermissions', {
        'readTypes':  readTypes.map((t) => t.identifier).toList(),
        'writeTypes': writeTypes.map((t) => t.identifier).toList(),
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[HealthKitWrapper] requestPermissions error: ${e.message}');
      return false;
    }
  }

  /// Check if all specified permissions are currently granted.
  ///
  /// **iOS caveat:** HealthKit does not reveal read authorization status
  /// for privacy reasons. This method checks write authorization on iOS
  /// and returns `true` optimistically for read-only types.
  static Future<bool> hasPermissions({
    required List<RecordType> readTypes,
    List<RecordType> writeTypes = const [],
  }) async {
    try {
      final result = await _manager.invokeMethod<bool>('hasPermissions', {
        'readTypes':  readTypes.map((t) => t.identifier).toList(),
        'writeTypes': writeTypes.map((t) => t.identifier).toList(),
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[HealthKitWrapper] hasPermissions error: ${e.message}');
      return false;
    }
  }

  /// Returns all currently granted permission type names.
  static Future<List<String>> getGrantedPermissions() async {
    try {
      final result = await _manager.invokeMethod<List>('getGrantedPermissions');
      return List<String>.from(result ?? []);
    } on PlatformException catch (e) {
      debugPrint('[HealthKitWrapper] getGrantedPermissions error: ${e.message}');
      return [];
    }
  }

  /// Revoke all health permissions for this app.
  static Future<bool> revokeAllPermissions() async {
    try {
      final result = await _manager.invokeMethod<bool>('revokeAllPermissions');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[HealthKitWrapper] revokeAllPermissions error: ${e.message}');
      return false;
    }
  }

  /// Open the platform health app.
  ///
  /// **Android:** Opens Health Connect app, or falls back to Play Store
  /// if not installed.
  /// **iOS:** Opens the Health app settings.
  static Future<bool> openHealthApp() async {
    try {
      final result = await _manager.invokeMethod<bool>('openHealthApp');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[HealthKitWrapper] openHealthApp error: ${e.message}');
      return false;
    }
  }

  /// Open the Play Store to install Health Connect (Android only).
  ///
  /// No-op on iOS. Use when [getSdkStatus] returns [SdkStatus.notInstalled].
  static Future<bool> installHealthConnect() async {
    if (Platform.isIOS) return false;
    try {
      final result = await _manager.invokeMethod<bool>('installHealthConnect');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[HealthKitWrapper] installHealthConnect error: ${e.message}');
      return false;
    }
  }

  /// Get device manufacturer info for suggesting the right health app.
  ///
  /// Returns a map with `manufacturer`, `brand`, `model`, `sdkVersion`.
  /// On iOS, returns Apple device info.
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    if (Platform.isIOS) {
      return {
        'manufacturer': 'apple',
        'brand': 'apple',
        'model': 'iPhone',
        'sdkVersion': 0,
      };
    }
    try {
      final result = await _manager.invokeMethod<Map>('getDeviceInfo');
      if (result == null) return {};
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      debugPrint('[HealthKitWrapper] getDeviceInfo error: ${e.message}');
      return {};
    }
  }

  /// Suggest the best companion health app based on device manufacturer.
  ///
  /// Returns human-readable app name and package ID for the health app
  /// that syncs to Health Connect on this device.
  static Future<({String appName, String packageId, String description})>
      suggestedHealthApp() async {
    final info = await getDeviceInfo();
    final manufacturer = (info['manufacturer'] as String?) ?? '';

    return switch (manufacturer) {
      'samsung' => (
        appName: 'Samsung Health',
        packageId: 'com.sec.android.app.shealth',
        description:
            'Enable "Sync data with Health Connect" in Samsung Health settings.',
      ),
      'huawei' => (
        appName: 'Huawei Health',
        packageId: 'com.huawei.health',
        description:
            'Enable Health Connect sync in Huawei Health settings.',
      ),
      'xiaomi' || 'redmi' || 'poco' => (
        appName: 'Mi Fitness',
        packageId: 'com.xiaomi.wearable',
        description:
            'Enable Health Connect sync in Mi Fitness settings.',
      ),
      'oppo' || 'realme' || 'oneplus' => (
        appName: 'HeyTap Health',
        packageId: 'com.heytap.health',
        description:
            'Enable Health Connect sync in HeyTap Health settings.',
      ),
      'google' => (
        appName: 'Google Fit',
        packageId: 'com.google.android.apps.fitness',
        description:
            'Google Fit syncs automatically with Health Connect on Pixel devices.',
      ),
      _ => (
        appName: 'Google Fit',
        packageId: 'com.google.android.apps.fitness',
        description:
            'Install a Health Connect-compatible fitness app to sync your data.',
      ),
    };
  }

  // ─────────────────────────────────────────────────────────────
  // READER — AGGREGATE QUERIES
  // ─────────────────────────────────────────────────────────────

  /// Aggregate all activity metrics in one round-trip.
  static Future<AggregatedActivity> aggregateActivity({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _reader.invokeMethod<Map>(
        'aggregateActivity',
        _dateArgs(from, to),
      );
      if (result == null) return AggregatedActivity.empty();
      return AggregatedActivity.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      debugPrint('[HealthKitWrapper] aggregateActivity error: ${e.message}');
      return AggregatedActivity.empty();
    }
  }

  /// Aggregate steps only.
  static Future<({int total, List<String> sources})> aggregateSteps({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _reader.invokeMethod<Map>(
        'aggregateSteps',
        _dateArgs(from, to),
      );
      if (result == null) return (total: 0, sources: <String>[]);
      final m = Map<String, dynamic>.from(result);
      return (
        total:   (m['total'] as num).toInt(),
        sources: List<String>.from(m['dataOrigins'] ?? []),
      );
    } on PlatformException {
      return (total: 0, sources: <String>[]);
    }
  }

  /// Aggregate calories — returns active, total, and basal in kcal.
  static Future<({double activeKcal, double totalKcal, double basalKcal,
      List<String> sources})> aggregateCalories({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _reader.invokeMethod<Map>(
        'aggregateCalories',
        _dateArgs(from, to),
      );
      if (result == null) {
        return (activeKcal: 0.0, totalKcal: 0.0, basalKcal: 0.0, sources: <String>[]);
      }
      final m = Map<String, dynamic>.from(result);
      return (
        activeKcal: (m['activeKcal'] as num).toDouble(),
        totalKcal:  (m['totalKcal']  as num).toDouble(),
        basalKcal:  (m['basalKcal']  as num).toDouble(),
        sources:    List<String>.from(m['dataOrigins'] ?? []),
      );
    } on PlatformException {
      return (activeKcal: 0.0, totalKcal: 0.0, basalKcal: 0.0, sources: <String>[]);
    }
  }

  /// Aggregate distance in meters.
  static Future<({double meters, List<String> sources})> aggregateDistance({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _reader.invokeMethod<Map>(
        'aggregateDistance',
        _dateArgs(from, to),
      );
      if (result == null) return (meters: 0.0, sources: <String>[]);
      final m = Map<String, dynamic>.from(result);
      return (
        meters:  (m['meters'] as num).toDouble(),
        sources: List<String>.from(m['dataOrigins'] ?? []),
      );
    } on PlatformException {
      return (meters: 0.0, sources: <String>[]);
    }
  }

  /// Aggregate floors climbed.
  static Future<({double total, List<String> sources})> aggregateFloors({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _reader.invokeMethod<Map>(
        'aggregateFloors',
        _dateArgs(from, to),
      );
      if (result == null) return (total: 0.0, sources: <String>[]);
      final m = Map<String, dynamic>.from(result);
      return (
        total:   (m['total'] as num).toDouble(),
        sources: List<String>.from(m['dataOrigins'] ?? []),
      );
    } on PlatformException {
      return (total: 0.0, sources: <String>[]);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // READER — SAMPLE QUERIES
  // ─────────────────────────────────────────────────────────────

  static Future<List<StepsSample>> readSteps({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readSteps', from, to, StepsSample.fromMap);

  static Future<List<SleepSession>> readSleep({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readSleep', from, to, SleepSession.fromMap);

  static Future<List<HeartRateSample>> readHeartRate({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readHeartRate', from, to, HeartRateSample.fromMap);

  static Future<List<HeartRateSample>> readRestingHeartRate({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readRestingHeartRate', from, to, HeartRateSample.fromMap);

  /// Read HRV samples.
  ///
  /// **Android:** Returns RMSSD (ms) in [HrvSample.rmssdMs].
  /// **iOS:** Returns SDNN (ms) in [HrvSample.sdnnMs].
  /// These are different metrics — do not compare directly across platforms.
  static Future<List<HrvSample>> readHeartRateVariability({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readHeartRateVariability', from, to, HrvSample.fromMap);

  static Future<List<OxygenSaturationSample>> readOxygenSaturation({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readOxygenSaturation', from, to, OxygenSaturationSample.fromMap);

  static Future<List<BloodPressureSample>> readBloodPressure({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readBloodPressure', from, to, BloodPressureSample.fromMap);

  static Future<List<BloodGlucoseSample>> readBloodGlucose({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readBloodGlucose', from, to, BloodGlucoseSample.fromMap);

  static Future<List<RespiratoryRateSample>> readRespiratoryRate({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readRespiratoryRate', from, to, RespiratoryRateSample.fromMap);

  static Future<List<Vo2MaxSample>> readVo2Max({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readVo2Max', from, to, Vo2MaxSample.fromMap);

  static Future<List<BodyTemperatureSample>> readBodyTemperature({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readBodyTemperature', from, to, BodyTemperatureSample.fromMap);

  static Future<List<WeightSample>> readWeight({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readWeight', from, to, WeightSample.fromMap);

  static Future<List<HeightSample>> readHeight({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readHeight', from, to, HeightSample.fromMap);

  static Future<List<BodyFatSample>> readBodyFat({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readBodyFat', from, to, BodyFatSample.fromMap);

  static Future<List<WeightSample>> readLeanBodyMass({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readLeanBodyMass', from, to, WeightSample.fromMap);

  static Future<List<ExerciseSession>> readExerciseSessions({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readExerciseSessions', from, to, ExerciseSession.fromMap);

  static Future<List<NutritionRecord>> readNutrition({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readNutrition', from, to, NutritionRecord.fromMap);

  static Future<List<HydrationRecord>> readHydration({
    required DateTime from,
    required DateTime to,
  }) async =>
      _readList('readHydration', from, to, HydrationRecord.fromMap);

  // ─────────────────────────────────────────────────────────────
  // OBSERVER
  // ─────────────────────────────────────────────────────────────

  /// Observe the platform health store for data changes.
  ///
  /// **Android:** Polls via Health Connect ChangesToken at [intervalMs].
  /// **iOS:** Push-based via HKObserverQuery ([intervalMs] ignored).
  ///
  /// Returns a [StreamSubscription] — cancel it when you're done.
  static StreamSubscription<ObserverUpdate> observerQuery({
    required List<RecordType> types,
    int intervalMs = 30000,
    String? observerId,
    required void Function(ObserverUpdate update) onUpdate,
    void Function(Object error)? onError,
  }) {
    final id = observerId ?? types.map((t) => t.identifier).join(',');

    return _observer
        .receiveBroadcastStream({
          'types':      types.map((t) => t.identifier).toList(),
          'intervalMs': intervalMs,
          'observerId': id,
        })
        .where((event) => event is Map)
        .map((event) =>
            ObserverUpdate.fromMap(Map<String, dynamic>.from(event as Map)))
        .where((update) => update.hasChanges)
        .listen(
          onUpdate,
          onError: onError ??
              (e) => debugPrint('[HealthKitWrapper] observer error: $e'),
        );
  }

  // ─────────────────────────────────────────────────────────────
  // CONVENIENCE
  // ─────────────────────────────────────────────────────────────

  /// Fetch [days] days of aggregated activity history (newest-first).
  static Future<List<({DateTime date, AggregatedActivity activity})>>
      getActivityHistory(int days) async {
    final now = DateTime.now();
    final futures = List.generate(days, (i) {
      final date  = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final start = date;
      final end   = date.add(const Duration(days: 1));
      return aggregateActivity(from: start, to: end)
          .then((a) => (date: date, activity: a));
    });
    return Future.wait(futures);
  }

  /// Fetch sleep sessions for the last [days] nights.
  static Future<List<SleepSession>> getSleepHistory(int days) async {
    final now = DateTime.now();
    return readSleep(from: now.subtract(Duration(days: days)), to: now);
  }

  // ─────────────────────────────────────────────────────────────
  // INTERNAL
  // ─────────────────────────────────────────────────────────────

  static Map<String, dynamic> _dateArgs(DateTime from, DateTime to) => {
    'startTimestamp': from.millisecondsSinceEpoch,
    'endTimestamp':   to.millisecondsSinceEpoch,
  };

  static Future<List<T>> _readList<T>(
    String method,
    DateTime from,
    DateTime to,
    T Function(Map<String, dynamic>) fromMap,
  ) async {
    try {
      final raw = await _reader.invokeMethod<List>(method, _dateArgs(from, to));
      return (raw ?? [])
          .map((e) => fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('[HealthKitWrapper] $method error: ${e.message}');
      return [];
    }
  }
}
