import AppKit

extension Notification.Name {
    static let pingerStatusUpdate = Notification.Name("com.pinger.statusUpdate")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    var pingManager: PingManager!

    private var blinkTimer: Timer?
    private var blinkPhase = false

    private var statusMenuItem: NSMenuItem!
    private var aboutWindowController: AboutWindowController?
    private var configWindowController: ConfigWindowController?
    private var historyWindowController: HistoryWindowController?

    private(set) var currentStatus: PingStatus?

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenu()
        setButton("●", color: .secondaryLabelColor)

        pingManager = PingManager()
        pingManager.onStatusUpdate = { [weak self] status in
            DispatchQueue.main.async { self?.apply(status) }
        }
        pingManager.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            UpdateChecker.checkInBackground()
        }
    }

    // MARK: - Menu

    private func setupMenu() {
        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "History…",
            action: #selector(showHistory),
            keyEquivalent: "h"
        ))
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
        setupMainMenu()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu (first item title is ignored by macOS — it always shows the app name)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About Pinger",        action: #selector(showAbout),       keyEquivalent: ""))
        appMenu.addItem(NSMenuItem(title: "Check for Updates…",  action: #selector(checkForUpdates), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "History…",            action: #selector(showHistory),     keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "Configure…",          action: #selector(showConfig),      keyEquivalent: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Pinger",         action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Status updates

    private func apply(_ status: PingStatus) {
        currentStatus = status
        NotificationCenter.default.post(name: .pingerStatusUpdate, object: nil)
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

    // MARK: - Reopen (re-launch while already running)

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showHistory()
        return true
    }

    // MARK: - Configuration window

    @objc private func showAbout() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
        becomeRegularApp()
    }

    @objc private func checkForUpdates() {
        UpdateChecker.checkExplicitly()
    }

    @objc private func showHistory() {
        if historyWindowController == nil {
            historyWindowController = HistoryWindowController()
        }
        historyWindowController?.showWindow(nil)
        historyWindowController?.window?.makeKeyAndOrderFront(nil)
        becomeRegularApp()
    }

    @objc private func showConfig() {
        if configWindowController == nil {
            configWindowController = ConfigWindowController()
        }
        configWindowController?.refresh()
        configWindowController?.showWindow(nil)
        configWindowController?.window?.makeKeyAndOrderFront(nil)
        becomeRegularApp()
    }

    // MARK: - Activation policy

    private func becomeRegularApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowClosed),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    @objc private func windowClosed() {
        let stillOpen = NSApp.windows.contains { $0.isVisible && $0 !== statusItem.button?.window }
        if !stillOpen {
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
