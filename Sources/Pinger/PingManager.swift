import Foundation

enum PingStatus {
    case good(latency: Double)
    case degraded(latency: Double)   // above threshold
    case unreachable                 // timeout, packet loss, or error
}

final class PingManager {
    var onStatusUpdate: ((PingStatus) -> Void)?

    private var timer: Timer?
    private var isPinging = false

    // MARK: - Lifecycle

    func start() {
        ping()
        scheduleTimer()
    }

    func restart() {
        stop()
        start()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(
            withTimeInterval: Config.shared.pingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.ping()
        }
    }

    // MARK: - Ping

    private func ping() {
        guard !isPinging else { return }
        isPinging = true

        let host = Config.shared.host
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        // -c 1  : single packet
        // -W 2000 : wait up to 2 s for a reply (macOS uses milliseconds)
        process.arguments = ["-c", "1", "-W", "2000", host]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()   // suppress error output

        // Hard-kill after 4 s in case -W is ignored by the OS version
        let killWork = DispatchWorkItem { process.terminate() }
        DispatchQueue.global().asyncAfter(deadline: .now() + 4, execute: killWork)

        process.terminationHandler = { [weak self] proc in
            killWork.cancel()
            let output = String(
                data: pipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""

            let status: PingStatus
            if proc.terminationStatus == 0, let ms = Self.parseLatency(from: output) {
                status = ms >= Config.shared.latencyThreshold
                    ? .degraded(latency: ms)
                    : .good(latency: ms)
            } else {
                status = .unreachable
            }

            self?.isPinging = false
            self?.onStatusUpdate?(status)
        }

        do {
            try process.run()
        } catch {
            isPinging = false
            onStatusUpdate?(.unreachable)
        }
    }

    // MARK: - Parsing

    /// Extracts the round-trip time from a line like "time=12.345 ms" or "time<1.000 ms".
    private static func parseLatency(from output: String) -> Double? {
        let pattern = #"time[<=](\d+(?:\.\d+)?)\s*ms"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: output,
                range: NSRange(output.startIndex..., in: output)
            ),
            let range = Range(match.range(at: 1), in: output)
        else { return nil }
        return Double(output[range])
    }
}
