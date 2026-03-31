import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    var pingManager: PingManager!

    private var blinkTimer: Timer?
    private var blinkPhase = false

    private var statusMenuItem: NSMenuItem!
    private var configWindowController: ConfigWindowController?

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep app out of the Dock and App Switcher
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenu()
        setButton("●", color: .secondaryLabelColor)

        pingManager = PingManager()
        pingManager.onStatusUpdate = { [weak self] status in
            DispatchQueue.main.async { self?.apply(status) }
        }
        pingManager.start()
    }

    // MARK: - Menu

    private func setupMenu() {
        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Configure…",
            action: #selector(showConfig),
            keyEquivalent: ","
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Pinger",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
    }

    // MARK: - Status updates

    private func apply(_ status: PingStatus) {
        switch status {
        case .good(let ms):
            stopBlinking()
            setButton(String(format: "● %.0fms", ms), color: .systemGreen)
            statusMenuItem.title = String(
                format: "%@ — %.1f ms  ✓", Config.shared.host, ms
            )

        case .degraded(let ms):
            stopBlinking()
            setButton(String(format: "● %.0fms", ms), color: .systemYellow)
            statusMenuItem.title = String(
                format: "%@ — %.1f ms  ⚠ high latency", Config.shared.host, ms
            )

        case .unreachable:
            statusMenuItem.title = "\(Config.shared.host) — unreachable  ✗"
            startBlinking()
        }
    }

    // MARK: - Icon helpers

    private func setButton(_ text: String, color: NSColor) {
        guard let button = statusItem.button else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: NSFont.menuBarFont(ofSize: 13)
        ]
        button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
    }

    private func startBlinking() {
        guard blinkTimer == nil else { return }
        blinkPhase = true
        setButton("●", color: .systemRed)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            blinkPhase.toggle()
            // Alternate between vivid red and near-invisible to create a pulse effect
            setButton("●", color: blinkPhase ? .systemRed : NSColor.systemRed.withAlphaComponent(0.15))
        }
    }

    private func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
    }

    // MARK: - Configuration window

    @objc private func showConfig() {
        if configWindowController == nil {
            configWindowController = ConfigWindowController()
        }
        configWindowController?.refresh()
        configWindowController?.showWindow(nil)
        configWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
