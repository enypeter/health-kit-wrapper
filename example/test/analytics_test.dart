// Tests for the example app's pure business logic (scoring + profile).
//
// The screens drive platform channels and timers, so the dashboard widgets
// are exercised on-device rather than here; these tests cover the
// deterministic analytics/profile logic that has no platform dependency.

import 'package:flutter_test/flutter_test.dart';
import 'package:health_kit_wrapper/health_kit_wrapper.dart';

import 'package:health_kit_wrapper_example/models/user_profile.dart';
import 'package:health_kit_wrapper_example/services/health_analytics.dart';

void main() {
  group('HealthAnalytics.computeSleepScore', () {
    SleepSession sessionWith({
      required int durationMinutes,
      required int deep,
      required int rem,
      required int light,
      required int awake,
    }) {
      return SleepSession.fromMap({
        'startMs': 1700000000000,
        'endMs': 1700000000000 + durationMinutes * 60000,
        'durationMinutes': durationMinutes,
        'source': 'test',
        'device': '',
        'title': '',
        'notes': '',
        'stages': const [],
        'breakdown': {
          'deepMinutes': deep,
          'remMinutes': rem,
          'lightMinutes': light,
          'awakeMinutes': awake,
          'asleepMinutes': 0,
        },
      });
    }

    test('a healthy 8h night scores Excellent', () {
      final score = HealthAnalytics.computeSleepScore(
        sessionWith(durationMinutes: 480, deep: 120, rem: 120, light: 220, awake: 5),
      );

      expect(score.durationPts, 25); // 8h is in the ideal 7-9h band
      expect(score.deepPts, 20); // 25% deep
      expect(score.remPts, 20); // 25% rem
      expect(score.awakePenaltyPts, 10); // <=10 min awake
      expect(score.total, greaterThanOrEqualTo(85));
      expect(score.label, 'Excellent');
    });

    test('a short, fragmented night scores Poor', () {
      final score = HealthAnalytics.computeSleepScore(
        sessionWith(durationMinutes: 240, deep: 5, rem: 5, light: 110, awake: 60),
      );

      expect(score.durationPts, 5); // 4h is well below ideal
      expect(score.awakePenaltyPts, 0); // >40 min awake
      expect(score.total, lessThan(50));
      expect(score.label, 'Poor');
    });
  });

  group('UserProfile', () {
    test('bmi and category are computed from weight and height', () {
      final p = UserProfile(weightKg: 70, heightCm: 175);
      expect(p.hasBmi, isTrue);
      expect(p.bmi, closeTo(22.86, 0.01));
      expect(p.bmiCategory, 'Normal');
    });

    test('bmi is zero when height or weight is unset', () {
      expect(UserProfile(weightKg: 70).bmi, 0);
      expect(UserProfile(heightCm: 175).hasBmi, isFalse);
    });

    test('weightDelta is the signed gap to the goal', () {
      final p = UserProfile(weightKg: 80, weightGoalKg: 75);
      expect(p.weightDelta, 5);
    });
  });
}
