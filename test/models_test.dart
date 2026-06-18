import 'package:flutter_test/flutter_test.dart';
import 'package:health_kit_wrapper/models/activity.dart';
import 'package:health_kit_wrapper/models/sleep.dart';
import 'package:health_kit_wrapper/models/vitals.dart';
import 'package:health_kit_wrapper/models/body.dart';
import 'package:health_kit_wrapper/models/exercise.dart';
import 'package:health_kit_wrapper/models/nutrition.dart';
import 'package:health_kit_wrapper/models/observer_update.dart';

void main() {
  group('AggregatedActivity', () {
    test('fromMap with realistic Android Health Connect data', () {
      final a = AggregatedActivity.fromMap({
        'steps': 8432,
        'distanceM': 6510.5,
        'floors': 12.0,
        'activeKcal': 345.7,
        'totalKcal': 1876.2,
        'dataOrigins': ['com.samsung.android.wear.shealth', 'com.google.android.apps.fitness'],
      });

      expect(a.steps, 8432);
      expect(a.distanceKm, closeTo(6.51, 0.01));
      expect(a.floors, 12.0);
      expect(a.activeCaloriesKcal, 345.7);
      expect(a.totalCaloriesKcal, 1876.2);
      expect(a.dataOrigins, hasLength(2));
    });

    test('fromMap handles nulls gracefully', () {
      final a = AggregatedActivity.fromMap({});
      expect(a.steps, 0);
      expect(a.distanceKm, 0);
      expect(a.floors, 0);
      expect(a.activeCaloriesKcal, 0);
      expect(a.dataOrigins, isEmpty);
    });

    test('empty factory returns zeroed values', () {
      final a = AggregatedActivity.empty();
      expect(a.steps, 0);
      expect(a.distanceKm, 0);
      expect(a.dataOrigins, isEmpty);
    });

    test('toMap roundtrip', () {
      final original = AggregatedActivity(
        steps: 1000,
        distanceKm: 0.8,
        floors: 3,
        activeCaloriesKcal: 100,
        totalCaloriesKcal: 500,
        dataOrigins: ['com.test'],
      );
      final restored = AggregatedActivity.fromMap(original.toMap());
      expect(restored.steps, original.steps);
      expect(restored.distanceKm, closeTo(original.distanceKm, 0.01));
      expect(restored.activeCaloriesKcal, original.activeCaloriesKcal);
    });
  });

  group('StepsSample', () {
    test('fromMap with epoch milliseconds', () {
      final s = StepsSample.fromMap({
        'count': 150,
        'startMs': 1700000000000,
        'endMs': 1700000300000,
        'source': 'com.samsung.health',
        'device': 'Galaxy Watch 6',
      });

      expect(s.count, 150);
      expect(s.source, 'com.samsung.health');
      expect(s.device, 'Galaxy Watch 6');
      expect(s.start.millisecondsSinceEpoch, 1700000000000);
      expect(s.end.millisecondsSinceEpoch, 1700000300000);
    });
  });

  group('SleepSession', () {
    test('fromMap with full stage breakdown', () {
      final s = SleepSession.fromMap({
        'startMs': 1700000000000,
        'endMs': 1700028800000, // 8 hours later
        'durationMinutes': 480,
        'source': 'com.samsung.android.wear.shealth',
        'device': 'Galaxy Watch 6',
        'title': 'Sleep',
        'notes': '',
        'stages': [
          {'stage': 'light', 'startMs': 1700000000000, 'endMs': 1700003600000, 'durationMinutes': 60},
          {'stage': 'deep', 'startMs': 1700003600000, 'endMs': 1700010800000, 'durationMinutes': 120},
          {'stage': 'rem', 'startMs': 1700010800000, 'endMs': 1700018000000, 'durationMinutes': 120},
          {'stage': 'light', 'startMs': 1700018000000, 'endMs': 1700025200000, 'durationMinutes': 120},
          {'stage': 'awake', 'startMs': 1700025200000, 'endMs': 1700028800000, 'durationMinutes': 60},
        ],
        'breakdown': {
          'deepMinutes': 120,
          'remMinutes': 120,
          'lightMinutes': 180,
          'awakeMinutes': 60,
          'asleepMinutes': 0,
        },
      });

      expect(s.durationMinutes, 480);
      expect(s.stages, hasLength(5));
      expect(s.breakdown.deepMinutes, 120);
      expect(s.breakdown.remMinutes, 120);
      expect(s.breakdown.lightMinutes, 180);
      expect(s.breakdown.awakeMinutes, 60);
      expect(s.breakdown.totalSleepMinutes, 420); // 120+120+180+0
      expect(s.efficiency, closeTo(0.875, 0.01)); // 420/480
    });

    test('fromMap computes breakdown from stages when not provided', () {
      final s = SleepSession.fromMap({
        'startMs': 1700000000000,
        'endMs': 1700014400000,
        'durationMinutes': 240,
        'source': 'com.apple.health',
        'stages': [
          {'stage': 'deep', 'startMs': 1700000000000, 'endMs': 1700003600000, 'durationMinutes': 60},
          {'stage': 'light', 'startMs': 1700003600000, 'endMs': 1700010800000, 'durationMinutes': 120},
          {'stage': 'awake', 'startMs': 1700010800000, 'endMs': 1700014400000, 'durationMinutes': 60},
        ],
      });

      expect(s.breakdown.deepMinutes, 60);
      expect(s.breakdown.lightMinutes, 120);
      expect(s.breakdown.awakeMinutes, 60);
    });
  });

  group('HeartRateSample', () {
    test('fromMap', () {
      final hr = HeartRateSample.fromMap({
        'bpm': 72,
        'timeMs': 1700000000000,
        'source': 'com.apple.health',
        'device': 'Apple Watch',
      });
      expect(hr.bpm, 72);
      expect(hr.source, 'com.apple.health');
    });
  });

  group('HrvSample', () {
    test('fromMap with RMSSD (Android)', () {
      final hrv = HrvSample.fromMap({
        'rmssdMs': 42.5,
        'timeMs': 1700000000000,
        'source': 'com.samsung.health',
        'device': 'Galaxy Watch',
      });
      expect(hrv.rmssdMs, 42.5);
      expect(hrv.sdnnMs, isNull);
      expect(hrv.valueMs, 42.5);
    });

    test('fromMap with SDNN (iOS)', () {
      final hrv = HrvSample.fromMap({
        'sdnnMs': 55.3,
        'timeMs': 1700000000000,
        'source': 'com.apple.health',
        'device': 'Apple Watch',
      });
      expect(hrv.sdnnMs, 55.3);
      expect(hrv.rmssdMs, isNull);
      expect(hrv.valueMs, 55.3);
    });

    test('valueMs prefers RMSSD over SDNN when both present', () {
      final hrv = HrvSample.fromMap({
        'rmssdMs': 40.0,
        'sdnnMs': 50.0,
        'timeMs': 1700000000000,
        'source': 'test',
      });
      expect(hrv.valueMs, 40.0);
    });
  });

  group('BloodPressureSample', () {
    test('fromMap', () {
      final bp = BloodPressureSample.fromMap({
        'systolicMmhg': 120.0,
        'diastolicMmhg': 80.0,
        'bodyPosition': 'sitting',
        'measurementLoc': 'leftArm',
        'timeMs': 1700000000000,
        'source': 'com.withings.wiscale2',
        'device': 'BPM Core',
      });
      expect(bp.systolicMmhg, 120.0);
      expect(bp.diastolicMmhg, 80.0);
      expect(bp.bodyPosition, 'sitting');
    });
  });

  group('BloodGlucoseSample', () {
    test('fromMap with both units', () {
      final bg = BloodGlucoseSample.fromMap({
        'mmolPerL': 5.5,
        'mgPerDl': 99.0,
        'mealType': 'fasting',
        'timeMs': 1700000000000,
        'source': 'com.dexcom.cgm',
      });
      expect(bg.mmolPerL, 5.5);
      expect(bg.mgPerDl, 99.0);
    });
  });

  group('WeightSample', () {
    test('fromMap with kg and lbs', () {
      final w = WeightSample.fromMap({
        'kg': 75.5,
        'lbs': 166.4,
        'timeMs': 1700000000000,
        'source': 'com.withings.wiscale2',
      });
      expect(w.kg, 75.5);
      expect(w.lbs, 166.4);
      expect(w.poundsValue, 166.4);
    });

    test('poundsValue computes from kg when lbs missing', () {
      final w = WeightSample.fromMap({
        'kg': 70.0,
        'timeMs': 1700000000000,
        'source': 'test',
      });
      expect(w.lbs, isNull);
      expect(w.poundsValue, closeTo(154.32, 0.1));
    });
  });

  group('HeightSample', () {
    test('fromMap', () {
      final h = HeightSample.fromMap({
        'meters': 1.80,
        'cm': 180.0,
        'timeMs': 1700000000000,
        'source': 'manual',
      });
      expect(h.meters, 1.80);
      expect(h.centimeters, 180.0);
    });

    test('centimeters computed when cm missing', () {
      final h = HeightSample.fromMap({
        'meters': 1.75,
        'timeMs': 1700000000000,
        'source': 'test',
      });
      expect(h.centimeters, closeTo(175, 0.1));
    });
  });

  group('BodyFatSample', () {
    test('fromMap', () {
      final bf = BodyFatSample.fromMap({
        'percentage': 18.5,
        'timeMs': 1700000000000,
        'source': 'com.withings.wiscale2',
      });
      expect(bf.percentage, 18.5);
    });
  });

  group('ExerciseSession', () {
    test('fromMap with laps and segments', () {
      final e = ExerciseSession.fromMap({
        'exerciseType': 'running',
        'title': 'Morning Run',
        'notes': 'Felt good',
        'startMs': 1700000000000,
        'endMs': 1700003600000,
        'durationMinutes': 60,
        'source': 'com.strava',
        'device': 'Galaxy Watch',
        'laps': [
          {'startMs': 1700000000000, 'endMs': 1700001800000, 'lengthM': 5000.0},
        ],
        'segments': [
          {'type': 'warmup', 'startMs': 1700000000000, 'endMs': 1700000600000, 'reps': 0},
        ],
      });

      expect(e.exerciseType, 'running');
      expect(e.title, 'Morning Run');
      expect(e.durationMinutes, 60);
      expect(e.laps, hasLength(1));
      expect(e.laps.first.lengthMeters, 5000.0);
      expect(e.segments, hasLength(1));
      expect(e.segments.first.type, 'warmup');
    });
  });

  group('NutritionRecord', () {
    test('fromMap with macros', () {
      final n = NutritionRecord.fromMap({
        'name': 'Lunch',
        'mealType': 'lunch',
        'energyKcal': 650.0,
        'proteinG': 35.0,
        'carbohydratesG': 80.0,
        'fatG': 20.0,
        'fiberG': 8.0,
        'sugarG': 12.0,
        'sodiumMg': 800.0,
        'startMs': 1700000000000,
        'endMs': 1700003600000,
        'source': 'com.myfitnesspal.android',
      });

      expect(n.name, 'Lunch');
      expect(n.energyKcal, 650.0);
      expect(n.proteinG, 35.0);
      expect(n.carbohydratesG, 80.0);
    });
  });

  group('HydrationRecord', () {
    test('fromMap and computed ml', () {
      final h = HydrationRecord.fromMap({
        'volumeLiters': 0.5,
        'startMs': 1700000000000,
        'endMs': 1700000060000,
        'source': 'com.watertracker',
      });
      expect(h.volumeLiters, 0.5);
      expect(h.volumeMl, 500.0);
    });
  });

  group('ObserverUpdate', () {
    test('fromMap', () {
      final u = ObserverUpdate.fromMap({
        'observerId': 'home_screen',
        'hasChanges': true,
        'insertedTypes': ['steps', 'heartRate'],
        'deletedTypes': [],
        'timestampMs': 1700000000000,
      });

      expect(u.observerId, 'home_screen');
      expect(u.hasChanges, true);
      expect(u.insertedTypes, hasLength(2));
      expect(u.deletedTypes, isEmpty);
      expect(u.timestamp.millisecondsSinceEpoch, 1700000000000);
    });

    test('fromMap handles missing fields', () {
      final u = ObserverUpdate.fromMap({});
      expect(u.observerId, '');
      expect(u.hasChanges, false);
      expect(u.insertedTypes, isEmpty);
    });
  });
}
