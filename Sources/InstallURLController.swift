import Cocoa

// MARK: - Install from URL Controller

class InstallURLController: NSObject {
    let window: NSWindow
    private let urlField: NSTextField
    private let progressBar: NSProgressIndicator
    private let statusLabel: NSTextField
    private let installBtn: NSButton
    private let cancelBtn: NSButton
    private var onInstalled: (() -> Void)?

    init(onInstalled: (() -> Void)? = nil) {
        self.onInstalled = onInstalled

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "Install from URL"
        window.center()
        window.isReleasedWhenClosed = false

        urlField = NSTextField()
        progressBar = NSProgressIndicator()
        statusLabel = NSTextField(labelWithString: "")
        installBtn = NSButton(title: "Install", target: nil, action: nil)
        cancelBtn = NSButton(title: "Cancel", target: nil, action: nil)

        super.init()

        let cv = window.contentView!

        let label = NSTextField(labelWithString: "ZIP URL:")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(label)

        urlField.placeholderString = "https://example.com/sound-pack.zip"
        urlField.font = .systemFont(ofSize: 12)
        urlField.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(urlField)

        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.doubleValue = 0
        progressBar.isHidden = true
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(progressBar)

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(statusLabel)

        installBtn.bezelStyle = .rounded
        installBtn.keyEquivalent = "\r"
        installBtn.target = self
        installBtn.action = #selector(doInstall)
        installBtn.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(installBtn)

        cancelBtn.bezelStyle = .rounded
        cancelBtn.target = self
        cancelBtn.action = #selector(doCancel)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(cancelBtn)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: cv.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            urlField.topAnchor.constraint(equalTo: cv.topAnchor, constant: 18),
            urlField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            urlField.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
            progressBar.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 12),
            progressBar.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            progressBar.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
            statusLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 6),
            statusLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
            installBtn.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -20),
            installBtn.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16),
            cancelBtn.trailingAnchor.constraint(equalTo: installBtn.leadingAnchor, constant: -8),
            cancelBtn.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16),
        ])
    }

    @objc private func doInstall() {
        let urlStr = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlStr.isEmpty else {
            statusLabel.stringValue = "Please enter a URL."
            statusLabel.textColor = .systemRed
            return
        }
        guard URL(string: urlStr) != nil else {
            statusLabel.stringValue = "Invalid URL."
            statusLabel.textColor = .systemRed
            return
        }

        installBtn.isEnabled = false
        progressBar.isHidden = false
        progressBar.doubleValue = 0
        statusLabel.stringValue = "Downloading..."
        statusLabel.textColor = .secondaryLabelColor

        SoundPackManager.shared.installFromURL(urlStr, progress: { [weak self] pct in
            self?.progressBar.doubleValue = pct
        }, completion: { [weak self] success in
            if success {
                self?.statusLabel.stringValue = "Installed successfully!"
                self?.statusLabel.textColor = .systemGreen
                self?.onInstalled?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self?.window.close()
                }
            } else {
                self?.statusLabel.stringValue = "Download or extraction failed."
                self?.statusLabel.textColor = .systemRed
                self?.installBtn.isEnabled = true
            }
        })
    }

    @objc private func doCancel() {
        window.close()
    }
}
