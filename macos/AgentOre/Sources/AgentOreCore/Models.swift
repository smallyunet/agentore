import Foundation

public struct AgentOreConfiguration: Codable, Equatable, Sendable {
    public var rpcURL: String
    public var contractAddress: String
    public var autoSubmit: Bool

    public init(
        rpcURL: String = "https://sepolia.base.org",
        contractAddress: String = "",
        autoSubmit: Bool = false
    ) {
        self.rpcURL = rpcURL
        self.contractAddress = contractAddress
        self.autoSubmit = autoSubmit
    }

    public var isChainConfigured: Bool {
        URL(string: rpcURL) != nil && contractAddress.hasPrefix("0x") && contractAddress.count == 42
    }
}

public struct AgentOreState: Codable, Equatable, Sendable {
    public var lastObservedTokens: UInt64
    public var lastSubmittedEpoch: UInt64?
    public var lastTransactionHash: String?

    public init(
        lastObservedTokens: UInt64 = 0,
        lastSubmittedEpoch: UInt64? = nil,
        lastTransactionHash: String? = nil
    ) {
        self.lastObservedTokens = lastObservedTokens
        self.lastSubmittedEpoch = lastSubmittedEpoch
        self.lastTransactionHash = lastTransactionHash
    }
}

public struct UsageSnapshot: Equatable, Sendable {
    public let totalTokens: UInt64
    public let sessionCount: Int
    public let sampledAt: Date

    public init(totalTokens: UInt64, sessionCount: Int, sampledAt: Date = Date()) {
        self.totalTokens = totalTokens
        self.sessionCount = sessionCount
        self.sampledAt = sampledAt
    }
}

public enum AgentOreError: LocalizedError {
    case invalidConfiguration
    case invalidWallet
    case missingContract
    case malformedResponse
    case tokenCountOverflow

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "AgentOre configuration is invalid."
        case .invalidWallet: "The local AgentOre wallet could not be loaded."
        case .missingContract: "Set a valid contract address in ~/.agentore/config.json."
        case .malformedResponse: "The RPC or contract returned an unexpected response."
        case .tokenCountOverflow: "The aggregate token count exceeded UInt64 capacity."
        }
    }
}

