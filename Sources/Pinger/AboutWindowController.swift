import AppKit

final class AboutWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Pinger"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildUI()
    }

    private func buildUI() {
        guard let cv = window?.contentView else { return }

        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(iconView)

        let nameLabel = NSTextField(labelWithString: "Pinger")
        nameLabel.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(nameLabel)

        let versionLabel = NSTextField(labelWithString: "Version \(appVersion)")
        versionLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(versionLabel)

        let updateButton = NSButton(title: "Check for Updates…", target: self, action: #selector(checkForUpdates))
        updateButton.bezelStyle = .rounded
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(updateButton)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: cv.topAnchor, constant: 24),
            iconView.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            nameLabel.centerXAnchor.constraint(equalTo: cv.centerXAnchor),

            versionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            versionLabel.centerXAnchor.constraint(equalTo: cv.centerXAnchor),

            updateButton.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 20),
            updateButton.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
            updateButton.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -24),
        ])
    }

    @objc private func checkForUpdates() {
        UpdateChecker.checkExplicitly()
    }
}
