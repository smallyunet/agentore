import Foundation

public final class AgentOreCoordinator: @unchecked Sendable {
    public let paths: AppPaths
    public let walletAddress: String

    public private(set) var configuration: AgentOreConfiguration
    public private(set) var state: AgentOreState
    public private(set) var usage = UsageSnapshot(totalTokens: 0)
    public private(set) var chainSnapshot: ChainSnapshot?

    public var pendingMiningTokens: UInt64? {
        guard let chainSnapshot else { return nil }
        return MiningWeightCalculator.pending(
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
        return try await submitCurrentUsage(client: client, epoch: epoch)
    }

    private func submitCurrentUsage(client: EthereumClient, epoch: UInt64) async throws -> String {
        let hash = try await client.submit(cumulativeTokens: usage.totalTokens)
        state.lastSubmittedEpoch = epoch
        state.lastTransactionHash = hash
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
        guard chain.hasGasBalance else { return .waitingForGas }
        if usage.totalTokens == 0 {
            _ = try await refresh()
        }
        return .submitted(try await submitCurrentUsage(client: client, epoch: epoch))
    }

    public func finalizePreviousEpoch() async throws -> String {
        let client = try EthereumClient(configuration: configuration, wallet: wallet)
        let epoch = try await client.currentEpoch()
        guard epoch > 0 else { throw AgentOreError.malformedResponse }
        return try await client.finalize(epoch: epoch - 1)
    }
}
