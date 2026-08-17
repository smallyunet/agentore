import AppKit
import AgentOreCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let coordinator = try AgentOreCoordinator()
            menuBarController = MenuBarController(coordinator: coordinator)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "AgentOre could not start"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApplication.shared.terminate(nil)
        }
    }
}

