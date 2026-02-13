import Cocoa

// MARK: - Edit Pack Controller

class EditPackController: NSObject {
    let window: NSWindow
    private let nameField: NSTextField
    private let descField: NSTextField
    private let authorField: NSTextField
    private let versionField: NSTextField
    private let packId: String
    private var onSaved: (() -> Void)?

    init(packId: String, onSaved: (() -> Void)? = nil) {
        self.packId = packId
        self.onSaved = onSaved

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "Edit Pack: \(packId)"
        window.center()
        window.isReleasedWhenClosed = false

        nameField = NSTextField()
        descField = NSTextField()
        authorField = NSTextField()
        versionField = NSTextField()

        super.init()

        let contentView = window.contentView!
        var yOffset: CGFloat = 200

        func addRow(label: String, field: NSTextField) {
            let lbl = NSTextField(labelWithString: label)
            lbl.font = .systemFont(ofSize: 12, weight: .medium)
            lbl.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(lbl)

            field.translatesAutoresizingMaskIntoConstraints = false
            field.font = .systemFont(ofSize: 12)
            contentView.addSubview(field)

            NSLayoutConstraint.activate([
                lbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                lbl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: CGFloat(240) - yOffset),
                lbl.widthAnchor.constraint(equalToConstant: 90),
                field.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 8),
                field.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
                field.centerYAnchor.constraint(equalTo: lbl.centerYAnchor),
            ])
            yOffset -= 36
        }

        addRow(label: "Name:", field: nameField)
        addRow(label: "Description:", field: descField)
        addRow(label: "Author:", field: authorField)
        addRow(label: "Version:", field: versionField)

        nameField.placeholderString = packId.capitalized
        descField.placeholderString = "(optional)"
        authorField.placeholderString = "(optional)"
        versionField.placeholderString = "1.0"

        // Load existing metadata
        let meta = SoundPackManager.shared.loadPackMetadata(id: packId)
        nameField.stringValue = meta?["name"] ?? ""
        descField.stringValue = meta?["description"] ?? ""
        authorField.stringValue = meta?["author"] ?? ""
        versionField.stringValue = meta?["version"] ?? ""

        // Buttons
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.bezelStyle = .rounded
        contentView.addSubview(cancelBtn)

        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        contentView.addSubview(saveBtn)

        NSLayoutConstraint.activate([
            saveBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            saveBtn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            cancelBtn.trailingAnchor.constraint(equalTo: saveBtn.leadingAnchor, constant: -8),
            cancelBtn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])
    }

    @objc private func cancel() {
        window.close()
    }

    @objc private func save() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = descField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = authorField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let version = versionField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        SoundPackManager.shared.savePackConfig(
            id: packId,
            name: name.isEmpty ? packId.capitalized : name,
            description: desc,
            author: author,
            version: version.isEmpty ? "1.0" : version
        )

        window.close()
        onSaved?()
    }
}
