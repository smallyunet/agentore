import Foundation

public final class AgentOreCoordinator: @unchecked Sendable {
    public let paths: AppPaths
    public let walletAddress: String

    public private(set) var configuration: AgentOreConfiguration
    public private(set) var state: AgentOreState
    public private(set) var usage = UsageSnapshot(totalTokens: 0, sessionCount: 0)

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

        self.configuration = try configurationStore.load()
        self.state = try stateStore.load()
        self.stateStore = stateStore
        self.wallet = wallet
        self.walletAddress = wallet.address.address
        self.usageReader = usageReader ?? CodexJSONLUsageReader(sessionsRoot: paths.codexSessions)
    }

    @discardableResult
    public func refresh() throws -> UsageSnapshot {
        let snapshot = try usageReader.read()
        usage = snapshot
        state.lastObservedTokens = snapshot.totalTokens
        try stateStore.save(state)
        return snapshot
    }

    public func submitNow() async throws -> String {
        let client = try EthereumClient(configuration: configuration, wallet: wallet)
        let epoch = try await client.currentEpoch()
        if state.lastSubmittedEpoch == epoch, let hash = state.lastTransactionHash {
            return hash
        }

        let snapshot = try refresh()
        let hash = try await client.submit(cumulativeTokens: snapshot.totalTokens)
        state.lastSubmittedEpoch = epoch
        state.lastTransactionHash = hash
        try stateStore.save(state)
        return hash
    }

    public func autoSubmitIfNeeded() async throws -> String? {
        guard configuration.autoSubmit, configuration.isChainConfigured else { return nil }
        let client = try EthereumClient(configuration: configuration, wallet: wallet)
        let epoch = try await client.currentEpoch()
        guard state.lastSubmittedEpoch != epoch else { return nil }
        return try await submitNow()
    }

    public func finalizePreviousEpoch() async throws -> String {
        let client = try EthereumClient(configuration: configuration, wallet: wallet)
        let epoch = try await client.currentEpoch()
        guard epoch > 0 else { throw AgentOreError.malformedResponse }
        return try await client.finalize(epoch: epoch - 1)
    }
}

