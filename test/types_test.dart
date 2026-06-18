import 'package:flutter_test/flutter_test.dart';
import 'package:health_kit_wrapper/types/record_type.dart';
import 'package:health_kit_wrapper/types/sdk_status.dart';

void main() {
  group('RecordType', () {
    test('identifier roundtrip for all values', () {
      for (final type in RecordType.values) {
        expect(type.identifier, isNotEmpty);
        expect(RecordType.fromIdentifier(type.identifier), equals(type));
      }
    });

    test('fromIdentifier returns null for unknown', () {
      expect(RecordType.fromIdentifier('nonExistent'), isNull);
      expect(RecordType.fromIdentifier(''), isNull);
    });

    test('known identifiers match expected strings', () {
      expect(RecordType.steps.identifier, 'steps');
      expect(RecordType.heartRate.identifier, 'heartRate');
      expect(RecordType.heartRateVariability.identifier, 'heartRateVariability');
      expect(RecordType.sleep.identifier, 'sleep');
      expect(RecordType.bloodPressure.identifier, 'bloodPressure');
      expect(RecordType.weight.identifier, 'weight');
      expect(RecordType.nutrition.identifier, 'nutrition');
      expect(RecordType.hydration.identifier, 'hydration');
    });
  });

  group('SdkStatus', () {
    test('fromString parses known values', () {
      expect(SdkStatus.fromString('available'), SdkStatus.available);
      expect(SdkStatus.fromString('notInstalled'), SdkStatus.notInstalled);
      expect(SdkStatus.fromString('unavailable'), SdkStatus.unavailable);
    });

    test('fromString defaults to unavailable for unknown', () {
      expect(SdkStatus.fromString(''), SdkStatus.unavailable);
      expect(SdkStatus.fromString('garbage'), SdkStatus.unavailable);
    });
  });
}
