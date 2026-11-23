import Foundation
import IOKit.ps

/// Tells whether the Mac runs on battery and notifies when that changes.
final class PowerSourceMonitor {
    private(set) var onBattery = PowerSourceMonitor.isOnBattery()
    var onChange: ((Bool) -> Void)?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        guard runLoopSource == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource(powerSourceDidChange, context)?.takeRetainedValue() else {
            return
        }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    fileprivate func refresh() {
        let now = Self.isOnBattery()
        guard now != onBattery else { return }
        onBattery = now
        onChange?(now)
    }

    static func isOnBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPSBatteryPowerValue
    }
}

/// IOKit callback; runs on the main run loop where the source was added.
private nonisolated func powerSourceDidChange(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    MainActor.assumeIsolated {
        Unmanaged<PowerSourceMonitor>.fromOpaque(context).takeUnretainedValue().refresh()
    }
}
