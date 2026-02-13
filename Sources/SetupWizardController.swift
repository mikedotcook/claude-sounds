import Cocoa

// MARK: - Setup Wizard

class SetupWizardController: NSObject {
    let window: NSWindow
    private var currentStep = 0
    private let contentContainer: NSView
    private let stepLabel: NSTextField
    private let backBtn: NSButton
    private let nextBtn: NSButton
    private let skipBtn: NSButton
    private var selectedPackId: String?
    private var installedPacks: [String] = []
    private var manifestPacks: [SoundPackInfo] = []
    private var packRadioButtons: [NSButton] = []
    private var statusLabel: NSTextField?
    private var hookInstallDone = false
    private var completionHandler: (() -> Void)?

    init(completion: (() -> Void)? = nil) {
        self.completionHandler = completion

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "Claude Sounds Setup"
        window.center()
        window.isReleasedWhenClosed = false

        let cv = window.contentView!

        stepLabel = NSTextField(labelWithString: "Step 1 of 3")
        stepLabel.font = .systemFont(ofSize: 11)
        stepLabel.textColor = .secondaryLabelColor
        stepLabel.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(stepLabel)

        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(contentContainer)

        backBtn = NSButton(title: "Back", target: nil, action: nil)
        backBtn.bezelStyle = .rounded
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(backBtn)

        nextBtn = NSButton(title: "Next", target: nil, action: nil)
        nextBtn.bezelStyle = .rounded
        nextBtn.keyEquivalent = "\r"
        nextBtn.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(nextBtn)

        skipBtn = NSButton(title: "Skip Setup", target: nil, action: nil)
        skipBtn.bezelStyle = .rounded
        skipBtn.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(skipBtn)

        NSLayoutConstraint.activate([
            stepLabel.topAnchor.constraint(equalTo: cv.topAnchor, constant: 14),
            stepLabel.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -16),
            contentContainer.topAnchor.constraint(equalTo: stepLabel.bottomAnchor, constant: 8),
            contentContainer.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            contentContainer.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
            contentContainer.bottomAnchor.constraint(equalTo: backBtn.topAnchor, constant: -16),
            skipBtn.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 16),
            skipBtn.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -14),
            nextBtn.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -16),
            nextBtn.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -14),
            backBtn.trailingAnchor.constraint(equalTo: nextBtn.leadingAnchor, constant: -8),
            backBtn.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -14),
        ])

        super.init()

        backBtn.target = self
        backBtn.action = #selector(goBack)
        nextBtn.target = self
        nextBtn.action = #selector(goNext)
        skipBtn.target = self
        skipBtn.action = #selector(skipSetup)

        installedPacks = SoundPackManager.shared.installedPackIds()
        if installedPacks.contains("protoss") {
            selectedPackId = "protoss"
        } else if let first = installedPacks.first {
            selectedPackId = first
        }

        SoundPackManager.shared.fetchManifest { [weak self] manifest in
            self?.manifestPacks = manifest?.packs ?? []
            if self?.currentStep == 0 { self?.showStep(0) }
        }

        showStep(0)
    }

    private func showStep(_ step: Int) {
        currentStep = step
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        packRadioButtons.removeAll()

        stepLabel.stringValue = "Step \(step + 1) of 3"
        backBtn.isHidden = step == 0
        skipBtn.isHidden = step == 2

        switch step {
        case 0: showPackSelection()
        case 1: showHookInstall()
        case 2: showComplete()
        default: break
        }
    }

    // MARK: Step 1 - Pack Selection

    private func showPackSelection() {
        nextBtn.title = "Next"
        nextBtn.isEnabled = true

        let title = NSTextField(labelWithString: "Welcome to Claude Sounds!")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(title)

        let subtitle = NSTextField(labelWithString: "Choose a sound pack to get started:")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(subtitle)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 10),
            title.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            subtitle.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
        ])

        // Collect all packs (installed + from manifest)
        var allPacks: [(id: String, name: String, desc: String, installed: Bool)] = []
        for packId in installedPacks {
            let info = manifestPacks.first { $0.id == packId }
            allPacks.append((packId, info?.name ?? packId.capitalized,
                             info?.description ?? "Locally installed", true))
        }
        for pack in manifestPacks where !installedPacks.contains(pack.id) {
            allPacks.append((pack.id, pack.name, pack.description, false))
        }

        var lastAnchor = subtitle.bottomAnchor
        for (i, pack) in allPacks.enumerated() {
            let radio = NSButton(radioButtonWithTitle: " \(pack.name)", target: self,
                                 action: #selector(packSelected(_:)))
            radio.tag = i
            radio.font = .systemFont(ofSize: 13)
            radio.state = pack.id == selectedPackId ? .on : .off
            radio.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview(radio)
            packRadioButtons.append(radio)

            let desc = NSTextField(labelWithString: pack.desc + (pack.installed ? "" : " (will download)"))
            desc.font = .systemFont(ofSize: 11)
            desc.textColor = .tertiaryLabelColor
            desc.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview(desc)

            NSLayoutConstraint.activate([
                radio.topAnchor.constraint(equalTo: lastAnchor, constant: i == 0 ? 20 : 10),
                radio.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 10),
                desc.topAnchor.constraint(equalTo: radio.bottomAnchor, constant: 1),
                desc.leadingAnchor.constraint(equalTo: radio.leadingAnchor, constant: 20),
            ])
            lastAnchor = desc.bottomAnchor
        }

        if allPacks.isEmpty {
            let empty = NSTextField(labelWithString: "No packs found. You can add packs later from the menu.")
            empty.font = .systemFont(ofSize: 12)
            empty.textColor = .secondaryLabelColor
            empty.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview(empty)
            NSLayoutConstraint.activate([
                empty.topAnchor.constraint(equalTo: lastAnchor, constant: 20),
                empty.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            ])
        }
    }

    @objc func packSelected(_ sender: NSButton) {
        for btn in packRadioButtons { btn.state = .off }
        sender.state = .on

        var allPacks: [(id: String, name: String)] = []
        for packId in installedPacks {
            let info = manifestPacks.first { $0.id == packId }
            allPacks.append((packId, info?.name ?? packId.capitalized))
        }
        for pack in manifestPacks where !installedPacks.contains(pack.id) {
            allPacks.append((pack.id, pack.name))
        }

        if sender.tag < allPacks.count {
            selectedPackId = allPacks[sender.tag].id
        }
    }

    // MARK: Step 2 - Hook Install

    private func showHookInstall() {
        nextBtn.title = "Install"
        nextBtn.isEnabled = !hookInstallDone
        hookInstallDone = false

        let title = NSTextField(labelWithString: "Install Sound Hooks")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(title)

        let desc = NSTextField(wrappingLabelWithString:
            "This will:\n" +
            "  \u{2022} Create claude-sounds.sh hook script\n" +
            "  \u{2022} Add hook entries to Claude settings.json\n" +
            "  \u{2022} Back up your current settings first\n" +
            "  \u{2022} Set \"\(selectedPackId ?? "—")\" as the active pack")
        desc.font = .systemFont(ofSize: 13)
        desc.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(desc)

        let status = NSTextField(labelWithString: "")
        status.font = .systemFont(ofSize: 12, weight: .medium)
        status.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(status)
        statusLabel = status

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 10),
            title.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            desc.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
            desc.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            desc.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            status.topAnchor.constraint(equalTo: desc.bottomAnchor, constant: 20),
            status.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
        ])
    }

    private func performInstall() {
        // Set active pack
        if let packId = selectedPackId {
            // Download if not installed
            if !installedPacks.contains(packId),
               let pack = manifestPacks.first(where: { $0.id == packId }) {
                statusLabel?.stringValue = "Downloading \(pack.name)..."
                statusLabel?.textColor = .labelColor
                nextBtn.isEnabled = false

                SoundPackManager.shared.downloadAndInstall(pack: pack, progress: { _ in },
                    completion: { [weak self] success in
                        if success {
                            self?.installedPacks = SoundPackManager.shared.installedPackIds()
                            self?.finishInstall()
                        } else {
                            self?.statusLabel?.stringValue = "Download failed. Try again."
                            self?.statusLabel?.textColor = .systemRed
                            self?.nextBtn.isEnabled = true
                        }
                    })
                return
            }
            SoundPackManager.shared.setActivePack(packId)
        }

        finishInstall()
    }

    private func finishInstall() {
        if let packId = selectedPackId {
            SoundPackManager.shared.setActivePack(packId)
        }

        let success = HookInstaller.shared.install()
        if success {
            statusLabel?.stringValue = "Installed successfully!"
            statusLabel?.textColor = .systemGreen
            hookInstallDone = true
            nextBtn.title = "Next"
            nextBtn.isEnabled = true
        } else {
            statusLabel?.stringValue = "Installation failed. Check permissions."
            statusLabel?.textColor = .systemRed
            nextBtn.isEnabled = true
        }
    }

    // MARK: Step 3 - Complete

    private func showComplete() {
        nextBtn.title = "Done"
        nextBtn.isEnabled = true

        let title = NSTextField(labelWithString: "You're all set!")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(title)

        let activePack = SoundPackManager.shared.activePackId() ?? "none"
        let hookStatus = HookInstaller.shared.isHookInstalled() ? "Installed" : "Not installed"

        let info = NSTextField(wrappingLabelWithString:
            "Active pack: \(activePack)\n" +
            "Hooks: \(hookStatus)\n\n" +
            "You can manage sound packs and edit individual sounds from the menu bar icon.")
        info.font = .systemFont(ofSize: 13)
        info.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(info)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 10),
            title.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            info.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
            info.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            info.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
        ])
    }

    // MARK: Navigation

    @objc func goBack() {
        if currentStep > 0 { showStep(currentStep - 1) }
    }

    @objc func goNext() {
        switch currentStep {
        case 0:
            showStep(1)
        case 1:
            if hookInstallDone {
                showStep(2)
            } else {
                performInstall()
            }
        case 2:
            markSetupComplete()
            window.close()
            completionHandler?()
        default:
            break
        }
    }

    @objc func skipSetup() {
        markSetupComplete()
        window.close()
        completionHandler?()
    }

    private func markSetupComplete() {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".claude/sounds/.setup-complete")
        try? "1".write(toFile: path, atomically: true, encoding: .utf8)
    }
}
