import Foundation

final class Config {
    static let shared = Config()
    private init() {}

    var host: String {
        get { UserDefaults.standard.string(forKey: "pingerHost") ?? "8.8.8.8" }
        set { UserDefaults.standard.set(newValue, forKey: "pingerHost") }
    }

    /// Latency above this value (in ms) turns the indicator yellow.
    var latencyThreshold: Double {
        get {
            let v = UserDefaults.standard.double(forKey: "pingerThreshold")
            return v > 0 ? v : 200.0
        }
        set { UserDefaults.standard.set(newValue, forKey: "pingerThreshold") }
    }

    /// How often to send a ping, in seconds.
    var pingInterval: Double {
        get {
            let v = UserDefaults.standard.double(forKey: "pingerInterval")
            return v > 0 ? v : 1.0
        }
        set { UserDefaults.standard.set(newValue, forKey: "pingerInterval") }
    }
}
