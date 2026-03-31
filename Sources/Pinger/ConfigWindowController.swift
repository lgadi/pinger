import AppKit

final class ConfigWindowController: NSWindowController {
    private var hostField: NSTextField!
    private var thresholdField: NSTextField!
    private var intervalField: NSTextField!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 210),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pinger Configuration"
        window.center()
        self.init(window: window)
        buildUI()
    }

    // MARK: - UI

    private func buildUI() {
        guard let cv = window?.contentView else { return }

        @discardableResult
        func makeLabel(_ s: String, y: CGFloat) -> NSTextField {
            let f = NSTextField(labelWithString: s)
            f.frame = NSRect(x: 20, y: y, width: 170, height: 22)
            f.alignment = .right
            cv.addSubview(f)
            return f
        }

        func makeField(y: CGFloat) -> NSTextField {
            let f = NSTextField(frame: NSRect(x: 198, y: y, width: 122, height: 22))
            cv.addSubview(f)
            return f
        }

        makeLabel("Host:", y: 158)
        hostField = makeField(y: 158)
        hostField.placeholderString = "8.8.8.8"

        makeLabel("Warn threshold (ms):", y: 112)
        thresholdField = makeField(y: 112)
        thresholdField.placeholderString = "200"

        makeLabel("Ping interval (s):", y: 66)
        intervalField = makeField(y: 66)
        intervalField.placeholderString = "1.0"

        let saveBtn = NSButton(title: "Save & Apply", target: self, action: #selector(save))
        saveBtn.frame = NSRect(x: 105, y: 20, width: 130, height: 32)
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        cv.addSubview(saveBtn)

        refresh()
    }

    /// Sync fields to current Config values (called before showing the window).
    func refresh() {
        hostField?.stringValue = Config.shared.host
        thresholdField?.stringValue = "\(Int(Config.shared.latencyThreshold))"
        intervalField?.stringValue = String(format: "%.1f", Config.shared.pingInterval)
    }

    // MARK: - Actions

    @objc private func save() {
        let host = hostField.stringValue.trimmingCharacters(in: .whitespaces)
        Config.shared.host = host.isEmpty ? "8.8.8.8" : host
        Config.shared.latencyThreshold = Double(thresholdField.stringValue) ?? 200.0
        Config.shared.pingInterval = max(0.5, Double(intervalField.stringValue) ?? 1.0)

        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.pingManager.restart()
        }

        window?.close()
    }
}
