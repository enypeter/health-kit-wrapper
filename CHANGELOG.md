## 1.0.1

- Add iOS Swift Package Manager support (`Package.swift`); the plugin now builds
  under both SPM and CocoaPods.
- Fix the Flutter SDK constraint to `>=3.41.0` so it is consistent with the
  Dart `^3.11.1` requirement.
- Shorten the package description to satisfy pub.dev's length limit.

## 1.0.0

Initial release.

- Unified Dart API (`HealthKitWrapper`) over iOS HealthKit and Android Health Connect.
- Permissions: request, check, list granted, revoke; SDK status; open/install the
  platform health app; device-based companion-app suggestions (Android).
- Aggregate reads: activity, steps, calories (active/total/basal), distance, floors.
- Sample reads across 26 record types: sleep (with stage breakdown), heart rate,
  resting heart rate, HRV, SpO2, blood pressure, blood glucose, respiratory rate,
  VO2 max, body temperature, weight, height, body fat, lean body mass, exercise
  sessions, nutrition, and hydration.
- Live change observation via a single `Stream` interface (push-based `HKObserverQuery`
  on iOS, polling `ChangesToken` on Android).
- Self-contained Android permission flow — no host `Activity` changes required.
