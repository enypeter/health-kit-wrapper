import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_kit_wrapper/health_kit_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const managerChannel = MethodChannel('com.healthkitwrapper/manager');
  const readerChannel = MethodChannel('com.healthkitwrapper/reader');

  group('HealthKitWrapper Manager', () {
    test('getSdkStatus returns available', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(managerChannel, (call) async {
        if (call.method == 'getSdkStatus') return 'available';
        return null;
      });

      final status = await HealthKitWrapper.getSdkStatus();
      expect(status, SdkStatus.available);
    });

    test('getSdkStatus returns notInstalled', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(managerChannel, (call) async {
        if (call.method == 'getSdkStatus') return 'notInstalled';
        return null;
      });

      final status = await HealthKitWrapper.getSdkStatus();
      expect(status, SdkStatus.notInstalled);
    });

    test('getSdkStatus returns unavailable on error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(managerChannel, (call) async {
        throw PlatformException(code: 'ERROR');
      });

      final status = await HealthKitWrapper.getSdkStatus();
      expect(status, SdkStatus.unavailable);
    });

    test('requestPermissions sends type identifiers', () async {
      Map<String, dynamic>? capturedArgs;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(managerChannel, (call) async {
        if (call.method == 'requestPermissions') {
          capturedArgs = Map<String, dynamic>.from(call.arguments as Map);
          return true;
        }
        return null;
      });

      final result = await HealthKitWrapper.requestPermissions(
        readTypes: [RecordType.steps, RecordType.heartRate],
        writeTypes: [RecordType.weight],
      );

      expect(result, true);
      expect(capturedArgs?['readTypes'], ['steps', 'heartRate']);
      expect(capturedArgs?['writeTypes'], ['weight']);
    });

    test('hasPermissions returns false on error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(managerChannel, (call) async {
        throw PlatformException(code: 'ERROR');
      });

      final result = await HealthKitWrapper.hasPermissions(
        readTypes: [RecordType.steps],
      );
      expect(result, false);
    });

    test('getGrantedPermissions returns list', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(managerChannel, (call) async {
        if (call.method == 'getGrantedPermissions') {
          return ['steps', 'heartRate', 'sleep'];
        }
        return null;
      });

      final perms = await HealthKitWrapper.getGrantedPermissions();
      expect(perms, ['steps', 'heartRate', 'sleep']);
    });
  });

  group('HealthKitWrapper Reader', () {
    test('aggregateActivity returns parsed model', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(readerChannel, (call) async {
        if (call.method == 'aggregateActivity') {
          return {
            'steps': 5000,
            'distanceM': 3500.0,
            'floors': 8.0,
            'activeKcal': 250.0,
            'totalKcal': 1500.0,
            'dataOrigins': ['com.test.app'],
          };
        }
        return null;
      });

      final activity = await HealthKitWrapper.aggregateActivity(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 1, 2),
      );

      expect(activity.steps, 5000);
      expect(activity.distanceKm, closeTo(3.5, 0.01));
      expect(activity.activeCaloriesKcal, 250.0);
      expect(activity.dataOrigins, ['com.test.app']);
    });

    test('aggregateActivity returns empty on error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(readerChannel, (call) async {
        throw PlatformException(code: 'ERROR');
      });

      final activity = await HealthKitWrapper.aggregateActivity(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 1, 2),
      );

      expect(activity.steps, 0);
      expect(activity.dataOrigins, isEmpty);
    });

    test('readHeartRate returns parsed samples', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(readerChannel, (call) async {
        if (call.method == 'readHeartRate') {
          return [
            {'bpm': 65, 'timeMs': 1700000000000, 'source': 'com.test', 'device': 'Watch'},
            {'bpm': 72, 'timeMs': 1700000060000, 'source': 'com.test', 'device': 'Watch'},
          ];
        }
        return null;
      });

      final samples = await HealthKitWrapper.readHeartRate(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 1, 2),
      );

      expect(samples, hasLength(2));
      expect(samples[0].bpm, 65);
      expect(samples[1].bpm, 72);
      expect(samples[0].source, 'com.test');
    });

    test('readSleep returns sessions with breakdown', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(readerChannel, (call) async {
        if (call.method == 'readSleep') {
          return [
            {
              'startMs': 1700000000000,
              'endMs': 1700028800000,
              'durationMinutes': 480,
              'source': 'com.samsung.health',
              'device': '',
              'title': '',
              'notes': '',
              'stages': [
                {'stage': 'deep', 'startMs': 1700000000000, 'endMs': 1700007200000, 'durationMinutes': 120},
                {'stage': 'rem', 'startMs': 1700007200000, 'endMs': 1700014400000, 'durationMinutes': 120},
              ],
              'breakdown': {
                'deepMinutes': 120,
                'remMinutes': 120,
                'lightMinutes': 0,
                'awakeMinutes': 0,
                'asleepMinutes': 0,
              },
            }
          ];
        }
        return null;
      });

      final sessions = await HealthKitWrapper.readSleep(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 1, 2),
      );

      expect(sessions, hasLength(1));
      expect(sessions[0].breakdown.deepMinutes, 120);
      expect(sessions[0].breakdown.remMinutes, 120);
      expect(sessions[0].breakdown.totalSleepMinutes, 240);
    });

    test('readWeight returns weight samples', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(readerChannel, (call) async {
        if (call.method == 'readWeight') {
          return [
            {'kg': 75.0, 'lbs': 165.3, 'timeMs': 1700000000000, 'source': 'com.withings', 'device': ''},
          ];
        }
        return null;
      });

      final weights = await HealthKitWrapper.readWeight(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 1, 2),
      );

      expect(weights, hasLength(1));
      expect(weights[0].kg, 75.0);
      expect(weights[0].poundsValue, 165.3);
    });

    test('date args are sent as milliseconds since epoch', () async {
      Map<String, dynamic>? capturedArgs;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(readerChannel, (call) async {
        capturedArgs = Map<String, dynamic>.from(call.arguments as Map);
        return [];
      });

      final from = DateTime.utc(2024, 6, 15, 10, 0);
      final to = DateTime.utc(2024, 6, 15, 22, 0);

      await HealthKitWrapper.readHeartRate(from: from, to: to);

      expect(capturedArgs?['startTimestamp'], from.millisecondsSinceEpoch);
      expect(capturedArgs?['endTimestamp'], to.millisecondsSinceEpoch);
    });

    test('empty list on platform exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(readerChannel, (call) async {
        throw PlatformException(code: 'ERROR', message: 'test');
      });

      final result = await HealthKitWrapper.readHeartRate(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 1, 2),
      );
      expect(result, isEmpty);
    });
  });

  group('HealthKitWrapper Convenience', () {
    test('aggregateSteps returns record tuple', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(readerChannel, (call) async {
        if (call.method == 'aggregateSteps') {
          return {'total': 10000, 'dataOrigins': ['com.test']};
        }
        return null;
      });

      final result = await HealthKitWrapper.aggregateSteps(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 1, 2),
      );

      expect(result.total, 10000);
      expect(result.sources, ['com.test']);
    });

    test('aggregateCalories returns all three values', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(readerChannel, (call) async {
        if (call.method == 'aggregateCalories') {
          return {
            'activeKcal': 300.0,
            'totalKcal': 1800.0,
            'basalKcal': 1500.0,
            'dataOrigins': ['com.test'],
          };
        }
        return null;
      });

      final result = await HealthKitWrapper.aggregateCalories(
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 1, 2),
      );

      expect(result.activeKcal, 300.0);
      expect(result.totalKcal, 1800.0);
      expect(result.basalKcal, 1500.0);
    });
  });
}
