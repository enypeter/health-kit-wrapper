import Flutter
import HealthKit

/// Handles authorization, permission checks, and SDK status for HealthKit.
///
/// Method names match the Android HealthConnectManager exactly so the
/// Dart API can be platform-agnostic.
class HealthKitManager: NSObject {

    private let store: HKHealthStore

    private static let authRequestedKey = "com.healthkitwrapper.authRequested"

    init(store: HKHealthStore) {
        self.store = store
        super.init()
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getSdkStatus":
            getSdkStatus(result: result)
        case "requestPermissions":
            requestPermissions(call: call, result: result)
        case "hasPermissions":
            hasPermissions(call: call, result: result)
        case "getGrantedPermissions":
            getGrantedPermissions(result: result)
        case "revokeAllPermissions":
            revokeAllPermissions(result: result)
        case "openHealthApp":
            openHealthApp(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - SDK Status

    private func getSdkStatus(result: @escaping FlutterResult) {
        if HKHealthStore.isHealthDataAvailable() {
            result("available")
        } else {
            result("unavailable")
        }
    }

    // MARK: - Request Permissions

    private func requestPermissions(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let readTypes = args["readTypes"] as? [String],
              let writeTypes = args["writeTypes"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGS", message: "readTypes and writeTypes required", details: nil))
            return
        }

        var readSet = Set<HKObjectType>()
        for typeName in readTypes {
            // Blood pressure: HealthKit forbids requesting read auth for the
            // correlation type — must request the underlying quantity types instead.
            if typeName == "bloodPressure" {
                if let systolic = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) {
                    readSet.insert(systolic)
                }
                if let diastolic = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) {
                    readSet.insert(diastolic)
                }
            } else if typeName == "totalCalories" {
                // iOS has no single "total calories" type — it's active + basal.
                // Request both so aggregate queries can compute the sum.
                if let active = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                    readSet.insert(active)
                }
                if let basal = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
                    readSet.insert(basal)
                }
            } else if typeName == "nutrition" {
                // iOS stores each macro as a separate quantity type.
                let nutritionTypes: [HKQuantityTypeIdentifier] = [
                    .dietaryEnergyConsumed, .dietaryProtein, .dietaryFatTotal,
                    .dietaryCarbohydrates, .dietaryFiber, .dietarySugar, .dietarySodium,
                ]
                for id in nutritionTypes {
                    if let qt = HKQuantityType.quantityType(forIdentifier: id) {
                        readSet.insert(qt)
                    }
                }
            } else if let hkType = hkObjectType(for: typeName) {
                readSet.insert(hkType)
            }
        }

        var writeSet = Set<HKSampleType>()
        for typeName in writeTypes {
            if let hkType = hkSampleType(for: typeName) {
                writeSet.insert(hkType)
            }
        }

        store.requestAuthorization(toShare: writeSet, read: readSet) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "AUTH_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    // Mark that we've shown the auth dialog at least once.
                    // iOS never reveals read-auth status, so we track this
                    // ourselves to avoid re-prompting (it's a no-op after first time).
                    if success {
                        UserDefaults.standard.set(true, forKey: HealthKitManager.authRequestedKey)
                    }
                    result(success)
                }
            }
        }
    }

    // MARK: - Has Permissions

    /// iOS privacy note: HealthKit never reveals whether read access was denied.
    /// authorizationStatus(for:) returns .notDetermined for read types even after
    /// the user denied access. We can only reliably check write authorization.
    ///
    /// Strategy: check write types reliably. For read-only requests, attempt a
    /// small query — if it returns data, we have access. If it returns empty,
    /// we can't distinguish "no data" from "denied". We return true optimistically
    /// after requestAuthorization has been called.
    private func hasPermissions(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // iOS privacy: HealthKit never reveals whether read access was granted.
        // We track whether requestPermissions() has been called at least once.
        // If not, return false to ensure the auth sheet is shown.
        let authRequested = UserDefaults.standard.bool(forKey: HealthKitManager.authRequestedKey)
        if !authRequested {
            result(false)
            return
        }

        guard let args = call.arguments as? [String: Any],
              let writeTypes = args["writeTypes"] as? [String],
              !writeTypes.isEmpty else {
            // Read-only request and auth was already shown — return true
            result(true)
            return
        }

        // Check write authorization (this is reliable on iOS)
        for typeName in writeTypes {
            if let hkType = hkSampleType(for: typeName) {
                let status = store.authorizationStatus(for: hkType)
                if status != .sharingAuthorized {
                    result(false)
                    return
                }
            }
        }

        result(true)
    }

    // MARK: - Get Granted Permissions

    private func getGrantedPermissions(result: @escaping FlutterResult) {
        var granted = [String]()
        for (name, _) in typeMapping {
            if let hkType = hkSampleType(for: name) {
                if store.authorizationStatus(for: hkType) == .sharingAuthorized {
                    granted.append(name)
                }
            }
        }
        result(granted)
    }

    // MARK: - Revoke All

    private func revokeAllPermissions(result: @escaping FlutterResult) {
        // iOS does not support programmatic revocation of HealthKit permissions.
        // Users must do this manually in Settings → Health → Data Access.
        result(false)
    }

    // MARK: - Open Health App

    private func openHealthApp(result: @escaping FlutterResult) {
        if let url = URL(string: "x-apple-health://") {
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:]) { success in
                        result(success)
                    }
                } else {
                    result(false)
                }
            }
        } else {
            result(false)
        }
    }

    // MARK: - Type Mapping

    /// Maps our unified type identifiers to HealthKit types.
    static let typeMapping: [(String, HKObjectType)] = {
        var mapping = [(String, HKObjectType)]()

        // Activity
        mapping.append(("steps", HKQuantityType.quantityType(forIdentifier: .stepCount)!))
        mapping.append(("distance", HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!))
        mapping.append(("floors", HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!))
        mapping.append(("activeCalories", HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!))
        mapping.append(("totalCalories", HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!))
        mapping.append(("exercise", HKObjectType.workoutType()))

        // Sleep
        mapping.append(("sleep", HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!))

        // Vitals
        mapping.append(("heartRate", HKQuantityType.quantityType(forIdentifier: .heartRate)!))
        mapping.append(("restingHeartRate", HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!))
        mapping.append(("heartRateVariability", HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!))
        mapping.append(("oxygenSaturation", HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!))
        mapping.append(("bloodPressure", HKCorrelationType.correlationType(forIdentifier: .bloodPressure)!))
        mapping.append(("bloodGlucose", HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!))
        mapping.append(("respiratoryRate", HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!))
        mapping.append(("vo2Max", HKQuantityType.quantityType(forIdentifier: .vo2Max)!))
        mapping.append(("bodyTemperature", HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!))

        // Body
        mapping.append(("height", HKQuantityType.quantityType(forIdentifier: .height)!))
        mapping.append(("weight", HKQuantityType.quantityType(forIdentifier: .bodyMass)!))
        mapping.append(("bodyFat", HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!))
        mapping.append(("leanBodyMass", HKQuantityType.quantityType(forIdentifier: .leanBodyMass)!))
        mapping.append(("basalMetabolicRate", HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!))

        // Nutrition — energy is the primary type; macros requested via special case
        mapping.append(("nutrition", HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!))
        mapping.append(("hydration", HKQuantityType.quantityType(forIdentifier: .dietaryWater)!))

        return mapping
    }()

    private var typeMapping: [(String, HKObjectType)] {
        return HealthKitManager.typeMapping
    }

    func hkObjectType(for typeName: String) -> HKObjectType? {
        return HealthKitManager.typeMapping.first(where: { $0.0 == typeName })?.1
    }

    func hkSampleType(for typeName: String) -> HKSampleType? {
        return hkObjectType(for: typeName) as? HKSampleType
    }

    func hkQuantityType(for typeName: String) -> HKQuantityType? {
        return hkObjectType(for: typeName) as? HKQuantityType
    }
}
