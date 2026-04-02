import Foundation
import SystemConfiguration

extension Notification.Name {
    static let pingerVPNChanged = Notification.Name("com.pinger.vpnChanged")
}

private func vpnStoreCallback(
    _ store: SCDynamicStore, _ changedKeys: CFArray, _ context: UnsafeMutableRawPointer?
) {
    guard let ctx = context else { return }
    let monitor = Unmanaged<VPNMonitor>.fromOpaque(ctx).takeUnretainedValue()
    monitor.update()
}

final class VPNMonitor {
    static let shared = VPNMonitor()
    private(set) var isVPNActive: Bool = false
    private var store: SCDynamicStore?

    private init() {
        setup()
    }

    private func setup() {
        var ctx = SCDynamicStoreContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        store = SCDynamicStoreCreate(nil, "com.pinger.vpn" as CFString, vpnStoreCallback, &ctx)

        let patterns = ["State:/Network/Service/.*/IPv4" as CFString] as CFArray
        SCDynamicStoreSetNotificationKeys(store!, nil, patterns)

        if let source = SCDynamicStoreCreateRunLoopSource(nil, store!, 0) {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }

        update()
    }

    func update() {
        let newValue = Self.checkVPN(store: store)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isVPNActive != newValue {
                self.isVPNActive = newValue
                NotificationCenter.default.post(name: .pingerVPNChanged, object: nil)
            }
        }
    }

    private static func checkVPN(store: SCDynamicStore?) -> Bool {
        guard let store else { return false }
        let pattern = "State:/Network/Service/.*/IPv4" as CFString
        guard let keys = SCDynamicStoreCopyKeyList(store, pattern) as? [String] else { return false }
        for key in keys {
            guard let dict = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any],
                  let iface = dict["InterfaceName"] as? String else { continue }
            if iface.hasPrefix("utun") || iface.hasPrefix("ppp") || iface.hasPrefix("ipsec") {
                return true
            }
        }
        return false
    }
}
