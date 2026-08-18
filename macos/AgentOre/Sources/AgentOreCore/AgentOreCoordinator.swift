import Foundation

public final class AgentOreCoordinator: @unchecked Sendable {
    public let paths: AppPaths
    public let walletAddress: String

    public private(set) var configuration: AgentOreConfiguration
    public private(set) var state: AgentOreState
    public private(set) var usage = UsageSnapshot(totalTokens: 0)
    public private(set) var chainSnapshot: ChainSnapshot?

    public var pendingMiningState: PendingMiningState {
        guard let chainSnapshot else { return .unavailable }
        return MiningWeightCalculator.state(
            lifetimeTokens: usage.totalTokens,
            registered: chainSnapshot.registered,
            lastCumulativeTokens: chainSnapshot.lastCumulativeTokens
        )
    }

    private let usageReader: UsageReading
    private let stateStore: JSONStore<AgentOreState>
    private let wallet: LocalWallet

    public init(paths: AppPaths = AppPaths(), usageReader: UsageReading? = nil) throws {
        self.paths = paths
        try paths.prepare()

        let configurationStore = JSONStore(
            url: paths.config,
            defaultValue: AgentOreConfiguration()
        )
        let stateStore = JSONStore(url: paths.state, defaultValue: AgentOreState())
        let wallet = try WalletStore(url: paths.wallet).loadOrCreate()
        var configuration = try configurationStore.load()
        if configuration.applyCurrentDefaultsIfNeeded() {
            try configurationStore.save(configuration)
        }

        self.configuration = configuration
        self.state = try stateStore.load()
        self.stateStore = stateStore
        self.wallet = wallet
        self.walletAddress = wallet.address.address
        self.usageReader = usageReader ?? CodexAccountUsageReader()
    }

    @discardableResult
    public func refreshChain() async throws -> ChainSnapshot {
        let client = try EthereumClient(configuration: configuration, wallet: wallet)
        let snapshot = try await client.snapshot()
        chainSnapshot = snapshot
        if state.lastSubmittedEpoch == 0,
           state.lastSubmissionWasBaseline == nil,
           state.lastSubmittedDeltaTokens == nil,
           snapshot.registered {
            // A wallet can only submit once in Epoch 0, so an accepted Epoch 0
            // transaction is necessarily its zero-weight baseline.
            state.lastSubmissionWasBaseline = true
            try stateStore.save(state)
        }
        return snapshot
    }

    @discardableResult
    public func refresh() async throws -> UsageSnapshot {
        let snapshot = try await usageReader.read()
        usage = snapshot
        state.lastObservedTokens = snapshot.totalTokens
        try stateStore.save(state)
        return snapshot
    }

    public func submitNow() async throws -> String {
        let client = try EthereumClient(configuration: configuration, wallet: wallet)
        let chain = try await currentChainSnapshot()
        guard chain.hasGasBalance else { throw AgentOreError.gasBalanceRequired }
        let epoch = chain.currentEpoch
        if state.lastSubmittedEpoch == epoch, let hash = state.lastTransactionHash {
            return hash
        }

        _ = try await refresh()
        return try await submitCurrentUsage(client: client, chain: chain)
    }

    private func submitCurrentUsage(client: EthereumClient, chain: ChainSnapshot) async throws -> String {
        let wasBaseline = !chain.registered
        let pendingState = MiningWeightCalculator.state(
            lifetimeTokens: usage.totalTokens,
            registered: chain.registered,
            lastCumulativeTokens: chain.lastCumulativeTokens
        )
        if case let .counterBehind(deficit) = pendingState {
            throw AgentOreError.usageCounterBelowBaseline(deficit)
        }
        if case let .ready(tokens) = pendingState, tokens == 0 {
            throw AgentOreError.noPendingTokens
        }
        let submittedDelta = wasBaseline ? nil : pendingState.displayedTokens
        let hash = try await client.submit(cumulativeTokens: usage.totalTokens)
        state.lastSubmittedEpoch = chain.currentEpoch
        state.lastTransactionHash = hash
        state.lastSubmittedDeltaTokens = submittedDelta
        state.lastSubmissionWasBaseline = wasBaseline
        try stateStore.save(state)
        _ = try? await refreshChain()
        return hash
    }

    private func currentChainSnapshot() async throws -> ChainSnapshot {
        if let chainSnapshot {
            return chainSnapshot
        }
        return try await refreshChain()
    }

    public func autoSubmitIfNeeded() async throws -> AutomaticSubmissionResult {
        guard configuration.autoSubmit, configuration.isChainConfigured else { return .disabled }
        let client = try EthereumClient(configuration: configuration, wallet: wallet)
        let chain = try await currentChainSnapshot()
        let epoch = chain.currentEpoch
        if chain.submittedThisEpoch {
            state.lastSubmittedEpoch = epoch
            try stateStore.save(state)
            return .alreadySubmitted
        }
        guard state.lastSubmittedEpoch != epoch else { return .alreadySubmitted }
        if usage.totalTokens == 0 {
            _ = try await refresh()
        }
        guard pendingMiningState.canSubmit else { return .waitingForUsage }
        guard chain.hasGasBalance else { return .waitingForGas }
        return .submitted(try await submitCurrentUsage(client: client, chain: chain))
    }

    public func finalizePreviousEpoch() async throws -> String {
        let client = try EthereumClient(configuration: configuration, wallet: wallet)
        let epoch = try await client.currentEpoch()
        guard epoch > 0 else { throw AgentOreError.noPreviousEpochToFinalize }
        return try await client.finalize(epoch: epoch - 1)
    }
}
