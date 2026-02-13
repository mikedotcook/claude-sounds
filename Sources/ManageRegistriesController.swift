import Cocoa

// MARK: - Manage Registries Controller

class ManageRegistriesController: NSObject {
    let window: NSWindow
    private let scrollView: NSScrollView
    private let stackView: NSStackView
    private var onChanged: (() -> Void)?

    init(onChanged: (() -> Void)? = nil) {
        self.onChanged = onChanged

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 340),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Manage Registries"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 250)

        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        super.init()

        let cv = window.contentView!

        let addBtn = NSButton(title: "Add Registry...", target: self, action: #selector(addRegistry))
        addBtn.bezelStyle = .rounded
        addBtn.controlSize = .small
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(addBtn)

        let doneBtn = NSButton(title: "Done", target: self, action: #selector(doDone))
        doneBtn.bezelStyle = .rounded
        doneBtn.controlSize = .small
        doneBtn.translatesAutoresizingMaskIntoConstraints = false
        cv.addSubview(doneBtn)

        cv.addSubview(scrollView)
        scrollView.documentView = stackView

        let clipView = scrollView.contentView
        NSLayoutConstraint.activate([
            addBtn.topAnchor.constraint(equalTo: cv.topAnchor, constant: 10),
            addBtn.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 12),
            doneBtn.topAnchor.constraint(equalTo: cv.topAnchor, constant: 10),
            doneBtn.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: addBtn.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: clipView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
        ])

        rebuildList()
    }

    private func rebuildList() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let urls = SoundPackManager.shared.customManifestURLs()
        if urls.isEmpty {
            let empty = NSTextField(labelWithString: "  No custom registries added.")
            empty.font = .systemFont(ofSize: 12)
            empty.textColor = .secondaryLabelColor
            empty.translatesAutoresizingMaskIntoConstraints = false
            let wrapper = NSView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(empty)
            NSLayoutConstraint.activate([
                wrapper.heightAnchor.constraint(equalToConstant: 30),
                empty.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 14),
                empty.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
            ])
            stackView.addArrangedSubview(wrapper)
            wrapper.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        } else {
            for urlStr in urls {
                let row = NSView()
                row.translatesAutoresizingMaskIntoConstraints = false

                let label = NSTextField(labelWithString: urlStr)
                label.font = .systemFont(ofSize: 12)
                label.lineBreakMode = .byTruncatingMiddle
                label.translatesAutoresizingMaskIntoConstraints = false
                row.addSubview(label)

                let removeBtn = NSButton(title: "Remove", target: self, action: #selector(removeRegistry(_:)))
                removeBtn.bezelStyle = .rounded
                removeBtn.controlSize = .small
                removeBtn.identifier = NSUserInterfaceItemIdentifier(urlStr)
                removeBtn.translatesAutoresizingMaskIntoConstraints = false
                row.addSubview(removeBtn)

                let sep = NSBox()
                sep.boxType = .separator
                sep.translatesAutoresizingMaskIntoConstraints = false
                row.addSubview(sep)

                NSLayoutConstraint.activate([
                    row.heightAnchor.constraint(equalToConstant: 36),
                    label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
                    label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                    label.trailingAnchor.constraint(lessThanOrEqualTo: removeBtn.leadingAnchor, constant: -8),
                    removeBtn.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
                    removeBtn.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                    sep.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
                    sep.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
                    sep.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                ])

                stackView.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            }
        }

        // Spacer
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(spacer)
    }

    @objc private func addRegistry() {
        let alert = NSAlert()
        alert.messageText = "Add Registry URL"
        alert.informativeText = "Enter the URL of a sound pack manifest (JSON):"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 350, height: 24))
        field.placeholderString = "https://example.com/sound-packs.json"
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let url = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        SoundPackManager.shared.addCustomManifestURL(url)
        rebuildList()
        onChanged?()
    }

    @objc private func removeRegistry(_ sender: NSButton) {
        guard let url = sender.identifier?.rawValue else { return }
        SoundPackManager.shared.removeCustomManifestURL(url)
        rebuildList()
        onChanged?()
    }

    @objc private func doDone() {
        window.close()
    }
}
