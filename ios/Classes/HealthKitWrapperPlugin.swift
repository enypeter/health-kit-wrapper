import Flutter
import HealthKit

/// Entry point for the `health_kit_wrapper` plugin on iOS.
///
/// Registers the three unified channels and wires them to the native
/// HealthKit handlers. This replaces the manual channel setup that used to
/// live in the host app's `AppDelegate` — the host now needs no plugin code.
public class HealthKitWrapperPlugin: NSObject, FlutterPlugin {

    // Strong references — the manager/reader serve MethodChannels and the
    // observer is the EventChannel stream handler. They must outlive
    // `register(with:)`, so we hold them on the published plugin instance.
    private let healthStore = HKHealthStore()
    private var manager: HealthKitManager?
    private var reader: HealthKitReader?
    private var observer: HealthKitObserver?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = HealthKitWrapperPlugin()
        let messenger = registrar.messenger()

        let manager = HealthKitManager(store: instance.healthStore)
        let reader = HealthKitReader(store: instance.healthStore)
        let observer = HealthKitObserver(store: instance.healthStore)
        instance.manager = manager
        instance.reader = reader
        instance.observer = observer

        let managerChannel = FlutterMethodChannel(
            name: "com.healthkitwrapper/manager",
            binaryMessenger: messenger
        )
        managerChannel.setMethodCallHandler { call, result in
            manager.handle(call, result: result)
        }

        let readerChannel = FlutterMethodChannel(
            name: "com.healthkitwrapper/reader",
            binaryMessenger: messenger
        )
        readerChannel.setMethodCallHandler { call, result in
            reader.handle(call, result: result)
        }

        let observerChannel = FlutterEventChannel(
            name: "com.healthkitwrapper/observer",
            binaryMessenger: messenger
        )
        observerChannel.setStreamHandler(observer)

        // Keep the instance (and therefore the handlers) alive for the
        // lifetime of the plugin registrar.
        registrar.publish(instance)
    }
}
