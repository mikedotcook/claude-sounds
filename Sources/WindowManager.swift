import Cocoa

// MARK: - Window Manager

class WindowManager {
    static let shared = WindowManager()

    private var packBrowserWindow: NSWindow?
    private var eventEditorWindow: NSWindow?
    private var setupWizardWindow: NSWindow?

    private var packBrowserController: PackBrowserController?
    private var eventEditorController: EventEditorController?
    private var wizardController: SetupWizardController?

    func showPackBrowser() {
        if let w = packBrowserWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let ctrl = PackBrowserController()
        let w = ctrl.window
        packBrowserWindow = w
        packBrowserController = ctrl
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showEventEditor() {
        if let w = eventEditorWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let ctrl = EventEditorController()
        let w = ctrl.window
        eventEditorWindow = w
        eventEditorController = ctrl
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var newPackWindow: NSWindow?
    private var newPackController: NewPackController?

    func showNewPack(onCreated: (() -> Void)? = nil) {
        if let w = newPackWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let ctrl = NewPackController(onCreated: onCreated)
        let w = ctrl.window
        newPackWindow = w
        newPackController = ctrl
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSetupWizard(completion: (() -> Void)? = nil) {
        if let w = setupWizardWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let ctrl = SetupWizardController(completion: completion)
        let w = ctrl.window
        setupWizardWindow = w
        wizardController = ctrl
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
