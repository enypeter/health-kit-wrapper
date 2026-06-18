# health_kit_wrapper

Unified health-data plugin for Flutter. One Dart API that routes to **HealthKit**
on iOS and **Health Connect** on Android, with deep native implementations on both
sides. Request permissions, run aggregate and sample queries across 26 health data
types, and observe live changes — all through the same code.

## Features

- **Single API** — `HealthKitWrapper` static methods; identical `Map` shapes from both platforms feed the same Dart models.
- **Permissions** — request / check / list / revoke, SDK status, open or install the platform health app.
- **Aggregates** — activity, steps, calories (active / total / basal), distance, floors.
- **Samples** — sleep (with stage breakdown), heart rate, resting HR, HRV, SpO₂, blood pressure, blood glucose, respiratory rate, VO₂ max, body temperature, weight, height, body fat, lean body mass, exercise sessions, nutrition, hydration.
- **Live observation** — one `Stream` interface; push-based `HKObserverQuery` on iOS, polling `ChangesToken` on Android.
- **Self-contained Android permissions** — the plugin drives the Health Connect permission flow itself; no host `Activity` wiring needed.

## Platform support

| | iOS | Android |
|---|---|---|
| Backend | HealthKit | Health Connect |
| Min version | iOS 13 (sleep stages need iOS 16+) | API 26, Health Connect installed |

## Install

```yaml
dependencies:
  health_kit_wrapper: ^1.0.0
```

## Required setup

### iOS

1. Add the HealthKit usage descriptions to `ios/Runner/Info.plist`:

   ```xml
   <key>NSHealthShareUsageDescription</key>
   <string>Reads your health data to show fitness and wellness trends.</string>
   <key>NSHealthUpdateUsageDescription</key>
   <string>Writes health data to keep your records in sync.</string>
   ```

2. Enable the **HealthKit** capability for the Runner target in Xcode (Signing &
   Capabilities → + Capability → HealthKit). This creates / updates
   `Runner.entitlements`. Enable **background delivery** there if you use observers.

See `example/ios/` for a working configuration.

### Android

Nothing required. The plugin's manifest contributes the Health Connect permissions,
the `<queries>` entry, and the permission-rationale activity via manifest merging.
Your launcher `Activity` can be a plain `FlutterActivity`.

- Health Connect requires `minSdkVersion >= 26`.
- To **drop** permissions for data types you do not use, override them in your app
  manifest with `tools:node="remove"`.

## Quick start

```dart
import 'package:health_kit_wrapper/health_kit_wrapper.dart';

// 1. Check availability (Android may need Health Connect installed).
final status = await HealthKitWrapper.getSdkStatus();
if (status == SdkStatus.notInstalled) {
  await HealthKitWrapper.installHealthConnect();
}

// 2. Request permissions.
const types = [RecordType.steps, RecordType.sleep, RecordType.heartRate];
final granted = await HealthKitWrapper.requestPermissions(readTypes: types);

// 3. Read aggregated activity for the last day.
final activity = await HealthKitWrapper.aggregateActivity(
  from: DateTime.now().subtract(const Duration(days: 1)),
  to:   DateTime.now(),
);
print('Steps: ${activity.steps}, active kcal: ${activity.activeKcal}');

// 4. Observe live changes.
final sub = HealthKitWrapper.observerQuery(
  types: [RecordType.steps],
  onUpdate: (update) => print('changed: ${update.changedTypes}'),
);
// ... later: await sub.cancel();
```

## Cross-platform caveats

- **HRV** — Android returns RMSSD (`HrvSample.rmssdMs`), iOS returns SDNN
  (`HrvSample.sdnnMs`). Different metrics; not directly comparable. Use
  `HrvSample.valueMs` for whichever is available.
- **iOS read authorization is opaque** — HealthKit never reveals read-permission
  status, so `hasPermissions` reliably reflects only *write* types on iOS and is
  optimistic for read-only types.
- **Observers** — iOS is push-based (`intervalMs` ignored); Android polls at
  `intervalMs`. Same Dart interface.
- **Sleep stages** — iOS 16+ provides deep / REM / core / awake; earlier iOS only
  asleep / awake; Android provides full stage breakdown.

## Example

A full demo app (dashboard, analytics scoring, reminders) lives in [`example/`](example/).

## License

MIT — see [LICENSE](LICENSE).
