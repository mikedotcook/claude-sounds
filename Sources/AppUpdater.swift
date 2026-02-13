import Cocoa

// MARK: - App Updater

struct AppRelease {
    let version: String
    let downloadURL: URL
    let releaseNotes: String
}

class AppUpdater {
    static let shared = AppUpdater()

    private let repoOwner = "michalarent"
    private let repoName = "claude-sounds"
    private let assetName = "ClaudeSounds.app.zip"
    private var isChecking = false

    private init() {}

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    /// Returns true if `remote` is newer than `local` (dot-separated numeric comparison).
    func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.replacingOccurrences(of: "v", with: "")
            .split(separator: ".").compactMap { Int($0) }
        let l = local.replacingOccurrences(of: "v", with: "")
            .split(separator: ".").compactMap { Int($0) }
        let count = max(r.count, l.count)
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }

    // MARK: - Check for Updates

    func checkForUpdate(completion: @escaping (AppRelease?) -> Void) {
        guard !isChecking else { completion(nil); return }
        isChecking = true

        let urlStr = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlStr) else {
            isChecking = false
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            defer { self?.isChecking = false }
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let assets = json["assets"] as? [[String: Any]] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let version = tagName.replacingOccurrences(of: "v", with: "")
            let body = json["body"] as? String ?? ""

            guard self.isNewer(version, than: self.currentVersion) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let asset = assets.first(where: { ($0["name"] as? String) == self.assetName }),
                  let dlUrlStr = asset["browser_download_url"] as? String,
                  let dlUrl = URL(string: dlUrlStr) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let release = AppRelease(version: version, downloadURL: dlUrl, releaseNotes: body)
            DispatchQueue.main.async { completion(release) }
        }.resume()
    }

    // MARK: - User-Facing Check

    func checkForUpdateInteractive() {
        checkForUpdate { [weak self] release in
            guard let self = self else { return }
            if let release = release {
                self.promptUpdate(release)
            } else {
                let alert = NSAlert()
                alert.messageText = "You're up to date"
                alert.informativeText = "Claude Sounds \(self.currentVersion) is the latest version."
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    func checkForUpdateSilent() {
        checkForUpdate { [weak self] release in
            guard let release = release else { return }
            self?.promptUpdate(release)
        }
    }

    // MARK: - Update Prompt

    private func promptUpdate(_ release: AppRelease) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "Claude Sounds \(release.version) is available (you have \(currentVersion)).\n\n\(release.releaseNotes)"
        alert.addButton(withTitle: "Update Now")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            downloadAndInstall(release)
        }
    }

    // MARK: - Download and Install

    private func downloadAndInstall(_ release: AppRelease) {
        let progressWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 100),
            styleMask: [.titled],
            backing: .buffered, defer: false
        )
        progressWindow.title = "Updating Claude Sounds..."
        progressWindow.center()
        progressWindow.isReleasedWhenClosed = false

        let cv = progressWindow.contentView!

        let label = NSTextField(labelWithString: "Downloading update...")
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(label)

        let progressBar = NSProgressIndicator()
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.doubleValue = 0
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(progressBar)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: cv.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
            progressBar.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            progressBar.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            progressBar.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
        ])

        progressWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let delegate = DownloadDelegate(progress: { pct in
            DispatchQueue.main.async { progressBar.doubleValue = pct }
        }, completion: { [weak self] tempUrl in
            DispatchQueue.main.async { progressWindow.close() }
            guard let self = self, let tempUrl = tempUrl else {
                DispatchQueue.main.async { self?.showUpdateError("Download failed.") }
                return
            }
            self.performReplacement(zipAt: tempUrl)
        })

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        session.downloadTask(with: release.downloadURL).resume()
    }

    // MARK: - Self-Replacement

    private func performReplacement(zipAt tempZip: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            let currentBundlePath = Bundle.main.bundlePath
            let currentBundleDir = (currentBundlePath as NSString).deletingLastPathComponent

            // Check write permission
            guard fm.isWritableFile(atPath: currentBundleDir) else {
                DispatchQueue.main.async {
                    self.showUpdateError(
                        "Cannot update: no write permission to \(currentBundleDir).\n\n"
                        + "Move ClaudeSounds.app to a location where you have write access."
                    )
                }
                try? fm.removeItem(at: tempZip)
                return
            }

            // Extract ZIP to temp directory
            let extractDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("ClaudeSounds-update-\(UUID().uuidString)")
            try? fm.createDirectory(at: extractDir, withIntermediateDirectories: true)

            let unzipProc = Process()
            unzipProc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzipProc.arguments = ["-o", tempZip.path, "-d", extractDir.path]
            unzipProc.standardOutput = FileHandle.nullDevice
            unzipProc.standardError = FileHandle.nullDevice

            do {
                try unzipProc.run()
                unzipProc.waitUntilExit()
            } catch {
                DispatchQueue.main.async { self.showUpdateError("Failed to extract update.") }
                try? fm.removeItem(at: tempZip)
                try? fm.removeItem(at: extractDir)
                return
            }

            try? fm.removeItem(at: tempZip)

            guard unzipProc.terminationStatus == 0 else {
                DispatchQueue.main.async { self.showUpdateError("Failed to extract update.") }
                try? fm.removeItem(at: extractDir)
                return
            }

            // Find the extracted .app bundle
            let directPath = extractDir.appendingPathComponent("ClaudeSounds.app").path
            let extractedAppPath: String
            if fm.fileExists(atPath: directPath) {
                extractedAppPath = directPath
            } else {
                guard let contents = try? fm.contentsOfDirectory(atPath: extractDir.path),
                      let appName = contents.first(where: { $0.hasSuffix(".app") }) else {
                    DispatchQueue.main.async { self.showUpdateError("No .app found in update archive.") }
                    try? fm.removeItem(at: extractDir)
                    return
                }
                extractedAppPath = extractDir.appendingPathComponent(appName).path
            }

            // Write and launch the replacement script
            let pid = ProcessInfo.processInfo.processIdentifier
            let scriptPath = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("claude-sounds-update.sh")

            let script = """
            #!/bin/bash
            while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
            rm -rf "\(currentBundlePath)"
            mv "\(extractedAppPath)" "\(currentBundlePath)"
            xattr -cr "\(currentBundlePath)"
            rm -rf "\(extractDir.path)"
            open "\(currentBundlePath)"
            rm -f "\(scriptPath)"
            """

            do {
                try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            } catch {
                DispatchQueue.main.async { self.showUpdateError("Failed to prepare update.") }
                try? fm.removeItem(at: extractDir)
                return
            }

            // Make executable and launch
            let chmodProc = Process()
            chmodProc.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodProc.arguments = ["+x", scriptPath]
            try? chmodProc.run()
            chmodProc.waitUntilExit()

            let scriptProc = Process()
            scriptProc.executableURL = URL(fileURLWithPath: "/bin/bash")
            scriptProc.arguments = [scriptPath]
            scriptProc.standardOutput = FileHandle.nullDevice
            scriptProc.standardError = FileHandle.nullDevice

            do {
                try scriptProc.run()
            } catch {
                DispatchQueue.main.async { self.showUpdateError("Failed to launch update.") }
                try? fm.removeItem(at: extractDir)
                try? fm.removeItem(atPath: scriptPath)
                return
            }

            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    private func showUpdateError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Update Failed"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
