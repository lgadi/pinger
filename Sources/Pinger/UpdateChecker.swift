import AppKit

enum UpdateChecker {
    private static let apiURL = URL(string: "https://api.github.com/repos/lgadi/pinger/releases/latest")!
    private static let releasesURL = URL(string: "https://github.com/lgadi/pinger/releases/latest")!

    static func checkInBackground() {
        URLSession.shared.dataTask(with: apiURL) { data, _, _ in
            guard
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tag = json["tag_name"] as? String,
                tag > appVersion
            else { return }
            DispatchQueue.main.async { showAlert(latest: tag) }
        }.resume()
    }

    private static func showAlert(latest: String) {
        let alert = NSAlert()
        alert.messageText = "Pinger \(latest) is available"
        alert.informativeText = "You're running \(appVersion). Open the releases page to download the update."
        alert.addButton(withTitle: "Open Releases Page")
        alert.addButton(withTitle: "Dismiss")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(releasesURL)
        }
    }
}
