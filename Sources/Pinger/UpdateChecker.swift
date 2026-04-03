import AppKit

enum UpdateChecker {
    private static let apiURL = URL(string: "https://api.github.com/repos/lgadi/pinger/releases/latest")!
    private static let releasesURL = URL(string: "https://github.com/lgadi/pinger/releases/latest")!

    /// Silent check on launch — only shows alert if a newer version exists.
    static func checkInBackground() {
        fetch { latest in
            guard let latest, latest > appVersion else { return }
            DispatchQueue.main.async { showUpdateAlert(latest: latest) }
        }
    }

    /// Explicit check (e.g. from About panel) — always shows a result.
    static func checkExplicitly() {
        fetch { latest in
            DispatchQueue.main.async {
                if let latest, latest > appVersion {
                    showUpdateAlert(latest: latest)
                } else if latest != nil {
                    let alert = NSAlert()
                    alert.messageText = "You're up to date"
                    alert.informativeText = "Pinger \(appVersion) is the latest version."
                    alert.runModal()
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Couldn't check for updates"
                    alert.informativeText = "Make sure you're connected to the internet and try again."
                    alert.runModal()
                }
            }
        }
    }

    private static func fetch(completion: @escaping (String?) -> Void) {
        URLSession.shared.dataTask(with: apiURL) { data, _, _ in
            guard
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tag = json["tag_name"] as? String
            else { completion(nil); return }
            completion(tag)
        }.resume()
    }

    private static func showUpdateAlert(latest: String) {
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
