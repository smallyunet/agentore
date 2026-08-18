import AgentOreCore
import AppKit

private enum ActivityTone {
    case informational
    case warning
    case error
}

@MainActor
final class MenuBarController: NSObject {
    private static let networkRefreshInterval: TimeInterval = 300

    private let coordinator: AgentOreCoordinator
    private let statusItem: NSStatusItem
    private let dashboardView: DashboardMenuView
    private var timer: Timer?
    private var activity = "Starting…"
    private var activityTone = ActivityTone.informational
    private var isRefreshing = false
    private var nextAutomaticAttemptAt = Date()
    private var submitMenuItem: NSMenuItem?
    private var finalizeMenuItem: NSMenuItem?
    private var submissionAttentionMessage: String?

    init(coordinator: AgentOreCoordinator) {
        self.coordinator = coordinator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.dashboardView = DashboardMenuView(brandImage: Self.brandImage())
        super.init()

        dashboardView.onCopyWalletAddress = { [weak self] in
            self?.copyAddress()
        }
        configureStatusItem()
        configureMenu()
        render()
        refreshAndMaybeSubmit()

        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(timerDidFire),
            userInfo: nil,
            repeats: true
        )
        timer?.tolerance = 0.1
    }

    deinit {
        timer?.invalidate()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = Self.brandImage()
        button.image?.size = NSSize(width: 18, height: 18)
        button.imagePosition = .imageLeading
        button.title = "—"
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.toolTip = "AgentOre token usage"
        button.setAccessibilityLabel("AgentOre token usage")
    }

    private func configureMenu() {
        let menu = NSMenu()

        let dashboardItem = NSMenuItem()
        dashboardItem.view = dashboardView
        menu.addItem(dashboardItem)
        menu.addItem(.separator())
        menu.addItem(actionItem("Refresh Now", #selector(refreshNow), key: "r"))
        let submitItem = actionItem("Submit Now", #selector(submitNow), key: "s")
        submitMenuItem = submitItem
        menu.addItem(submitItem)
        let finalizeItem = actionItem(
            "Finalize Previous Epoch",
            #selector(finalizePreviousEpoch),
            key: "f"
        )
        finalizeMenuItem = finalizeItem
        menu.addItem(finalizeItem)
        menu.addItem(.separator())
        menu.addItem(actionItem("Copy Wallet Address", #selector(copyAddress), key: ""))
        menu.addItem(actionItem("View Contract on BaseScan", #selector(openContract), key: ""))
        menu.addItem(actionItem("Open AgentOre Folder", #selector(openDataFolder), key: ""))
        menu.addItem(.separator())
        menu.addItem(actionItem("Quit AgentOre", #selector(quit), key: "q"))

        statusItem.menu = menu
    }

    private func render() {
        if coordinator.usage.totalTokens == 0 || coordinator.chainSnapshot == nil {
            statusItem.button?.title = "—"
        } else if coordinator.chainSnapshot?.registered == false {
            statusItem.button?.title = "Setup"
        } else if let pendingMiningTokens = coordinator.pendingMiningTokens {
            statusItem.button?.title = compact(pendingMiningTokens)
        } else {
            statusItem.button?.title = "—"
        }
        statusItem.button?.toolTip = "Pending AgentOre mining weight"
        let chain = coordinator.chainSnapshot
        let submissionNeedsAttention = submissionAttentionMessage != nil
            && chain?.submittedThisEpoch != true
        submitMenuItem?.badge = submissionNeedsAttention ? attentionBadge() : nil
        submitMenuItem?.isEnabled = !isRefreshing
            && chain?.hasGasBalance == true
            && chain?.submittedThisEpoch != true
        if let submissionAttentionMessage, submissionNeedsAttention {
            submitMenuItem?.toolTip = "Action required: \(submissionAttentionMessage)"
        } else if chain?.hasGasBalance == false {
            submitMenuItem?.toolTip = "Add Base ETH to the local wallet before submitting."
        } else {
            submitMenuItem?.toolTip = nil
        }

        let previousEpochNeedsFinalization = chain?.previousEpochNeedsFinalization == true
        finalizeMenuItem?.badge = previousEpochNeedsFinalization ? attentionBadge() : nil
        finalizeMenuItem?.isEnabled = !isRefreshing
            && previousEpochNeedsFinalization
            && chain?.hasGasBalance == true
        if previousEpochNeedsFinalization, let previousEpoch = chain?.previousEpoch {
            finalizeMenuItem?.toolTip = chain?.hasGasBalance == true
                ? "Epoch \(previousEpoch) has mining weight and is ready to finalize."
                : "Add Base ETH to finalize Epoch \(previousEpoch)."
        } else if let chain, chain.previousEpoch == nil {
            finalizeMenuItem?.toolTip = "No previous epoch exists yet."
        } else if chain?.previousEpochFinalized == true {
            finalizeMenuItem?.toolTip = "The previous epoch is already finalized."
        } else if chain?.previousEpochHasWeight == false {
            finalizeMenuItem?.toolTip = "The previous epoch has no mining weight to settle."
        } else {
            finalizeMenuItem?.toolTip = nil
        }
        dashboardView.update(
            usage: coordinator.usage,
            walletAddress: coordinator.walletAddress,
            chain: coordinator.chainSnapshot,
            autoSubmit: coordinator.configuration.autoSubmit,
            nextAutomaticAttemptAt: nextAutomaticAttemptAt,
            activity: activity,
            activityTone: activityTone
        )
    }

    private func refreshAndMaybeSubmit() {
        guard !isRefreshing else { return }
        isRefreshing = true
        nextAutomaticAttemptAt = Date().addingTimeInterval(Self.networkRefreshInterval)
        activity = "Refreshing account and Base data…"
        activityTone = .informational
        render()

        Task {
            do {
                async let usage: UsageSnapshot = coordinator.refresh()
                async let chain: ChainSnapshot = coordinator.refreshChain()
                _ = try await (usage, chain)

                do {
                    switch try await coordinator.autoSubmitIfNeeded() {
                    case let .submitted(hash):
                        activity = "Submitted \(shortHash(hash))"
                        activityTone = .informational
                        submissionAttentionMessage = nil
                    case .waitingForGas:
                        activity = "Action needed: Add Base ETH for automatic submission."
                        activityTone = .warning
                        submissionAttentionMessage = "Add Base ETH for automatic submission."
                    case .alreadySubmitted:
                        activity = "Automatic submission active"
                        activityTone = .informational
                        submissionAttentionMessage = nil
                    case .disabled:
                        activity = "Automatic submission disabled"
                        activityTone = .informational
                        submissionAttentionMessage = nil
                    }
                } catch {
                    activity = AgentOreError.userFacingMessage(for: error)
                    activityTone = .error
                    if coordinator.chainSnapshot?.submittedThisEpoch == false {
                        submissionAttentionMessage = activity
                    }
                }
            } catch {
                activity = AgentOreError.userFacingMessage(for: error)
                activityTone = .error
            }
            scheduleNextAttempt()
            isRefreshing = false
            render()
        }
    }

    @objc private func refreshNow() {
        nextAutomaticAttemptAt = Date()
        refreshAndMaybeSubmit()
    }

    @objc private func timerDidFire() {
        if Date() >= nextAutomaticAttemptAt {
            refreshAndMaybeSubmit()
        } else {
            render()
        }
    }

    @objc private func submitNow() {
        guard !isRefreshing else { return }
        isRefreshing = true
        activity = "Submitting usage…"
        activityTone = .informational
        render()
        Task {
            do {
                let hash = try await coordinator.submitNow()
                activity = "Submitted \(shortHash(hash))"
                activityTone = .informational
                submissionAttentionMessage = nil
            } catch {
                activity = AgentOreError.userFacingMessage(for: error)
                activityTone = .error
                submissionAttentionMessage = activity
            }
            scheduleNextAttempt()
            isRefreshing = false
            render()
        }
    }

    @objc private func finalizePreviousEpoch() {
        guard !isRefreshing else { return }
        isRefreshing = true
        activity = "Finalizing previous epoch…"
        activityTone = .informational
        render()
        Task {
            do {
                let hash = try await coordinator.finalizePreviousEpoch()
                activity = "Finalized \(shortHash(hash))"
                activityTone = .informational
                _ = try? await coordinator.refreshChain()
            } catch {
                activity = AgentOreError.userFacingMessage(for: error)
                activityTone = .error
            }
            isRefreshing = false
            render()
        }
    }

    @objc private func copyAddress() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(coordinator.walletAddress, forType: .string)
        activity = "Wallet address copied"
        activityTone = .informational
        render()
    }

    @objc private func openContract() {
        guard let url = URL(
            string: "https://basescan.org/address/\(coordinator.configuration.contractAddress)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openDataFolder() {
        NSWorkspace.shared.open(coordinator.paths.root)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func actionItem(_ title: String, _ action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func attentionBadge() -> NSMenuItemBadge {
        NSMenuItemBadge(string: "!")
    }

    private func scheduleNextAttempt() {
        let regularRefresh = Date().addingTimeInterval(Self.networkRefreshInterval)
        if let chain = coordinator.chainSnapshot,
           chain.submittedThisEpoch,
           chain.epochEndsAt > Date() {
            nextAutomaticAttemptAt = min(regularRefresh, chain.epochEndsAt)
        } else {
            nextAutomaticAttemptAt = regularRefresh
        }
    }

    private func compact(_ value: UInt64) -> String {
        let number = Double(value)
        let divisor: Double
        let suffix: String
        switch number {
        case 1_000_000_000...: (divisor, suffix) = (1_000_000_000, "B")
        case 1_000_000...: (divisor, suffix) = (1_000_000, "M")
        case 1_000...: (divisor, suffix) = (1_000, "K")
        default: return value.formatted(.number.grouping(.automatic))
        }

        let scaled = number / divisor
        return scaled.formatted(.number.precision(.fractionLength(scaled >= 100 ? 0 : 1))) + suffix
    }

    private func shortHash(_ value: String) -> String {
        guard value.count > 12 else { return value }
        return "\(value.prefix(10))…"
    }

    private static func brandImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AgentOreToken", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = false
            return image
        }
        return NSImage(systemSymbolName: "diamond.fill", accessibilityDescription: "AgentOre")
    }
}

@MainActor
private final class DashboardMenuView: NSView {
    private let miningWeightValue = NSTextField(labelWithString: "—")
    private let lifetimeValue = NSTextField(labelWithString: "Lifetime —")
    private let epochLabel = NSTextField(labelWithString: "Fetching epoch…")
    private let progress = NSProgressIndicator()
    private let countdownValue = NSTextField(labelWithString: "—")
    private let addressValue = CopyableAddressField()
    private let ethValue = NSTextField(labelWithString: "— ETH")
    private let tokenValue = NSTextField(labelWithString: "— AORE")
    private let statusValue = NSTextField(labelWithString: "Starting…")
    var onCopyWalletAddress: (() -> Void)?

    init(brandImage: NSImage?) {
        super.init(frame: NSRect(x: 0, y: 0, width: 336, height: 302))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 336).isActive = true
        heightAnchor.constraint(equalToConstant: 302).isActive = true

        let icon = NSImageView(image: brandImage ?? NSImage())
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 38),
            icon.heightAnchor.constraint(equalToConstant: 38)
        ])

        let title = label("AgentOre", size: 16, weight: .semibold)
        let subtitle = label("AORE · Base Mainnet", size: 11, color: .secondaryLabelColor)
        let heading = NSStackView(views: [title, subtitle])
        heading.orientation = .vertical
        heading.alignment = .leading
        heading.spacing = 1

        let header = NSStackView(views: [icon, heading])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10

        let usageCaption = label("PENDING MINING WEIGHT", size: 10, weight: .medium, color: .secondaryLabelColor)
        miningWeightValue.font = .monospacedDigitSystemFont(ofSize: 25, weight: .semibold)
        miningWeightValue.textColor = .labelColor
        lifetimeValue.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        lifetimeValue.textColor = .secondaryLabelColor

        epochLabel.font = .systemFont(ofSize: 10.5, weight: .medium)
        epochLabel.textColor = .secondaryLabelColor
        progress.style = .bar
        progress.controlSize = .small
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.doubleValue = 0
        progress.setAccessibilityLabel("Current submission epoch progress")

        let nextCaption = label("NEXT AUTOMATIC ATTEMPT", size: 10, weight: .medium, color: .secondaryLabelColor)
        countdownValue.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)

        let walletCaption = label("LOCAL WALLET", size: 10, weight: .medium, color: .secondaryLabelColor)
        addressValue.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
        addressValue.textColor = .secondaryLabelColor
        addressValue.lineBreakMode = .byClipping
        addressValue.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addressValue.onActivate = { [weak self] in
            self?.onCopyWalletAddress?()
        }

        ethValue.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        tokenValue.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let balances = NSStackView(views: [ethValue, tokenValue])
        balances.orientation = .horizontal
        balances.distribution = .fillEqually
        balances.spacing = 12

        statusValue.font = .systemFont(ofSize: 10.5)
        statusValue.textColor = .secondaryLabelColor
        statusValue.lineBreakMode = .byTruncatingTail
        statusValue.maximumNumberOfLines = 1

        let content = NSStackView(views: [
            header,
            separator(),
            usageCaption,
            miningWeightValue,
            lifetimeValue,
            epochLabel,
            progress,
            nextCaption,
            countdownValue,
            separator(),
            walletCaption,
            addressValue,
            balances,
            statusValue
        ])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 5
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            content.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
            header.widthAnchor.constraint(equalTo: content.widthAnchor),
            epochLabel.widthAnchor.constraint(equalTo: content.widthAnchor),
            progress.widthAnchor.constraint(equalTo: content.widthAnchor),
            countdownValue.widthAnchor.constraint(equalTo: content.widthAnchor),
            addressValue.widthAnchor.constraint(equalTo: content.widthAnchor),
            balances.widthAnchor.constraint(equalTo: content.widthAnchor),
            statusValue.widthAnchor.constraint(equalTo: content.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func update(
        usage: UsageSnapshot,
        walletAddress: String,
        chain: ChainSnapshot?,
        autoSubmit: Bool,
        nextAutomaticAttemptAt: Date,
        activity: String,
        activityTone: ActivityTone
    ) {
        lifetimeValue.stringValue = "Lifetime  \(usage.totalTokens.formatted(.number.grouping(.automatic))) tokens"
        addressValue.stringValue = walletAddress
        addressValue.toolTip = "Click to copy\n\(walletAddress)"
        addressValue.setAccessibilityValue(walletAddress)
        let displayedActivity = activityTone == .error ? "Error: \(activity)" : activity
        statusValue.stringValue = displayedActivity
        statusValue.toolTip = displayedActivity
        switch activityTone {
        case .informational:
            statusValue.textColor = .secondaryLabelColor
            statusValue.font = .systemFont(ofSize: 10.5)
        case .warning:
            statusValue.textColor = .systemOrange
            statusValue.font = .systemFont(ofSize: 10.5, weight: .medium)
        case .error:
            statusValue.textColor = .systemRed
            statusValue.font = .systemFont(ofSize: 10.5, weight: .semibold)
        }
        statusValue.setAccessibilityLabel(displayedActivity)

        guard let chain else {
            miningWeightValue.stringValue = "—"
            epochLabel.stringValue = "Fetching Base epoch…"
            progress.doubleValue = 0
            countdownValue.stringValue = autoSubmit ? "Checking schedule…" : "Disabled"
            ethValue.stringValue = "— ETH"
            tokenValue.stringValue = "— AORE"
            return
        }

        if !chain.registered {
            miningWeightValue.stringValue = "Baseline pending"
        } else if let pending = MiningWeightCalculator.pending(
            lifetimeTokens: usage.totalTokens,
            registered: chain.registered,
            lastCumulativeTokens: chain.lastCumulativeTokens
        ) {
            miningWeightValue.stringValue = pending.formatted(.number.grouping(.automatic))
        } else {
            miningWeightValue.stringValue = "—"
        }

        let duration = chain.epochEndsAt.timeIntervalSince(chain.epochStartedAt)
        let elapsed = Date().timeIntervalSince(chain.epochStartedAt)
        let fraction = duration > 0 ? min(max(elapsed / duration, 0), 1) : 0
        progress.doubleValue = fraction
        epochLabel.stringValue = "Epoch \(chain.currentEpoch)  ·  \(Int(fraction * 100))% complete"
        progress.setAccessibilityValue("\(Int(fraction * 100)) percent")

        if autoSubmit {
            let target = chain.submittedThisEpoch ? chain.epochEndsAt : nextAutomaticAttemptAt
            countdownValue.stringValue = countdown(to: target)
            countdownValue.toolTip = target.formatted(date: .abbreviated, time: .standard)
        } else {
            countdownValue.stringValue = "Disabled"
            countdownValue.toolTip = nil
        }

        ethValue.stringValue = "\(chain.ethBalance) ETH"
        tokenValue.stringValue = "\(chain.tokenBalance) AORE"
    }

    private func countdown(to date: Date) -> String {
        let remaining = max(0, Int(date.timeIntervalSinceNow.rounded(.up)))
        let hours = remaining / 3_600
        let minutes = (remaining % 3_600) / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func label(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor = .labelColor
    ) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        return field
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}

@MainActor
private final class CopyableAddressField: NSTextField {
    var onActivate: (() -> Void)?

    init() {
        super.init(frame: .zero)
        isEditable = false
        isSelectable = false
        isBezeled = false
        drawsBackground = false
        focusRingType = .default
        setAccessibilityRole(.button)
        setAccessibilityLabel("Copy wallet address")
        setAccessibilityHelp("Copies the local AgentOre wallet address to the clipboard")
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        alphaValue = 0.55
        onActivate?()
        alphaValue = 1
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 49 {
            onActivate?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        onActivate?()
        return true
    }
}
