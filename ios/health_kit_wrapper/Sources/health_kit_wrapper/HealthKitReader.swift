import Flutter
import HealthKit

/// Reads health data from HealthKit and returns Maps in the same shape
/// as the Android HealthConnectReader — same keys, same units.
class HealthKitReader: NSObject {

    private let store: HKHealthStore
    init(store: HKHealthStore) {
        self.store = store
        super.init()
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "arguments must be a map", details: nil))
            return
        }

        // Flutter sends Dart int as NSNumber — cast via NSNumber to Double
        guard let startRaw = args["startTimestamp"],
              let endRaw = args["endTimestamp"] else {
            result(FlutterError(code: "INVALID_ARGS", message: "startTimestamp and endTimestamp required", details: nil))
            return
        }

        let startTimestamp: Double
        let endTimestamp: Double

        if let n = startRaw as? NSNumber {
            startTimestamp = n.doubleValue
        } else if let d = startRaw as? Double {
            startTimestamp = d
        } else if let i = startRaw as? Int {
            startTimestamp = Double(i)
        } else {
            result(FlutterError(code: "INVALID_ARGS", message: "startTimestamp has unexpected type: \(type(of: startRaw))", details: nil))
            return
        }

        if let n = endRaw as? NSNumber {
            endTimestamp = n.doubleValue
        } else if let d = endRaw as? Double {
            endTimestamp = d
        } else if let i = endRaw as? Int {
            endTimestamp = Double(i)
        } else {
            result(FlutterError(code: "INVALID_ARGS", message: "endTimestamp has unexpected type: \(type(of: endRaw))", details: nil))
            return
        }

        let from = Date(timeIntervalSince1970: startTimestamp / 1000.0)
        let to = Date(timeIntervalSince1970: endTimestamp / 1000.0)

        let predicate = HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)

        switch call.method {
        // Aggregate queries
        case "aggregateActivity":
            aggregateActivity(from: from, to: to, predicate: predicate, result: result)
        case "aggregateSteps":
            aggregateQuantity(identifier: .stepCount, unit: HKUnit.count(), key: "total", predicate: predicate, result: result)
        case "aggregateCalories":
            aggregateCalories(predicate: predicate, result: result)
        case "aggregateDistance":
            aggregateQuantity(identifier: .distanceWalkingRunning, unit: HKUnit.meter(), key: "meters", predicate: predicate, result: result)
        case "aggregateFloors":
            aggregateQuantity(identifier: .flightsClimbed, unit: HKUnit.count(), key: "total", predicate: predicate, result: result)

        // Sample queries
        case "readSteps":
            readSteps(predicate: predicate, result: result)
        case "readSleep":
            readSleep(predicate: predicate, result: result)
        case "readHeartRate":
            readHeartRate(predicate: predicate, result: result)
        case "readRestingHeartRate":
            readQuantitySamples(identifier: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), key: "bpm", predicate: predicate, result: result)
        case "readHeartRateVariability":
            readHrv(predicate: predicate, result: result)
        case "readOxygenSaturation":
            readOxygenSaturation(predicate: predicate, result: result)
        case "readBloodPressure":
            readBloodPressure(predicate: predicate, result: result)
        case "readBloodGlucose":
            readBloodGlucose(predicate: predicate, result: result)
        case "readRespiratoryRate":
            readQuantitySamples(identifier: .respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), key: "rate", predicate: predicate, result: result)
        case "readVo2Max":
            readVo2Max(predicate: predicate, result: result)
        case "readBodyTemperature":
            readBodyTemperature(predicate: predicate, result: result)
        case "readWeight":
            readWeight(predicate: predicate, result: result)
        case "readHeight":
            readHeight(predicate: predicate, result: result)
        case "readBodyFat":
            readBodyFat(predicate: predicate, result: result)
        case "readLeanBodyMass":
            readLeanBodyMass(predicate: predicate, result: result)
        case "readExerciseSessions":
            readExerciseSessions(predicate: predicate, result: result)
        case "readNutrition":
            readNutrition(predicate: predicate, result: result)
        case "readHydration":
            readHydration(predicate: predicate, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Aggregate Queries

    private func aggregateActivity(from: Date, to: Date, predicate: NSPredicate, result: @escaping FlutterResult) {
        let group = DispatchGroup()
        var steps: Double = 0
        var distance: Double = 0
        var floors: Double = 0
        var activeKcal: Double = 0
        var basalKcal: Double = 0
        var origins = Set<String>()

        let queries: [(HKQuantityTypeIdentifier, HKUnit)] = [
            (.stepCount, HKUnit.count()),
            (.distanceWalkingRunning, HKUnit.meter()),
            (.flightsClimbed, HKUnit.count()),
            (.activeEnergyBurned, HKUnit.kilocalorie()),
            (.basalEnergyBurned, HKUnit.kilocalorie()),
        ]

        for (identifier, unit) in queries {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            group.enter()

            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                defer { group.leave() }
                guard let sum = statistics?.sumQuantity() else { return }
                let value = sum.doubleValue(for: unit)

                if let sources = statistics?.sources {
                    for source in sources {
                        origins.insert(source.bundleIdentifier)
                    }
                }

                switch identifier {
                case .stepCount: steps = value
                case .distanceWalkingRunning: distance = value
                case .flightsClimbed: floors = value
                case .activeEnergyBurned: activeKcal = value
                case .basalEnergyBurned: basalKcal = value
                default: break
                }
            }
            store.execute(query)
        }

        group.notify(queue: .main) {
            // totalKcal = active + basal (matching Android behavior)
            let computedTotal = activeKcal + basalKcal
            result([
                "steps": Int(steps),
                "distanceM": distance,
                "floors": floors,
                "activeKcal": activeKcal,
                "totalKcal": computedTotal,
                "dataOrigins": Array(origins),
            ] as [String: Any])
        }
    }

    private func aggregateCalories(predicate: NSPredicate, result: @escaping FlutterResult) {
        let group = DispatchGroup()
        var activeKcal: Double = 0
        var basalKcal: Double = 0
        var origins = Set<String>()

        let queries: [(HKQuantityTypeIdentifier, String)] = [
            (.activeEnergyBurned, "active"),
            (.basalEnergyBurned, "basal"),
        ]

        for (identifier, label) in queries {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            group.enter()

            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                defer { group.leave() }
                guard let sum = statistics?.sumQuantity() else { return }
                let value = sum.doubleValue(for: HKUnit.kilocalorie())
                if let sources = statistics?.sources {
                    for source in sources { origins.insert(source.bundleIdentifier) }
                }
                if label == "active" { activeKcal = value }
                else { basalKcal = value }
            }
            store.execute(query)
        }

        group.notify(queue: .main) {
            result([
                "activeKcal": activeKcal,
                "totalKcal": activeKcal + basalKcal,
                "basalKcal": basalKcal,
                "dataOrigins": Array(origins),
            ] as [String: Any])
        }
    }

    private func aggregateQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        key: String,
        predicate: NSPredicate,
        result: @escaping FlutterResult
    ) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            result([key: 0, "dataOrigins": []] as [String: Any])
            return
        }

        let query = HKStatisticsQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, statistics, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "AGGREGATE_ERROR", message: error.localizedDescription, details: nil))
                    return
                }
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                let origins = statistics?.sources?.map { $0.bundleIdentifier } ?? []
                result([key: value, "dataOrigins": origins] as [String: Any])
            }
        }
        store.execute(query)
    }

    // MARK: - Sample Queries

    private func readSteps(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            result([] as [[String: Any]])
            return
        }

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, error in
            DispatchQueue.main.async {
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = quantitySamples.map { s -> [String: Any] in
                    [
                        "count": Int(s.quantity.doubleValue(for: HKUnit.count())),
                        "startMs": Int64(s.startDate.timeIntervalSince1970 * 1000),
                        "endMs": Int64(s.endDate.timeIntervalSince1970 * 1000),
                        "zoneOffset": TimeZone.current.secondsFromGMT(),
                        "source": s.sourceRevision.source.bundleIdentifier,
                        "device": s.device?.model ?? "",
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    private func readSleep(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let sampleType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            result([] as [[String: Any]])
            return
        }

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let categorySamples = samples as? [HKCategorySample] else {
                    result([] as [[String: Any]])
                    return
                }

                // Group sleep samples into sessions.
                // iOS 16+ has HKCategoryValueSleepAnalysis with stages.
                // Pre-iOS 16 only has inBed/asleep.
                let sessions = self.groupSleepSessions(categorySamples)
                result(sessions)
            }
        }
        store.execute(query)
    }

    private func groupSleepSessions(_ samples: [HKCategorySample]) -> [[String: Any]] {
        if samples.isEmpty { return [] }

        // Group by source + overlapping/adjacent time windows into sessions
        var sessions = [[String: Any]]()

        // Simple grouping: treat each "inBed" sample as a session boundary,
        // or group all samples within 30 min gaps as one session
        var currentSession = [HKCategorySample]()
        var lastEnd: Date?

        for sample in samples {
            if let last = lastEnd, sample.startDate.timeIntervalSince(last) > 1800 {
                // Gap > 30 min — new session
                if !currentSession.isEmpty {
                    sessions.append(buildSleepSession(currentSession))
                }
                currentSession = [sample]
            } else {
                currentSession.append(sample)
            }
            lastEnd = sample.endDate
        }
        if !currentSession.isEmpty {
            sessions.append(buildSleepSession(currentSession))
        }

        return sessions
    }

    private func buildSleepSession(_ samples: [HKCategorySample]) -> [String: Any] {
        guard let first = samples.first, let last = samples.last else {
            return [:]
        }

        let sessionStart = samples.map { $0.startDate }.min() ?? first.startDate
        let sessionEnd = samples.map { $0.endDate }.max() ?? last.endDate
        let durationMinutes = Int(sessionEnd.timeIntervalSince(sessionStart) / 60)

        var stages = [[String: Any]]()
        var deepMins = 0, remMins = 0, lightMins = 0, awakeMins = 0, asleepMins = 0

        for sample in samples {
            let stageName: String
            let mins = Int(sample.endDate.timeIntervalSince(sample.startDate) / 60)

            if #available(iOS 16.0, *) {
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    stageName = "deep"; deepMins += mins
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    stageName = "rem"; remMins += mins
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    stageName = "light"; lightMins += mins
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    stageName = "awake"; awakeMins += mins
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    stageName = "asleep"; asleepMins += mins
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    stageName = "awake"; awakeMins += mins
                default:
                    stageName = "unknown"
                }
            } else {
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleep.rawValue:
                    stageName = "asleep"; asleepMins += mins
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    stageName = "awake"; awakeMins += mins
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    stageName = "awake"; awakeMins += mins
                default:
                    stageName = "unknown"
                }
            }

            stages.append([
                "stage": stageName,
                "startMs": Int64(sample.startDate.timeIntervalSince1970 * 1000),
                "endMs": Int64(sample.endDate.timeIntervalSince1970 * 1000),
                "durationMinutes": mins,
            ] as [String: Any])
        }

        return [
            "startMs": Int64(sessionStart.timeIntervalSince1970 * 1000),
            "endMs": Int64(sessionEnd.timeIntervalSince1970 * 1000),
            "durationMinutes": durationMinutes,
            "title": "",
            "notes": "",
            "source": first.sourceRevision.source.bundleIdentifier,
            "device": first.device?.model ?? "",
            "stages": stages,
            "breakdown": [
                "deepMinutes": deepMins,
                "remMinutes": remMins,
                "lightMinutes": lightMins,
                "awakeMinutes": awakeMins,
                "asleepMinutes": asleepMins,
            ] as [String: Any],
        ] as [String: Any]
    }

    private func readHeartRate(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            result([] as [[String: Any]])
            return
        }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = quantitySamples.map { s -> [String: Any] in
                    [
                        "bpm": Int(s.quantity.doubleValue(for: unit)),
                        "timeMs": Int64(s.startDate.timeIntervalSince1970 * 1000),
                        "source": s.sourceRevision.source.bundleIdentifier,
                        "device": s.device?.model ?? "",
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    private func readHrv(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            result([] as [[String: Any]])
            return
        }

        let unit = HKUnit.secondUnit(with: .milli)
        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = quantitySamples.map { s -> [String: Any] in
                    [
                        "sdnnMs": s.quantity.doubleValue(for: unit),
                        "timeMs": Int64(s.startDate.timeIntervalSince1970 * 1000),
                        "source": s.sourceRevision.source.bundleIdentifier,
                        "device": s.device?.model ?? "",
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    private func readOxygenSaturation(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            result([] as [[String: Any]])
            return
        }

        let unit = HKUnit.percent()
        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = quantitySamples.map { s -> [String: Any] in
                    [
                        "percentage": s.quantity.doubleValue(for: unit) * 100,
                        "timeMs": Int64(s.startDate.timeIntervalSince1970 * 1000),
                        "source": s.sourceRevision.source.bundleIdentifier,
                        "device": s.device?.model ?? "",
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    private func readBloodPressure(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let correlationType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) else {
            result([] as [[String: Any]])
            return
        }

        let mmHg = HKUnit.millimeterOfMercury()
        let query = HKSampleQuery(
            sampleType: correlationType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let correlations = samples as? [HKCorrelation] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = correlations.compactMap { c -> [String: Any]? in
                    let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!
                    let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!

                    guard let systolic = c.objects(for: systolicType).first as? HKQuantitySample,
                          let diastolic = c.objects(for: diastolicType).first as? HKQuantitySample else {
                        return nil
                    }

                    return [
                        "systolicMmhg": systolic.quantity.doubleValue(for: mmHg),
                        "diastolicMmhg": diastolic.quantity.doubleValue(for: mmHg),
                        "bodyPosition": "",
                        "measurementLoc": "",
                        "timeMs": Int64(c.startDate.timeIntervalSince1970 * 1000),
                        "source": c.sourceRevision.source.bundleIdentifier,
                        "device": c.device?.model ?? "",
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    private func readBloodGlucose(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else {
            result([] as [[String: Any]])
            return
        }

        let mmolPerL = HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter())
        let mgPerDl = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = quantitySamples.map { s -> [String: Any] in
                    [
                        "mmolPerL": s.quantity.doubleValue(for: mmolPerL),
                        "mgPerDl": s.quantity.doubleValue(for: mgPerDl),
                        "mealType": "",
                        "specimenSource": "",
                        "relationToMeal": "",
                        "timeMs": Int64(s.startDate.timeIntervalSince1970 * 1000),
                        "source": s.sourceRevision.source.bundleIdentifier,
                        "device": s.device?.model ?? "",
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    private func readVo2Max(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
            result([] as [[String: Any]])
            return
        }

        let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = quantitySamples.map { s -> [String: Any] in
                    [
                        "vo2Max": s.quantity.doubleValue(for: unit),
                        "measurementMethod": "",
                        "timeMs": Int64(s.startDate.timeIntervalSince1970 * 1000),
                        "source": s.sourceRevision.source.bundleIdentifier,
                        "device": s.device?.model ?? "",
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    private func readBodyTemperature(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) else {
            result([] as [[String: Any]])
            return
        }

        let unit = HKUnit.degreeCelsius()
        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = quantitySamples.map { s -> [String: Any] in
                    [
                        "celsius": s.quantity.doubleValue(for: unit),
                        "measurementLoc": "",
                        "timeMs": Int64(s.startDate.timeIntervalSince1970 * 1000),
                        "source": s.sourceRevision.source.bundleIdentifier,
                        "device": s.device?.model ?? "",
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    private func readWeight(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            result([] as [[String: Any]])
            return
        }

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = quantitySamples.map { s -> [String: Any] in
                    [
                        "kg": s.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)),
                        "lbs": s.quantity.doubleValue(for: HKUnit.pound()),
                        "timeMs": Int64(s.startDate.timeIntervalSince1970 * 1000),
                        "source": s.sourceRevision.source.bundleIdentifier,
                        "device": s.device?.model ?? "",
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    private func readHeight(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: .height) else {
            result([] as [[String: Any]])
            return
        }

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = quantitySamples.map { s -> [String: Any] in
                    let meters = s.quantity.doubleValue(for: HKUnit.meter())
                    return [
                        "meters": meters,
                        "cm": meters * 100,
                        "timeMs": Int64(s.startDate.timeIntervalSince1970 * 1000),
                        "source": s.sourceRevision.source.bundleIdentifier,
                        "device": s.device?.model ?? "",
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    private func readBodyFat(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
            result([] as [[String: Any]])
            return
        }

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = quantitySamples.map { s -> [String: Any] in
                    [
                        "percentage": s.quantity.doubleValue(for: HKUnit.percent()) * 100,
                        "timeMs": Int64(s.startDate.timeIntervalSince1970 * 1000),
                        "source": s.sourceRevision.source.bundleIdentifier,
                        "device": s.device?.model ?? "",
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    private func readLeanBodyMass(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) else {
            result([] as [[String: Any]])
            return
        }

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = quantitySamples.map { s -> [String: Any] in
                    [
                        "kg": s.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)),
                        "timeMs": Int64(s.startDate.timeIntervalSince1970 * 1000),
                        "source": s.sourceRevision.source.bundleIdentifier,
                        "device": s.device?.model ?? "",
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    private func readExerciseSessions(predicate: NSPredicate, result: @escaping FlutterResult) {
        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let workouts = samples as? [HKWorkout] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = workouts.map { w -> [String: Any] in
                    [
                        "exerciseType": self.exerciseTypeString(w.workoutActivityType),
                        "title": "",
                        "notes": "",
                        "startMs": Int64(w.startDate.timeIntervalSince1970 * 1000),
                        "endMs": Int64(w.endDate.timeIntervalSince1970 * 1000),
                        "durationMinutes": Int(w.duration / 60),
                        "source": w.sourceRevision.source.bundleIdentifier,
                        "device": w.device?.model ?? "",
                        "laps": [] as [[String: Any]],
                        "segments": [] as [[String: Any]],
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    private func readNutrition(predicate: NSPredicate, result: @escaping FlutterResult) {
        // iOS stores each macro as a separate HKQuantitySample.
        // Query all nutrition types and group by (startDate, endDate, source)
        // to reconstruct records matching Android's NutritionRecord shape.
        let nutritionTypes: [(HKQuantityTypeIdentifier, HKUnit, String)] = [
            (.dietaryEnergyConsumed, HKUnit.kilocalorie(), "energyKcal"),
            (.dietaryProtein, HKUnit.gram(), "proteinG"),
            (.dietaryFatTotal, HKUnit.gram(), "fatG"),
            (.dietaryCarbohydrates, HKUnit.gram(), "carbohydratesG"),
            (.dietaryFiber, HKUnit.gram(), "fiberG"),
            (.dietarySugar, HKUnit.gram(), "sugarG"),
            (.dietarySodium, HKUnit.gramUnit(with: .milli), "sodiumMg"),
        ]

        let group = DispatchGroup()

        // Key: "startMs|endMs|source" → nutrient values
        let lock = NSLock()
        var grouped = [String: [String: Any]]()

        for (identifier, unit, key) in nutritionTypes {
            guard let sampleType = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            group.enter()

            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                defer { group.leave() }
                guard let quantitySamples = samples as? [HKQuantitySample] else { return }
                lock.lock()
                for s in quantitySamples {
                    let startMs = Int64(s.startDate.timeIntervalSince1970 * 1000)
                    let endMs = Int64(s.endDate.timeIntervalSince1970 * 1000)
                    let source = s.sourceRevision.source.bundleIdentifier
                    let groupKey = "\(startMs)|\(endMs)|\(source)"

                    if grouped[groupKey] == nil {
                        grouped[groupKey] = [
                            "name": "",
                            "mealType": "",
                            "energyKcal": 0.0,
                            "proteinG": 0.0,
                            "carbohydratesG": 0.0,
                            "fatG": 0.0,
                            "fiberG": 0.0,
                            "sugarG": 0.0,
                            "sodiumMg": 0.0,
                            "startMs": startMs,
                            "endMs": endMs,
                            "source": source,
                        ] as [String: Any]
                    }
                    grouped[groupKey]![key] = s.quantity.doubleValue(for: unit)
                }
                lock.unlock()
            }
            store.execute(query)
        }

        group.notify(queue: .main) {
            let records = grouped.values.sorted {
                ($0["startMs"] as? Int64 ?? 0) < ($1["startMs"] as? Int64 ?? 0)
            }
            result(records)
        }
    }

    private func readHydration(predicate: NSPredicate, result: @escaping FlutterResult) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            result([] as [[String: Any]])
            return
        }

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = quantitySamples.map { s -> [String: Any] in
                    let liters = s.quantity.doubleValue(for: HKUnit.liter())
                    return [
                        "volumeLiters": liters,
                        "volumeMl": liters * 1000,
                        "startMs": Int64(s.startDate.timeIntervalSince1970 * 1000),
                        "endMs": Int64(s.endDate.timeIntervalSince1970 * 1000),
                        "source": s.sourceRevision.source.bundleIdentifier,
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    // MARK: - Generic quantity sample reader (for simple types)

    private func readQuantitySamples(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        key: String,
        predicate: NSPredicate,
        result: @escaping FlutterResult
    ) {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            result([] as [[String: Any]])
            return
        }

        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, _ in
            DispatchQueue.main.async {
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    result([] as [[String: Any]])
                    return
                }
                let mapped = quantitySamples.map { s -> [String: Any] in
                    [
                        key: s.quantity.doubleValue(for: unit),
                        "timeMs": Int64(s.startDate.timeIntervalSince1970 * 1000),
                        "source": s.sourceRevision.source.bundleIdentifier,
                        "device": s.device?.model ?? "",
                    ]
                }
                result(mapped)
            }
        }
        store.execute(query)
    }

    // MARK: - Exercise Type Mapping

    private func exerciseTypeString(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:                  return "running"
        case .walking:                  return "walking"
        case .cycling:                  return "cycling"
        case .swimming:                 return "swimming"
        case .hiking:                   return "hiking"
        case .yoga:                     return "yoga"
        case .dance:                    return "dancing"
        case .elliptical:               return "elliptical"
        case .rowing:                   return "rowing"
        case .stairClimbing:            return "stair_climbing"
        case .functionalStrengthTraining: return "strength_training"
        case .traditionalStrengthTraining: return "weightlifting"
        case .coreTraining:             return "calisthenics"
        case .highIntensityIntervalTraining: return "high_intensity_interval_training"
        case .jumpRope:                 return "jump_rope"
        case .pilates:                  return "pilates"
        case .boxing:                   return "boxing"
        case .kickboxing:               return "martial_arts"
        case .martialArts:              return "martial_arts"
        case .tennis:                   return "tennis"
        case .badminton:                return "badminton"
        case .golf:                     return "golf"
        case .soccer:                   return "soccer"
        case .americanFootball:         return "american_football"
        case .basketball:               return "basketball"
        case .volleyball:               return "volleyball"
        case .baseball:                 return "baseball"
        case .softball:                 return "softball"
        case .rugby:                    return "rugby"
        case .hockey:                   return "ice_hockey"
        case .tableTennis:              return "table_tennis"
        case .racquetball:              return "racquetball"
        case .squash:                   return "squash"
        case .skatingSports:            return "skating"
        case .crossTraining:            return "cross_training"
        case .surfingSports:            return "surfing"
        case .snowSports:               return "skiing"
        case .waterFitness:             return "water_fitness"
        case .waterPolo:                return "water_polo"
        case .wheelchairWalkPace:       return "wheelchair"
        case .wheelchairRunPace:        return "wheelchair"
        case .other:                    return "other"
        default:                        return "other"
        }
    }
}
