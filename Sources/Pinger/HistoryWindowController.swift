import AppKit

// MARK: - PingChartView

final class PingChartView: NSView {

    var dataPoints: [PingDataPoint] = [] {
        didSet { needsDisplay = true }
    }

    // MARK: Drawing constants
    private let leftMargin: CGFloat  = 50
    private let rightMargin: CGFloat = 20
    private let topMargin: CGFloat   = 20
    private let bottomMargin: CGFloat = 20

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Background
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let chartRect = NSRect(
            x: leftMargin,
            y: bottomMargin,
            width: bounds.width  - leftMargin - rightMargin,
            height: bounds.height - topMargin  - bottomMargin
        )

        // No-data state
        guard !dataPoints.isEmpty else {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 13)
            ]
            let str = "No data yet" as NSString
            let size = str.size(withAttributes: attrs)
            let pt = NSPoint(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2
            )
            str.draw(at: pt, withAttributes: attrs)
            return
        }

        // Compute maxY
        let maxAvg = dataPoints.compactMap { $0.avgLatency }.max() ?? 0
        let maxY = max(maxAvg * 1.2, 100)

        // Helper: convert data-space to view-space
        let timeStamps = dataPoints.map { $0.timestamp.timeIntervalSince1970 }
        let minT = timeStamps.first!
        let maxT = timeStamps.last!
        let tRange: Double = maxT - minT > 0 ? maxT - minT : 1.0

        func xFor(_ ts: TimeInterval) -> CGFloat {
            chartRect.minX + CGFloat((ts - minT) / tRange) * chartRect.width
        }
        func yFor(_ ms: Double) -> CGFloat {
            chartRect.minY + CGFloat(ms / maxY) * chartRect.height
        }

        // Grid lines + Y-axis labels
        let gridFractions: [Double] = [0, 1.0/3.0, 2.0/3.0, 1.0]
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: NSFont.systemFont(ofSize: 10)
        ]

        NSColor.separatorColor.setStroke()
        for frac in gridFractions {
            let ms = maxY * frac
            let y  = yFor(ms)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: chartRect.minX, y: y))
            path.line(to: NSPoint(x: chartRect.maxX, y: y))
            path.lineWidth = 0.5
            path.stroke()

            let label = String(format: "%.0f", ms) as NSString
            let labelSize = label.size(withAttributes: labelAttrs)
            label.draw(
                at: NSPoint(x: chartRect.minX - labelSize.width - 4, y: y - labelSize.height / 2),
                withAttributes: labelAttrs
            )
        }

        // X axis baseline
        let xAxis = NSBezierPath()
        xAxis.move(to: NSPoint(x: chartRect.minX, y: chartRect.minY))
        xAxis.line(to: NSPoint(x: chartRect.maxX, y: chartRect.minY))
        xAxis.lineWidth = 0.5
        NSColor.separatorColor.setStroke()
        xAxis.stroke()

        // VPN active bands
        let slotWidth = dataPoints.count > 1 ? chartRect.width / CGFloat(dataPoints.count) : chartRect.width
        NSColor.systemBlue.withAlphaComponent(0.08).setFill()
        var vpnStart: Int? = nil
        for (i, point) in dataPoints.enumerated() {
            let isVPN = point.vpnActiveCount > 0
            if isVPN && vpnStart == nil { vpnStart = i }
            if let start = vpnStart, (!isVPN || i == dataPoints.count - 1) {
                let end = isVPN ? i : i - 1
                let x0 = chartRect.minX + CGFloat(start) * slotWidth
                let x1 = chartRect.minX + CGFloat(end + 1) * slotWidth
                NSRect(x: x0, y: chartRect.minY, width: x1 - x0, height: chartRect.height).fill()
                vpnStart = nil
            }
        }

        // Separate reachable and unreachable points
        let reachable = dataPoints.filter {
            $0.avgLatency != nil && $0.unreachableCount < $0.sampleCount
        }
        let unreachable = dataPoints.filter {
            $0.avgLatency == nil || $0.unreachableCount == $0.sampleCount
        }

        // Red ticks for unreachable
        NSColor.systemRed.setStroke()
        for point in unreachable {
            let x = xFor(point.timestamp.timeIntervalSince1970)
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: x, y: chartRect.minY))
            tick.line(to: NSPoint(x: x, y: chartRect.minY + 6))
            tick.lineWidth = 1.5
            tick.stroke()
        }

        // Line + dots for reachable points
        guard !reachable.isEmpty else { return }

        let lineColor = NSColor.systemBlue.withAlphaComponent(0.8)
        lineColor.setStroke()
        lineColor.setFill()

        let linePath = NSBezierPath()
        linePath.lineWidth = 1.5

        for (i, point) in reachable.enumerated() {
            let x = xFor(point.timestamp.timeIntervalSince1970)
            let y = yFor(point.avgLatency!)
            if i == 0 {
                linePath.move(to: NSPoint(x: x, y: y))
            } else {
                linePath.line(to: NSPoint(x: x, y: y))
            }
        }
        linePath.stroke()

        // Dots
        for point in reachable {
            let x = xFor(point.timestamp.timeIntervalSince1970)
            let y = yFor(point.avgLatency!)
            let dotRect = NSRect(x: x - 2, y: y - 2, width: 4, height: 4)
            let dot = NSBezierPath(ovalIn: dotRect)
            dot.fill()
        }
    }
}

// MARK: - HistoryWindowController

final class HistoryWindowController: NSWindowController, NSWindowDelegate {

    private var segmentedControl: NSSegmentedControl!
    private var chartView: PingChartView!
    private var statsOverall: NSTextField!
    private var statsVPNOn: NSTextField!
    private var statsVPNOff: NSTextField!
    private var isRefreshing = false

    // MARK: - Init

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ping History"
        window.center()
        self.init(window: window)
        window.delegate = self
        buildUI()
    }

    // MARK: - UI

    private func buildUI() {
        guard let cv = window?.contentView else { return }

        // Segmented control
        segmentedControl = NSSegmentedControl(
            labels: ["1h", "24h", "30d", "1y"],
            trackingMode: .selectOne,
            target: self,
            action: #selector(segmentChanged)
        )
        segmentedControl.selectedSegment = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(segmentedControl)

        // Stats labels
        func makeStatsLabel() -> NSTextField {
            let f = NSTextField(labelWithString: "")
            f.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            f.textColor = .secondaryLabelColor
            f.translatesAutoresizingMaskIntoConstraints = false
            return f
        }
        statsOverall = makeStatsLabel()
        statsVPNOn   = makeStatsLabel()
        statsVPNOff  = makeStatsLabel()
        cv.addSubview(statsOverall)
        cv.addSubview(statsVPNOn)
        cv.addSubview(statsVPNOff)

        // Chart view
        chartView = PingChartView()
        chartView.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(chartView)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: cv.topAnchor, constant: 12),
            segmentedControl.centerXAnchor.constraint(equalTo: cv.centerXAnchor),

            statsOverall.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            statsOverall.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 12),
            statsOverall.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -12),
            statsOverall.heightAnchor.constraint(equalToConstant: 18),

            statsVPNOn.topAnchor.constraint(equalTo: statsOverall.bottomAnchor, constant: 2),
            statsVPNOn.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 12),
            statsVPNOn.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -12),
            statsVPNOn.heightAnchor.constraint(equalToConstant: 18),

            statsVPNOff.topAnchor.constraint(equalTo: statsVPNOn.bottomAnchor, constant: 2),
            statsVPNOff.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 12),
            statsVPNOff.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -12),
            statsVPNOff.heightAnchor.constraint(equalToConstant: 18),

            chartView.topAnchor.constraint(equalTo: statsVPNOff.bottomAnchor, constant: 6),
            chartView.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
            chartView.bottomAnchor.constraint(equalTo: cv.bottomAnchor)
        ])
    }

    // MARK: - Stats

    private func updateStats() {
        let points = chartView.dataPoints

        func stats(from pts: [PingDataPoint]) -> String? {
            let latencies = pts.compactMap { $0.avgLatency }
            guard !latencies.isEmpty else { return nil }
            let avg = latencies.reduce(0, +) / Double(latencies.count)
            let min = pts.compactMap { $0.minLatency }.min() ?? avg
            let max = pts.compactMap { $0.maxLatency }.max() ?? avg
            return String(format: "avg %.0fms   min %.0fms   max %.0fms", avg, min, max)
        }

        let vpnOn  = points.filter { $0.vpnActiveCount > 0 }
        let vpnOff = points.filter { $0.vpnActiveCount == 0 && $0.avgLatency != nil }

        statsOverall.stringValue = stats(from: points).map { "Overall:  \($0)" } ?? "Overall:  no data"
        statsVPNOn.stringValue   = stats(from: vpnOn).map  { "VPN on:   \($0)" } ?? "VPN on:   —"
        statsVPNOff.stringValue  = stats(from: vpnOff).map { "VPN off:  \($0)" } ?? "VPN off:  —"
    }

    // MARK: - Data fetching

    private func queryParams() -> (resolution: String, since: Date) {
        let now = Date()
        switch segmentedControl.selectedSegment {
        case 0: return ("seconds", now.addingTimeInterval(-3600))
        case 1: return ("seconds", now.addingTimeInterval(-86400))
        case 2: return ("minutes", now.addingTimeInterval(-86400 * 30))
        case 3: return ("hours",   now.addingTimeInterval(-86400 * 365))
        default: return ("seconds", now.addingTimeInterval(-3600))
        }
    }

    private func refreshData() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let (resolution, since) = queryParams()
        DispatchQueue.global().async { [weak self] in
            let points = PingStore.shared.query(resolution: resolution, since: since)
            DispatchQueue.main.async {
                self?.chartView.dataPoints = points
                self?.updateStats()
                self?.isRefreshing = false
            }
        }
    }

    // MARK: - Observation

    private func startObserving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onNewData),
            name: .pingerNewData,
            object: nil
        )
        refreshData()
    }

    private func stopObserving() {
        NotificationCenter.default.removeObserver(self, name: .pingerNewData, object: nil)
    }

    @objc private func onNewData() {
        refreshData()
    }

    // MARK: - Actions

    @objc private func segmentChanged() {
        refreshData()
    }

    // MARK: - NSWindowController overrides

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        startObserving()
    }

    // MARK: - NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        startObserving()
    }

    func windowWillClose(_ notification: Notification) {
        stopObserving()
    }
}
