import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_kit_wrapper/health_kit_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const observerChannel = EventChannel('com.healthkitwrapper/observer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockStreamHandler(observerChannel, null);
  });

  test('observerQuery forwards parsed updates and filters no-change events',
      () async {
    messenger.setMockStreamHandler(
      observerChannel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          // A no-change tick (must be filtered out by observerQuery).
          sink.success(<String, Object?>{
            'observerId': 'obs-1',
            'hasChanges': false,
            'insertedTypes': <String>[],
            'deletedTypes': <String>[],
            'timestampMs': 1700000000000,
          });
          // A real change (must be delivered).
          sink.success(<String, Object?>{
            'observerId': 'obs-1',
            'hasChanges': true,
            'insertedTypes': <String>['steps'],
            'deletedTypes': <String>['sleep'],
            'timestampMs': 1700000060000,
          });
        },
      ),
    );

    final updates = <ObserverUpdate>[];
    final sub = HealthKitWrapper.observerQuery(
      types: [RecordType.steps, RecordType.sleep],
      intervalMs: 15000,
      observerId: 'obs-1',
      onUpdate: updates.add,
    );

    // Let the broadcast stream deliver queued events.
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(updates, hasLength(1));
    expect(updates.single.hasChanges, isTrue);
    expect(updates.single.observerId, 'obs-1');
    expect(updates.single.insertedTypes, ['steps']);
    expect(updates.single.deletedTypes, ['sleep']);
  });

  test('observerQuery sends type identifiers and interval as listen args',
      () async {
    Object? captured;
    messenger.setMockStreamHandler(
      observerChannel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) => captured = arguments,
      ),
    );

    final sub = HealthKitWrapper.observerQuery(
      types: [RecordType.heartRate],
      intervalMs: 30000,
      observerId: 'hr-watch',
      onUpdate: (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    final args = Map<String, dynamic>.from(captured as Map);
    expect(args['types'], ['heartRate']);
    expect(args['intervalMs'], 30000);
    expect(args['observerId'], 'hr-watch');
  });
}
