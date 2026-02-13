import Cocoa

// MARK: - Data Models

enum ClaudeEvent: String, CaseIterable {
    case sessionStart = "session-start"
    case promptSubmit = "prompt-submit"
    case notification = "notification"
    case stop = "stop"
    case sessionEnd = "session-end"
    case subagentStop = "subagent-stop"
    case toolFailure = "tool-failure"

    var displayName: String {
        switch self {
        case .sessionStart: return "Session Start"
        case .promptSubmit: return "Prompt Submit"
        case .notification: return "Notification"
        case .stop: return "Stop"
        case .sessionEnd: return "Session End"
        case .subagentStop: return "Subagent Stop"
        case .toolFailure: return "Tool Failure"
        }
    }

    var hookEventName: String {
        switch self {
        case .sessionStart: return "SessionStart"
        case .promptSubmit: return "UserPromptSubmit"
        case .notification: return "Notification"
        case .stop: return "Stop"
        case .sessionEnd: return "SessionEnd"
        case .subagentStop: return "SubagentStop"
        case .toolFailure: return "PostToolUseFailure"
        }
    }
}

struct SoundPackInfo: Codable {
    let id: String
    let name: String
    let description: String
    let version: String
    let author: String
    let downloadUrl: String?
    let size: String
    let fileCount: Int
    let previewUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, version, author, size
        case downloadUrl = "download_url"
        case fileCount = "file_count"
        case previewUrl = "preview_url"
    }
}

struct SoundPackManifest: Codable {
    let version: String
    let packs: [SoundPackInfo]
}

// MARK: - Outline View Models

class EventItem {
    let event: ClaudeEvent
    var soundFiles: [SoundFileItem] = []

    init(event: ClaudeEvent) {
        self.event = event
    }
}

class SoundFileItem {
    let path: String
    let filename: String
    let isSkipped: Bool
    weak var parent: EventItem?

    init(path: String, parent: EventItem) {
        self.path = path
        self.isSkipped = path.hasSuffix(".disabled")
        self.filename = {
            let name = (path as NSString).lastPathComponent
            return name.hasSuffix(".disabled") ? String(name.dropLast(".disabled".count)) : name
        }()
        self.parent = parent
    }
}
