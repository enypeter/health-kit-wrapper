# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Unified Flutter **plugin** for **iOS (HealthKit)** and **Android (Health Connect)**, publishable to pub.dev. Single Dart API (`HealthKitWrapper`) that routes to native Swift or Kotlin via platform channels.

This repo is now a **plugin package** (root `lib/` is the thin API) plus an **example app** (`example/`) that contains the full analytics dashboard, wellness scoring, exercise recommendations, in-app reminders, and `UserProfile`.

## Build & Development Commands

```bash
# Plugin package (run from repo root)
flutter analyze              # Lint — must pass with zero issues
flutter test                 # Run model/API tests (channel-mocked, no native needed)
dart pub publish --dry-run   # Validate plugin layout + metadata before publishing

# Example app (run from example/)
cd example
flutter run                  # Run on connected device/emulator
flutter build apk            # Build Android APK
flutter build ios            # Build iOS (Xcode + HealthKit capability)
```

## Architecture

Three-handler pattern over unified platform channels:

| Channel | Type | iOS (Swift) | Android (Kotlin) |
|---------|------|-------------|-----------------|
| `com.healthkitwrapper/manager` | MethodChannel | `HealthKitManager` — HKHealthStore auth | `HealthConnectManager` — HC permissions |
| `com.healthkitwrapper/reader` | MethodChannel | `HealthKitReader` — HKStatisticsQuery/HKSampleQuery | `HealthConnectReader` — aggregate/readRecords |
| `com.healthkitwrapper/observer` | EventChannel | `HealthKitObserver` — push via HKObserverQuery | `HealthConnectObserver` — polling via ChangesToken |

**Plugin Dart layer (thin — published):**
- `lib/health_kit_wrapper.dart` — Single static `HealthKitWrapper` API (re-exports all models)
- `lib/types/` — RecordType enum (26 health data types), SdkStatus enum
- `lib/models/` — activity, sleep, vitals, body, exercise, nutrition, observer_update

**Example app Dart layer (`example/lib/`):**
- `services/health_analytics.dart` — Scoring engine (sleep score, recovery score, BMI, calorie trends, hydration, macros, exercise suggestions)
- `services/reminder_service.dart` — In-app reminders (water 3x/day, exercise afternoon, night wind-down)
- `screens/` — home, analytics, sleep, body, exercise, profile, setup_guide
- `models/user_profile.dart` — `shared_preferences`-backed profile
- `main.dart` — App entry with bottom navigation shell (Home | Analytics | Body | Exercise | Profile)

**iOS layer** (`ios/Classes/`): `HealthKitWrapperPlugin.swift` (FlutterPlugin registrant), HealthKitManager.swift, HealthKitReader.swift, HealthKitObserver.swift. Podspec: `ios/health_kit_wrapper.podspec` (links `HealthKit`). The host app needs no plugin code — the plugin self-registers.

**Android layer** (`android/src/main/kotlin/com/healthconnectreporter/`): HealthConnectReporterPlugin.kt (+ `manager/`, `reader/`, `observer/` subpackages), PermissionsRationaleActivity.kt. Library `android/build.gradle`; permissions/queries/rationale activity in `android/src/main/AndroidManifest.xml` (merged into consumers). **Permissions are self-contained**: the plugin launches the Health Connect contract via `startActivityForResult` + an `ActivityResultListener` on the `ActivityPluginBinding` — no host `Activity` wiring or `FlutterFragmentActivity` required.

## Key Design Decisions

- **Both platforms return identical Map shapes** — same keys, same units → same Dart model constructors
- **Calories always in kilocalories** — never raw calories (`.inKilocalories` on Android, `HKUnit.kilocalorie()` on iOS)
- **HRV:** Android returns RMSSD (ms) in `rmssdMs`, iOS returns SDNN (ms) in `sdnnMs` — `HrvSample.valueMs` gives whichever is available; not directly comparable across platforms
- **Observer:** iOS is push-based (HKObserverQuery), Android is polling-based (ChangesToken) — same Dart interface
- **Sleep stages:** iOS 16+ provides deep/REM/core/awake; pre-iOS 16 only asleep/awake; Android provides full stage breakdown
- **Blood pressure:** iOS uses HKCorrelation with systolic+diastolic pair; Android uses single BloodPressureRecord — normalized to same Map
- **Aggregates preferred over manual sample summation** — both platforms deduplicate
- **Exercise types:** Both platforms return normalized human-readable strings (`"running"`, `"cycling"`, `"walking"`) instead of raw enum values
- **Nutrition on iOS:** Queries all macro types separately (dietaryProtein, dietaryFatTotal, etc.) and groups by timestamp to match Android's single NutritionRecord shape
- **Total calories on iOS:** No single HK type exists — permission request fetches both activeEnergyBurned + basalEnergyBurned; aggregates compute the sum
- **HC not installed:** Android falls back to Play Store redirect; device manufacturer detection suggests compatible companion health app (Samsung Health, Google Fit, Huawei Health, etc.)

## Analytics & Scoring

`HealthAnalytics` in `example/lib/services/health_analytics.dart` computes all scores from raw health data:

| Score | Range | Components | Data Required |
|-------|-------|------------|---------------|
| Sleep Score | 0–100 | Duration (25), Efficiency (25), Deep % (20), REM % (20), Awake penalty (10) | SleepSession with stage breakdown |
| Recovery Score | 0–100 | HRV vs 7-day avg (30), Resting HR vs avg (25), Sleep quality (25), Activity load (20) | HRV, resting HR, sleep, activity history |
| BMI | computed | weight_kg / height_m² | Weight + height samples |
| Hydration Score | 0–100 | actual_intake / (weight_kg × 0.033 + exercise_adjustment) | Hydration records, weight, exercise sessions |
| Macro Balance | percentages | (macro_g × kcal_per_g) / total_kcal | Nutrition records |

Exercise suggestions are derived from recovery score (determines intensity), step average (movement needs), workout history (cross-training gaps), BMI (fat loss support), and flexibility gaps.

## Reminders

`ReminderService` in `example/lib/services/reminder_service.dart` — timer-based in-app reminders:

- **Water**: 3x/day during waking hours (8 AM–9 PM), every 2 hours
- **Exercise**: Afternoon (2–6 PM) if no exercise logged today — suggests squats, walks, stretches
- **Night**: Evening (8–10 PM) if no exercise — suggests gentle yoga, evening walk before sleep

Reminders display as modal bottom sheets via the `MainShell` listener in `main.dart`. No platform notification permissions required.

## Screens & Navigation

Bottom navigation with 4 tabs (`MainShell` in `main.dart`):

| Tab | Screen | Key Features |
|-----|--------|-------------|
| Home | `home_screen.dart` | Day-by-day activity, sleep, vitals, live observer |
| Analytics | `analytics_screen.dart` | Score rings (sleep/recovery/BMI), hydration bar, 7-day calorie chart, vitals grid |
| Body | `body_screen.dart` | BMI gauge + scale, body fat gauge, weight trend line, macro balance bar, hydration glasses |
| Exercise | `exercise_screen.dart` | Recovery hero + advice, recovery breakdown, suggested workouts, recent workout history |
| Profile | `profile_screen.dart` | Edit name, age, gender, weight, height, weight goal, daily step/calorie/water targets |

Additional screens: `sleep_screen.dart` (detailed sleep analysis, stage distribution, 7-night trend, tips), `setup_guide_screen.dart` (platform-specific setup instructions).

## User Profile

`UserProfile` in `example/lib/models/user_profile.dart` — persisted via `shared_preferences`:

- **Personal**: name, age, gender
- **Body**: weight (kg), height (cm) — auto-populated from health data if available
- **Goals**: weight goal (kg), daily steps, daily calories (kcal), daily water (liters)
- **Computed**: BMI, weight delta to goal

Profile data is used by `HealthAnalytics.computeBmi()` and `computeHydration()` as fallback when no health platform samples exist, and to personalize targets.

## Platform Requirements

- **Android:** min SDK 26, compile SDK 36, Java 17, Health Connect SDK `1.1.0-alpha10`
- **iOS:** HealthKit framework (no third-party pods), entitlements in `Runner.entitlements`
- **Dart:** SDK >= 3.11.1

## iOS Configuration Notes

- `Info.plist` must have `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`
- `Runner.entitlements` enables HealthKit capability + background delivery
- HealthKit does NOT reveal read authorization status (always `.notDetermined`) — `hasPermissions()` only reliably checks write types on iOS

## Android Configuration Notes

- `AndroidManifest.xml` declares all Health Connect read/write permissions
- `PermissionsRationaleActivity` shows health data rationale UI (required by Play Store review)
- `installHealthConnect` opens Play Store if HC not installed; `getDeviceInfo` returns manufacturer/brand/model for companion app suggestions
- Package query for `com.google.android.apps.healthdata` in manifest queries

## Test Structure

- `test/types_test.dart` — Enum serialization roundtrips
- `test/models_test.dart` — All model `fromMap()` constructors with realistic platform data
- `test/health_kit_wrapper_test.dart` — API layer with mocked MethodChannel/EventChannel
