import Cocoa

// MARK: - Publish Pack Controller

class PublishPackController: NSObject {
    let window: NSWindow
    private let packId: String
    private let nameField: NSTextField
    private let descField: NSTextField
    private let authorField: NSTextField
    private let versionField: NSTextField
    private let statusLabel: NSTextField
    private let exportBtn: NSButton
    private let submitBtn: NSButton
    private var onPublished: (() -> Void)?

    init(packId: String, onPublished: (() -> Void)? = nil) {
        self.packId = packId
        self.onPublished = onPublished

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "Publish Sound Pack"
        window.center()
        window.isReleasedWhenClosed = false

        nameField = NSTextField()
        descField = NSTextField()
        authorField = NSTextField()
        versionField = NSTextField()
        statusLabel = NSTextField(labelWithString: "")
        exportBtn = NSButton(title: "Export ZIP...", target: nil, action: nil)
        submitBtn = NSButton(title: "Submit to Community...", target: nil, action: nil)

        super.init()

        let cv = window.contentView!

        // Pack ID (read-only)
        let idLabel = NSTextField(labelWithString: "Pack ID:")
        idLabel.font = .systemFont(ofSize: 12, weight: .medium)
        idLabel.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(idLabel)

        let idValue = NSTextField(labelWithString: packId)
        idValue.font = .systemFont(ofSize: 12)
        idValue.textColor = .secondaryLabelColor
        idValue.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(idValue)

        // Editable fields
        let fields: [(String, NSTextField, String)] = [
            ("Name:", nameField, titleCase(packId)),
            ("Description:", descField, ""),
            ("Author:", authorField, ""),
            ("Version:", versionField, "1.0"),
        ]

        var fieldViews: [(NSTextField, NSTextField)] = []
        for (label, field, placeholder) in fields {
            let lbl = NSTextField(labelWithString: label)
            lbl.font = .systemFont(ofSize: 12, weight: .medium)
            lbl.translatesAutoresizingMaskIntoConstraints = false
            cv.addSubview(lbl)

            field.placeholderString = placeholder
            field.stringValue = placeholder
            field.font = .systemFont(ofSize: 12)
            field.translatesAutoresizingMaskIntoConstraints = false
            cv.addSubview(field)
            fieldViews.append((lbl, field))
        }

        // Pre-fill from local metadata first, then remote manifest as fallback
        let localMeta = SoundPackManager.shared.loadPackMetadata(id: packId)
        if let meta = localMeta {
            if let n = meta["name"], !n.isEmpty { nameField.stringValue = n }
            if let d = meta["description"], !d.isEmpty { descField.stringValue = d }
            if let a = meta["author"], !a.isEmpty { authorField.stringValue = a }
            if let v = meta["version"], !v.isEmpty { versionField.stringValue = v }
        }
        SoundPackManager.shared.fetchManifestMerged { [weak self] manifest in
            guard let self = self, let info = manifest?.packs.first(where: { $0.id == packId }) else { return }
            // Only fill fields that are still at their placeholder defaults
            if self.nameField.stringValue == self.titleCase(packId) { self.nameField.stringValue = info.name }
            if self.descField.stringValue.isEmpty { self.descField.stringValue = info.description }
            if self.authorField.stringValue.isEmpty { self.authorField.stringValue = info.author }
            if self.versionField.stringValue == "1.0" { self.versionField.stringValue = info.version }
        }

        // Stats
        let stats = SoundPackManager.shared.packStats(id: packId)
        let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(stats.totalSize), countStyle: .file)
        let statsLabel = NSTextField(labelWithString: "\(stats.fileCount) audio files, \(sizeStr)")
        statsLabel.font = .systemFont(ofSize: 11)
        statsLabel.textColor = .tertiaryLabelColor
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(statsLabel)

        // Status
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(statusLabel)

        // Buttons
        exportBtn.bezelStyle = .rounded
        exportBtn.target = self
        exportBtn.action = #selector(doExport)
        exportBtn.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(exportBtn)

        submitBtn.bezelStyle = .rounded
        submitBtn.target = self
        submitBtn.action = #selector(doSubmit)
        submitBtn.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(submitBtn)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(doCancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(cancelBtn)

        // Layout
        let labelWidth: CGFloat = 90
        let leftMargin: CGFloat = 20
        let rightMargin: CGFloat = -20
        var topAnchor = cv.topAnchor

        // Pack ID row
        NSLayoutConstraint.activate([
            idLabel.topAnchor.constraint(equalTo: cv.topAnchor, constant: 20),
            idLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: leftMargin),
            idLabel.widthAnchor.constraint(equalToConstant: labelWidth),
            idValue.leadingAnchor.constraint(equalTo: idLabel.trailingAnchor, constant: 8),
            idValue.centerYAnchor.constraint(equalTo: idLabel.centerYAnchor),
        ])
        topAnchor = idLabel.bottomAnchor

        // Form rows
        for (lbl, field) in fieldViews {
            NSLayoutConstraint.activate([
                lbl.topAnchor.constraint(equalTo: topAnchor, constant: 10),
                lbl.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: leftMargin),
                lbl.widthAnchor.constraint(equalToConstant: labelWidth),
                field.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 8),
                field.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: rightMargin),
                field.centerYAnchor.constraint(equalTo: lbl.centerYAnchor),
            ])
            topAnchor = lbl.bottomAnchor
        }

        NSLayoutConstraint.activate([
            statsLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            statsLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: leftMargin),

            statusLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: leftMargin),
            statusLabel.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: rightMargin),
            statusLabel.bottomAnchor.constraint(equalTo: exportBtn.topAnchor, constant: -10),

            cancelBtn.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: rightMargin),
            cancelBtn.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16),
            exportBtn.trailingAnchor.constraint(equalTo: cancelBtn.leadingAnchor, constant: -8),
            exportBtn.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16),
            submitBtn.trailingAnchor.constraint(equalTo: exportBtn.leadingAnchor, constant: -8),
            submitBtn.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16),
        ])
    }

    private func titleCase(_ id: String) -> String {
        return id.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    // MARK: - Export ZIP

    @objc private func doExport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(packId).zip"
        panel.allowedContentTypes = [.init(filenameExtension: "zip")!]

        guard panel.runModal() == .OK, let dest = panel.url else { return }

        exportBtn.isEnabled = false
        statusLabel.stringValue = "Exporting..."
        statusLabel.textColor = .secondaryLabelColor

        SoundPackManager.shared.exportPackAsZip(id: packId, to: dest) { [weak self] success in
            if success {
                self?.statusLabel.stringValue = "Exported to \(dest.lastPathComponent)"
                self?.statusLabel.textColor = .systemGreen
            } else {
                self?.statusLabel.stringValue = "Export failed."
                self?.statusLabel.textColor = .systemRed
            }
            self?.exportBtn.isEnabled = true
        }
    }

    // MARK: - Submit to Community

    @objc private func doSubmit() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = descField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = authorField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let version = versionField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            statusLabel.stringValue = "Pack name is required."
            statusLabel.textColor = .systemRed
            return
        }

        submitBtn.isEnabled = false
        exportBtn.isEnabled = false
        statusLabel.stringValue = "Preparing submission..."
        statusLabel.textColor = .secondaryLabelColor

        let stats = SoundPackManager.shared.packStats(id: packId)
        let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(stats.totalSize), countStyle: .file)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let tmpZip = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("\(self.packId).zip")
            let tmpClone = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("claude-sounds-submit-\(UUID().uuidString)")

            defer {
                try? FileManager.default.removeItem(at: tmpZip)
                try? FileManager.default.removeItem(at: tmpClone)
            }

            // 1. Export ZIP
            let exportSem = DispatchSemaphore(value: 0)
            var exportOK = false
            SoundPackManager.shared.exportPackAsZip(id: self.packId, to: tmpZip) { success in
                exportOK = success
                exportSem.signal()
            }
            exportSem.wait()

            guard exportOK else {
                self.updateStatus("Failed to create ZIP.", error: true)
                return
            }

            self.updateStatus("Forking repository...")

            // 2. Fork (idempotent)
            _ = self.shell("/usr/bin/env", ["gh", "repo", "fork", "michalarent/claude-sounds", "--clone=false"])
            // Fork may "fail" if already forked — that's fine

            // 3. Get the user's fork name
            let whoami = self.shell("/usr/bin/env", ["gh", "api", "user", "--jq", ".login"]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !whoami.isEmpty else {
                self.updateStatus("Failed to get GitHub username. Is `gh` authenticated?", error: true)
                return
            }

            self.updateStatus("Cloning fork...")

            let forkRepo = "\(whoami)/claude-sounds"
            let branch = "community/add-\(self.packId)"

            // 4. Clone fork
            _ = self.shell("/usr/bin/env", ["gh", "repo", "clone", forkRepo, tmpClone.path, "--", "--depth=1"])
            guard FileManager.default.fileExists(atPath: tmpClone.path) else {
                self.updateStatus("Failed to clone fork.", error: true)
                return
            }

            // 5. Create branch
            _ = self.shell("/usr/bin/git", ["-C", tmpClone.path, "checkout", "-b", branch])

            // 5b. Upload ZIP to v2.0 release
            self.updateStatus("Uploading ZIP to release...")
            let uploadResult = self.shellWithStatus("/usr/bin/env", [
                "gh", "release", "upload", "v2.0", tmpZip.path,
                "--repo", "michalarent/claude-sounds", "--clobber"
            ])
            if uploadResult.exitCode != 0 {
                self.updateStatus("Failed to upload ZIP: \(uploadResult.output.trimmingCharacters(in: .whitespacesAndNewlines)). Ensure `gh` is installed and you have repo access.", error: true)
                return
            }

            self.updateStatus("Updating manifest...")

            // 6. Read and update manifest
            let manifestPath = (tmpClone.path as NSString).appendingPathComponent("community/manifest.json")
            guard let manifestData = FileManager.default.contents(atPath: manifestPath),
                  let manifest = try? JSONDecoder().decode(SoundPackManifest.self, from: manifestData) else {
                self.updateStatus("Failed to read community manifest.", error: true)
                return
            }

            // Remove existing entry for this pack ID if present
            var packs = manifest.packs.filter { $0.id != self.packId }

            let downloadUrl = "https://github.com/michalarent/claude-sounds/releases/download/v2.0/\(self.packId).zip"

            let newEntry = SoundPackInfo(
                id: self.packId,
                name: name,
                description: desc,
                version: version.isEmpty ? "1.0" : version,
                author: author.isEmpty ? whoami : author,
                downloadUrl: downloadUrl,
                size: sizeStr,
                fileCount: stats.fileCount,
                previewUrl: nil
            )
            packs.append(newEntry)

            let updatedManifest = SoundPackManifest(version: manifest.version, packs: packs)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let updatedData = try? encoder.encode(updatedManifest) else {
                self.updateStatus("Failed to encode manifest.", error: true)
                return
            }
            try? updatedData.write(to: URL(fileURLWithPath: manifestPath))

            // 7. Commit and push
            _ = self.shell("/usr/bin/git", ["-C", tmpClone.path, "add", "community/manifest.json"])
            _ = self.shell("/usr/bin/git", ["-C", tmpClone.path, "commit", "-m", "Add \(name) community pack"])
            _ = self.shell("/usr/bin/git", ["-C", tmpClone.path, "push", "-u", "origin", branch, "--force"])

            self.updateStatus("Opening pull request...")

            // 8. Create PR
            let prBody = "Adds **\(name)** community sound pack (`\(self.packId)`).\n\n"
                + "- \(stats.fileCount) audio files, \(sizeStr)\n"
                + "- Author: \(author.isEmpty ? whoami : author)\n\n"
                + "**Before merging:** upload the ZIP to the v2.0 release:\n"
                + "```\ngh release upload v2.0 /path/to/\(self.packId).zip --clobber\n```"

            let prResult = self.shell("/usr/bin/env", [
                "gh", "pr", "create",
                "--repo", "michalarent/claude-sounds",
                "--head", "\(whoami):\(branch)",
                "--title", "Add \(name) community pack",
                "--body", prBody
            ])

            let prUrl = prResult.trimmingCharacters(in: .whitespacesAndNewlines)
            if prUrl.hasPrefix("http") {
                self.updateStatus("PR created: \(prUrl)", error: false)
                DispatchQueue.main.async { self.onPublished?() }
            } else {
                // PR might already exist
                if prResult.contains("already exists") {
                    self.updateStatus("PR already exists for this pack.", error: false)
                } else {
                    self.updateStatus("Push succeeded. Create PR manually on GitHub.", error: false)
                }
            }
        }
    }

    private func updateStatus(_ message: String, error: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.stringValue = message
            self?.statusLabel.textColor = error ? .systemRed : .secondaryLabelColor
            if error || message.contains("PR created") || message.contains("already exists") || message.contains("manually") {
                self?.submitBtn.isEnabled = true
                self?.exportBtn.isEnabled = true
            }
        }
    }

    private func shell(_ executable: String, _ args: [String]) -> String {
        return shellWithStatus(executable, args).output
    }

    private func shellWithStatus(_ executable: String, _ args: [String]) -> (output: String, exitCode: Int32) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = args
        // Include common paths so `gh` is found when launched as a .app
        var env = ProcessInfo.processInfo.environment
        let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
        proc.environment = env
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return ("", 1)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (output, proc.terminationStatus)
    }

    @objc private func doCancel() {
        window.close()
    }
}
