# Claude Sounds — Project Guide

## Overview

macOS menu bar app that plays custom audio cues for Claude Code events. Built as a single-target Swift app compiled with `swiftc` (no Xcode project).

## Build

```bash
./build.sh          # Builds ClaudeSounds.app
open ClaudeSounds.app
```

Requires macOS + Xcode Command Line Tools. All Swift sources are in `Sources/`. The build compiles them all in one `swiftc` invocation.

## Architecture

| File | Purpose |
|------|---------|
| `Sources/main.swift` | App entry point |
| `Sources/AppDelegate.swift` | Menu bar UI, event wiring |
| `Sources/SoundPackManager.swift` | Pack install/uninstall/export, manifest fetching, ZIP extraction |
| `Sources/AudioValidator.swift` | Magic-byte validation, ZIP preflight, post-extract sanitization |
| `Sources/PackBrowserController.swift` | Browse/download/publish packs window |
| `Sources/EventEditorController.swift` | Per-event sound editor with drag-drop |
| `Sources/PublishPackController.swift` | Export ZIP / submit pack to community |
| `Sources/WindowManager.swift` | Singleton window lifecycle manager |
| `Sources/Models.swift` | `ClaudeEvent`, `SoundPackInfo`, `SoundPackManifest` |
| `Sources/HookInstaller.swift` | Installs Claude Code shell hooks |
| `Sources/SetupWizardController.swift` | First-run setup flow |
| `Sources/InstallURLController.swift` | Install from URL dialog |
| `Sources/NewPackController.swift` | Create new pack dialog |
| `Sources/ManageRegistriesController.swift` | Custom manifest registry management |

## Sound pack structure

Packs live at `~/.claude/sounds/<pack-id>/` with one subdirectory per `ClaudeEvent`:

```
<pack-id>/
  session-start/
  prompt-submit/
  notification/
  stop/
  session-end/
  subagent-stop/
  tool-failure/
```

Allowed audio formats: `.wav`, `.mp3`, `.aiff`, `.m4a`, `.ogg`, `.aac`. Max 10 MB per file. All files are validated by magic bytes (not just extension).

## Releasing a new community pack

### From raw audio files

1. Organize files into the event directory structure under a temp folder named `<pack-id>/`
2. Create the ZIP: `cd /tmp && zip -r <pack-id>.zip <pack-id>/`
3. Upload to the `v2.0` GitHub release: `gh release upload v2.0 /tmp/<pack-id>.zip --clobber`
4. Add an entry to `community/manifest.json`:
   ```json
   {
     "id": "<pack-id>",
     "name": "Human Readable Name",
     "description": "Short description",
     "version": "1.0",
     "author": "Author Name",
     "download_url": "https://github.com/michalarent/claude-sounds/releases/download/v2.0/<pack-id>.zip",
     "size": "X.X MB",
     "file_count": N,
     "preview_url": null
   }
   ```
5. Update `community/README.md` — add a row to the "Available packs" table
6. Commit and push

### From a locally installed pack

If the pack already exists at `~/.claude/sounds/<pack-id>/`:

1. Create the ZIP from the sounds directory: `cd ~/.claude/sounds && zip -r /tmp/<pack-id>.zip <pack-id>/`
2. Upload: `gh release upload v2.0 /tmp/<pack-id>.zip --clobber`
3. Update `community/manifest.json` and `community/README.md` as above
4. Commit and push

### From a source ZIP (e.g. downloaded sound rips)

Source ZIPs often have flat file lists without event directories. You need to:

1. Extract to a temp directory
2. Map files to events (use your judgment — opening lines to `session-start`, fail sounds to `tool-failure`, etc.)
3. Create the pack directory structure and copy files in
4. ZIP and release as above

## Validation

All packs are validated at every entry point:

- **ZIP preflight** (`AudioValidator.preflightZip`): Rejects path traversal (`../`), absolute paths, symlinks, nesting > 3 levels
- **Post-extract sanitization** (`AudioValidator.sanitizeExtractedPack`): Removes files that aren't valid audio (by magic bytes), wrong depth, wrong extension, oversized, or symlinks
- **Single-file validation** (`AudioValidator.validateSingleFile`): Used for drag-drop and add-sound flows
- **CI validation** (`scripts/validate-pack.sh`): Runs on PRs touching `community/manifest.json` and during release workflow

To validate a pack ZIP manually: `bash scripts/validate-pack.sh <zip-path> <pack-id>`

## CI workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `validate-community-pack.yml` | PRs touching `community/manifest.json` | Downloads and validates every pack in the manifest |
| `release-community-packs.yml` | Push to `main` touching `community/manifest.json` | Re-hosts pack ZIPs under official releases, updates download URLs |

## Branch protection

`main` is protected:
- PRs require 1 approving review from `@michalarent` (CODEOWNERS)
- Status check `validate` must pass
- Repo owner can bypass for direct pushes

## Common tasks

**Add a new Swift source file**: Create it in `Sources/`, it's automatically included in the build via `Sources/*.swift` glob.

**Add a new event type**: Update `ClaudeEvent` enum in `Models.swift`. All event iteration uses `ClaudeEvent.allCases`, so new events propagate automatically to pack creation, validation, and the editor UI.

**Update the embedded fallback manifest**: Edit `embeddedManifest()` in `SoundPackManager.swift`. This is only used when the remote manifest can't be fetched.

**Test the app**: `./build.sh && open ClaudeSounds.app`. No unit test suite — test manually by installing packs, dragging files, and verifying sounds play.
