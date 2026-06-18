import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_kit_wrapper/health_kit_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const managerChannel = MethodChannel('com.healthkitwrapper/manager');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mockManager(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(managerChannel, handler);
  }

  tearDown(() => mockManager((_) async => null));

  test('hasPermissions sends read+write identifiers and returns true', () async {
    Map<String, dynamic>? args;
    mockManager((call) async {
      if (call.method == 'hasPermissions') {
        args = Map<String, dynamic>.from(call.arguments as Map);
        return true;
      }
      return null;
    });

    final granted = await HealthKitWrapper.hasPermissions(
      readTypes: [RecordType.steps, RecordType.sleep],
      writeTypes: [RecordType.weight],
    );

    expect(granted, isTrue);
    expect(args?['readTypes'], ['steps', 'sleep']);
    expect(args?['writeTypes'], ['weight']);
  });

  test('requestPermissions returns false on platform exception', () async {
    mockManager((_) async => throw PlatformException(code: 'DENIED'));

    final result = await HealthKitWrapper.requestPermissions(
      readTypes: [RecordType.steps],
    );
    expect(result, isFalse);
  });

  test('revokeAllPermissions returns the platform result', () async {
    mockManager((call) async => call.method == 'revokeAllPermissions');

    expect(await HealthKitWrapper.revokeAllPermissions(), isTrue);
  });

  test('getGrantedPermissions returns empty list on error', () async {
    mockManager((_) async => throw PlatformException(code: 'ERROR'));

    expect(await HealthKitWrapper.getGrantedPermissions(), isEmpty);
  });

  group('suggestedHealthApp maps manufacturer to companion app', () {
    Future<({String appName, String packageId, String description})> suggestFor(
        String manufacturer) {
      mockManager((call) async {
        if (call.method == 'getDeviceInfo') {
          return {
            'manufacturer': manufacturer,
            'brand': manufacturer,
            'model': 'test',
            'sdkVersion': 34,
          };
        }
        return null;
      });
      return HealthKitWrapper.suggestedHealthApp();
    }

    test('samsung -> Samsung Health', () async {
      final s = await suggestFor('samsung');
      expect(s.appName, 'Samsung Health');
      expect(s.packageId, 'com.sec.android.app.shealth');
    });

    test('xiaomi -> Mi Fitness', () async {
      final s = await suggestFor('xiaomi');
      expect(s.appName, 'Mi Fitness');
    });

    test('unknown manufacturer -> Google Fit fallback', () async {
      final s = await suggestFor('some-oem');
      expect(s.appName, 'Google Fit');
      expect(s.packageId, 'com.google.android.apps.fitness');
    });
  });
}
