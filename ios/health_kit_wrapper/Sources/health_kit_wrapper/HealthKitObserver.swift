import Flutter
import HealthKit

/// Push-based health data observer using HKObserverQuery.
///
/// Unlike Android's polling model, iOS HealthKit provides real-time
/// push notifications when health data changes. The intervalMs argument
/// from the Dart side is ignored — updates come immediately.
///
/// Emits the same Map shape as Android's HealthConnectObserver for
/// Dart-side compatibility.
class HealthKitObserver: NSObject, FlutterStreamHandler {

    private let store: HKHealthStore
    private var activeQueries = [String: [HKObserverQuery]]()
    private var eventSink: FlutterEventSink?

    init(store: HKHealthStore) {
        self.store = store
        super.init()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        guard let args = arguments as? [String: Any],
              let types = args["types"] as? [String] else {
            return FlutterError(code: "INVALID_ARGS", message: "types required", details: nil)
        }

        let observerId = args["observerId"] as? String ?? types.joined(separator: ",")

        // Cancel existing queries for this observer
        cancelObserver(observerId)

        var queries = [HKObserverQuery]()

        for typeName in types {
            guard let sampleType = hkSampleType(for: typeName) else { continue }

            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                guard let self = self else {
                    completionHandler()
                    return
                }

                if error != nil {
                    completionHandler()
                    return
                }

                DispatchQueue.main.async {
                    self.eventSink?([
                        "observerId": observerId,
                        "hasChanges": true,
                        "insertedTypes": [typeName],
                        "deletedTypes": [] as [String],
                        "timestampMs": Int64(Date().timeIntervalSince1970 * 1000),
                    ] as [String: Any])
                }

                completionHandler()
            }

            store.execute(query)
            queries.append(query)
        }

        activeQueries[observerId] = queries
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if let args = arguments as? [String: Any],
           let observerId = args["observerId"] as? String {
            cancelObserver(observerId)
        } else {
            cancelAll()
        }
        eventSink = nil
        return nil
    }

    private func cancelObserver(_ observerId: String) {
        if let queries = activeQueries[observerId] {
            for query in queries {
                store.stop(query)
            }
            activeQueries.removeValue(forKey: observerId)
        }
    }

    private func cancelAll() {
        for (_, queries) in activeQueries {
            for query in queries {
                store.stop(query)
            }
        }
        activeQueries.removeAll()
    }

    // MARK: - Type Mapping

    private func hkSampleType(for typeName: String) -> HKSampleType? {
        return HealthKitManager.typeMapping.first(where: { $0.0 == typeName })?.1 as? HKSampleType
    }
}
