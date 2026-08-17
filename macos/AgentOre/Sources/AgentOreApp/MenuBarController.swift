import AgentOreCore
import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let coordinator: AgentOreCoordinator
    private let statusItem: NSStatusItem
    private var timer: Timer?
    private var activity = "Starting…"

    init(coordinator: AgentOreCoordinator) {
        self.coordinator = coordinator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.title = "⛏"
        statusItem.button?.toolTip = "AgentOre"
        rebuildMenu()
        refreshAndMaybeSubmit()

        timer = Timer.scheduledTimer(
            timeInterval: 60,
            target: self,
            selector: #selector(timerDidFire),
            userInfo: nil,
            repeats: true
        )
    }

    deinit {
        timer?.invalidate()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: "AgentOre", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        menu.addItem(disabledItem("Usage: \(formatted(coordinator.usage.totalTokens)) tokens"))
        menu.addItem(disabledItem("Sessions: \(coordinator.usage.sessionCount)"))
        menu.addItem(disabledItem("Wallet: \(shortAddress(coordinator.walletAddress))"))
        menu.addItem(disabledItem("Status: \(activity)"))

        menu.addItem(.separator())
        menu.addItem(actionItem("Refresh Now", #selector(refreshNow), key: "r"))
        menu.addItem(actionItem("Submit Now", #selector(submitNow), key: "s"))
        menu.addItem(actionItem("Finalize Previous Epoch", #selector(finalizePreviousEpoch), key: "f"))
        menu.addItem(actionItem("Copy Wallet Address", #selector(copyAddress), key: ""))
        menu.addItem(actionItem("Open AgentOre Folder", #selector(openDataFolder), key: ""))

        menu.addItem(.separator())
        menu.addItem(actionItem("Quit AgentOre", #selector(quit), key: "q"))

        statusItem.menu = menu
    }

    private func refreshAndMaybeSubmit() {
        activity = "Refreshing"
        rebuildMenu()

        Task {
            do {
                _ = try coordinator.refresh()
                if let hash = try await coordinator.autoSubmitIfNeeded() {
                    activity = "Submitted \(shortHash(hash))"
                } else {
                    activity = coordinator.configuration.isChainConfigured
                        ? "Ready"
                        : "Configure contract"
                }
            } catch {
                activity = error.localizedDescription
            }
            rebuildMenu()
        }
    }

    @objc private func refreshNow() {
        refreshAndMaybeSubmit()
    }

    @objc private func timerDidFire() {
        refreshAndMaybeSubmit()
    }

    @objc private func submitNow() {
        activity = "Submitting"
        rebuildMenu()
        Task {
            do {
                let hash = try await coordinator.submitNow()
                activity = "Submitted \(shortHash(hash))"
            } catch {
                activity = error.localizedDescription
            }
            rebuildMenu()
        }
    }

    @objc private func finalizePreviousEpoch() {
        activity = "Finalizing"
        rebuildMenu()
        Task {
            do {
                let hash = try await coordinator.finalizePreviousEpoch()
                activity = "Finalized \(shortHash(hash))"
            } catch {
                activity = error.localizedDescription
            }
            rebuildMenu()
        }
    }

    @objc private func copyAddress() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(coordinator.walletAddress, forType: .string)
        activity = "Address copied"
        rebuildMenu()
    }

    @objc private func openDataFolder() {
        NSWorkspace.shared.open(coordinator.paths.root)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func formatted(_ value: UInt64) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    private func shortAddress(_ value: String) -> String {
        guard value.count > 12 else { return value }
        return "\(value.prefix(8))…\(value.suffix(4))"
    }

    private func shortHash(_ value: String) -> String {
        guard value.count > 12 else { return value }
        return "\(value.prefix(10))…"
    }
}
