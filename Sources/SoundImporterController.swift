import Cocoa

// MARK: - Sound Importer

class ImportedFile {
    let url: URL
    let filename: String
    var assignedEvent: ClaudeEvent

    init(url: URL, assignedEvent: ClaudeEvent = .sessionStart) {
        self.url = url
        self.filename = url.lastPathComponent
        self.assignedEvent = assignedEvent
    }
}

class SoundImporterController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let window: NSWindow
    private var tableView: NSTableView!
    private var packPopup: NSPopUpButton!
    private var countLabel: NSTextField!
    private var importButton: NSButton!
    private var importedFiles: [ImportedFile] = []
    private var previewProcess: Process?
    var onImported: (() -> Void)?

    init(onImported: (() -> Void)? = nil) {
        self.onImported = onImported

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false
        )
        window.title = "Import Sounds"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 500, height: 350)

        super.init()

        let contentView = window.contentView!

        // Top bar: Pack selector + Add Files button
        let packLabel = NSTextField(labelWithString: "Pack:")
        packLabel.font = .systemFont(ofSize: 12)
        packLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(packLabel)

        packPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        packPopup.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(packPopup)

        let addBtn = NSButton(title: "Add Files...", target: self, action: #selector(addFiles))
        addBtn.bezelStyle = .rounded
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addBtn)

        // Table view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        tableView = NSTableView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 30
        tableView.dataSource = self
        tableView.delegate = self

        let fileCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        fileCol.title = "File"
        fileCol.minWidth = 150
        fileCol.width = 220
        tableView.addTableColumn(fileCol)

        let eventCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("event"))
        eventCol.title = "Event"
        eventCol.minWidth = 130
        eventCol.width = 180
        tableView.addTableColumn(eventCol)

        let actionsCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("actions"))
        actionsCol.title = ""
        actionsCol.width = 70
        actionsCol.minWidth = 60
        actionsCol.maxWidth = 90
        tableView.addTableColumn(actionsCol)

        tableView.registerForDraggedTypes([.fileURL])

        scrollView.documentView = tableView

        // Drop hint
        let hint = NSTextField(labelWithString: "Drop audio files here to add them")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.alignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hint)

        // Bottom bar: count label + import button
        countLabel = NSTextField(labelWithString: "0 files")
        countLabel.font = .systemFont(ofSize: 12)
        countLabel.textColor = .secondaryLabelColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countLabel)

        importButton = NSButton(title: "Import to Pack", target: self, action: #selector(importToPack))
        importButton.bezelStyle = .rounded
        importButton.translatesAutoresizingMaskIntoConstraints = false
        importButton.isEnabled = false
        contentView.addSubview(importButton)

        NSLayoutConstraint.activate([
            packLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            packLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            packPopup.leadingAnchor.constraint(equalTo: packLabel.trailingAnchor, constant: 6),
            packPopup.centerYAnchor.constraint(equalTo: packLabel.centerYAnchor),
            packPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            addBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            addBtn.centerYAnchor.constraint(equalTo: packLabel.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: packLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: hint.topAnchor, constant: -4),

            hint.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hint.bottomAnchor.constraint(equalTo: countLabel.topAnchor, constant: -8),
            hint.heightAnchor.constraint(equalToConstant: 20),

            countLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            countLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            importButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            importButton.centerYAnchor.constraint(equalTo: countLabel.centerYAnchor),
        ])

        reloadPacks()
    }

    private func reloadPacks() {
        let installed = SoundPackManager.shared.installedPackIds()
        packPopup.removeAllItems()
        packPopup.addItems(withTitles: installed)

        let active = SoundPackManager.shared.activePackId() ?? installed.first ?? ""
        if let idx = installed.firstIndex(of: active) {
            packPopup.selectItem(at: idx)
        }
    }

    private func updateUI() {
        let count = importedFiles.count
        countLabel.stringValue = "\(count) file\(count == 1 ? "" : "s")"
        importButton.isEnabled = count > 0 && packPopup.selectedItem != nil
    }

    private func addValidFiles(from urls: [URL]) {
        for url in urls {
            if AudioValidator.validateSingleFile(at: url) {
                importedFiles.append(ImportedFile(url: url))
            }
        }
        tableView.reloadData()
        updateUI()
    }

    // MARK: Actions

    @objc func addFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            .init(filenameExtension: "wav")!,
            .init(filenameExtension: "mp3")!,
            .init(filenameExtension: "aiff")!,
            .init(filenameExtension: "m4a")!,
            .init(filenameExtension: "ogg")!,
            .init(filenameExtension: "aac")!,
        ]

        guard panel.runModal() == .OK else { return }
        addValidFiles(from: panel.urls)
    }

    @objc func importToPack() {
        guard let packId = packPopup.selectedItem?.title, !packId.isEmpty else { return }
        guard !importedFiles.isEmpty else { return }

        let fm = FileManager.default
        var copiedCount = 0

        for file in importedFiles {
            let destDir = (SoundPackManager.shared.soundsDir as NSString)
                .appendingPathComponent("\(packId)/\(file.assignedEvent.rawValue)")
            try? fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)

            let dest = (destDir as NSString).appendingPathComponent(file.filename)
            if !fm.fileExists(atPath: dest) {
                if (try? fm.copyItem(at: file.url, to: URL(fileURLWithPath: dest))) != nil {
                    copiedCount += 1
                }
            }
        }

        let alert = NSAlert()
        alert.messageText = "Import Complete"
        alert.informativeText = "Imported \(copiedCount) file\(copiedCount == 1 ? "" : "s") to \(packId)."
        alert.addButton(withTitle: "OK")
        alert.runModal()

        importedFiles.removeAll()
        tableView.reloadData()
        updateUI()

        window.close()
        onImported?()
    }

    @objc func eventChanged(_ sender: NSPopUpButton) {
        let row = tableView.row(for: sender)
        guard row >= 0, row < importedFiles.count else { return }
        if let event = ClaudeEvent.allCases.first(where: { $0.displayName == sender.titleOfSelectedItem }) {
            importedFiles[row].assignedEvent = event
        }
    }

    @objc func playFile(_ sender: NSButton) {
        let row = tableView.row(for: sender)
        guard row >= 0, row < importedFiles.count else { return }
        playAudio(importedFiles[row].url.path)
    }

    @objc func removeFile(_ sender: NSButton) {
        let row = tableView.row(for: sender)
        guard row >= 0, row < importedFiles.count else { return }
        importedFiles.remove(at: row)
        tableView.reloadData()
        updateUI()
    }

    private func playAudio(_ path: String) {
        if let proc = previewProcess, proc.isRunning { proc.terminate() }

        let vol = (try? String(contentsOfFile:
            (NSHomeDirectory() as NSString).appendingPathComponent(".claude/sounds/.volume"),
            encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0.50"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        proc.arguments = ["-v", vol, path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        previewProcess = proc
    }

    // MARK: NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return importedFiles.count
    }

    // Drag-and-drop
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo,
                   proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        return .copy
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo,
                   row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]) as? [URL] else { return false }
        let validUrls = urls.filter { AudioValidator.validateSingleFile(at: $0) }
        guard !validUrls.isEmpty else { return false }
        addValidFiles(from: validUrls)
        return true
    }

    // MARK: NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < importedFiles.count else { return nil }
        let file = importedFiles[row]
        let colId = tableColumn?.identifier.rawValue ?? ""

        if colId == "file" {
            let cell = NSTextField(labelWithString: file.filename)
            cell.font = .systemFont(ofSize: 12)
            cell.lineBreakMode = .byTruncatingMiddle
            return cell
        }

        if colId == "event" {
            let popup = NSPopUpButton(frame: .zero, pullsDown: false)
            for event in ClaudeEvent.allCases {
                popup.addItem(withTitle: event.displayName)
            }
            if let idx = ClaudeEvent.allCases.firstIndex(of: file.assignedEvent) {
                popup.selectItem(at: idx)
            }
            popup.target = self
            popup.action = #selector(eventChanged(_:))
            popup.font = .systemFont(ofSize: 11)
            return popup
        }

        if colId == "actions" {
            let container = NSStackView()
            container.orientation = .horizontal
            container.spacing = 4

            let playBtn = NSButton(image: NSImage(systemSymbolName: "play.fill",
                accessibilityDescription: "Play")!, target: self,
                action: #selector(playFile(_:)))
            playBtn.bezelStyle = .inline
            playBtn.isBordered = false

            let removeBtn = NSButton(image: NSImage(systemSymbolName: "xmark",
                accessibilityDescription: "Remove")!, target: self,
                action: #selector(removeFile(_:)))
            removeBtn.bezelStyle = .inline
            removeBtn.isBordered = false
            removeBtn.contentTintColor = .systemRed

            container.addArrangedSubview(playBtn)
            container.addArrangedSubview(removeBtn)
            return container
        }

        return nil
    }
}
