import Cocoa

// MARK: - Hook Installer

class HookInstaller {
    static let shared = HookInstaller()

    let hooksDir: String
    let hookScriptPath: String
    let settingsFile: String

    private init() {
        hooksDir = (NSHomeDirectory() as NSString).appendingPathComponent(".claude/hooks")
        hookScriptPath = (hooksDir as NSString).appendingPathComponent("claude-sounds.sh")
        settingsFile = (NSHomeDirectory() as NSString).appendingPathComponent(".claude/settings.json")
    }

    static let hookScriptContent = """
#!/bin/bash
# Claude Sounds - Generic hook script
# Reads active pack from ~/.claude/sounds/.active-pack

SOUNDS_DIR="$HOME/.claude/sounds"
ACTIVE_PACK_FILE="$SOUNDS_DIR/.active-pack"
MUTE_FILE="$SOUNDS_DIR/.muted"
VOLUME_FILE="$SOUNDS_DIR/.volume"

# Exit early if muted
[ -f "$MUTE_FILE" ] && exit 0

# Read active pack
[ ! -f "$ACTIVE_PACK_FILE" ] && exit 0
PACK=$(cat "$ACTIVE_PACK_FILE" | tr -d '[:space:]')
[ -z "$PACK" ] && exit 0

# Read volume (default 0.50)
VOLUME="0.50"
[ -f "$VOLUME_FILE" ] && VOLUME=$(cat "$VOLUME_FILE" | tr -d '[:space:]')

INPUT=$(cat)
EVENT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('hook_event_name',''))" 2>/dev/null)

pick_random() {
  local dir="$1"
  local existing=()
  for f in "$dir"/*.wav "$dir"/*.mp3 "$dir"/*.aiff "$dir"/*.m4a "$dir"/*.ogg; do
    [ -e "$f" ] && existing+=("$f")
  done
  local count=${#existing[@]}
  [ "$count" -eq 0 ] && return
  local idx=$((RANDOM % count))
  echo "${existing[$idx]}"
}

play() {
  local file="$1"
  [ -z "$file" ] && return
  python3 -c "
import subprocess
subprocess.Popen(
  ['/usr/bin/afplay', '-v', '$VOLUME', '$file'],
  start_new_session=True,
  stdin=subprocess.DEVNULL,
  stdout=subprocess.DEVNULL,
  stderr=subprocess.DEVNULL
)
"
}

PACK_DIR="$SOUNDS_DIR/$PACK"

case "$EVENT" in
  SessionStart)
    play "$(pick_random "$PACK_DIR/session-start")"
    ;;
  UserPromptSubmit)
    play "$(pick_random "$PACK_DIR/prompt-submit")"
    ;;
  Notification)
    play "$(pick_random "$PACK_DIR/notification")"
    ;;
  Stop)
    play "$(pick_random "$PACK_DIR/stop")"
    ;;
  SessionEnd)
    play "$(pick_random "$PACK_DIR/session-end")"
    ;;
  SubagentStop)
    play "$(pick_random "$PACK_DIR/subagent-stop")"
    ;;
  PostToolUseFailure)
    play "$(pick_random "$PACK_DIR/tool-failure")"
    ;;
esac

exit 0
"""

    func isHookInstalled() -> Bool {
        FileManager.default.fileExists(atPath: hookScriptPath)
    }

    @discardableResult
    func install() -> Bool {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)

        // Write hook script
        do {
            try HookInstaller.hookScriptContent.write(toFile: hookScriptPath, atomically: true, encoding: .utf8)
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/chmod")
            proc.arguments = ["+x", hookScriptPath]
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return false
        }

        return mergeHookSettings()
    }

    private func mergeHookSettings() -> Bool {
        let fm = FileManager.default

        // Backup existing settings
        if fm.fileExists(atPath: settingsFile) {
            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd-HHmmss"
            let backup = settingsFile + ".backup-\(df.string(from: Date()))"
            try? fm.copyItem(atPath: settingsFile, toPath: backup)
        }

        // Read existing
        var settings: [String: Any] = [:]
        if let data = fm.contents(atPath: settingsFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        let cmd = "\"$HOME/.claude/hooks/claude-sounds.sh\""
        let standardEntry: [String: Any] = [
            "hooks": [["type": "command", "command": cmd, "async": true] as [String: Any]]
        ]
        let notificationEntry: [String: Any] = [
            "matcher": "permission_prompt",
            "hooks": [["type": "command", "command": cmd, "async": true] as [String: Any]]
        ]

        let events: [(String, [String: Any])] = [
            ("SessionStart", standardEntry),
            ("UserPromptSubmit", standardEntry),
            ("Stop", standardEntry),
            ("Notification", notificationEntry),
            ("SubagentStop", standardEntry),
            ("PostToolUseFailure", standardEntry),
            ("SessionEnd", standardEntry),
        ]

        for (eventName, entry) in events {
            var eventHooks = hooks[eventName] as? [[String: Any]] ?? []

            // Remove old pack-specific script references
            eventHooks.removeAll { hookGroup in
                guard let arr = hookGroup["hooks"] as? [[String: Any]] else { return false }
                return arr.contains { h in
                    guard let c = h["command"] as? String else { return false }
                    return c.contains("protoss-sounds.sh") || c.contains("peon-sounds.sh")
                }
            }

            // Skip if claude-sounds.sh already present
            let present = eventHooks.contains { hookGroup in
                guard let arr = hookGroup["hooks"] as? [[String: Any]] else { return false }
                return arr.contains { ($0["command"] as? String)?.contains("claude-sounds.sh") == true }
            }

            if !present {
                eventHooks.append(entry)
            }

            hooks[eventName] = eventHooks
        }

        settings["hooks"] = hooks

        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) else {
            return false
        }

        do {
            try data.write(to: URL(fileURLWithPath: settingsFile))
            return true
        } catch {
            return false
        }
    }
}
