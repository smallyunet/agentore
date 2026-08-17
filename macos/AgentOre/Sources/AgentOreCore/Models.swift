import Foundation

public struct AgentOreConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let baseMainnetRPCURL = "https://mainnet.base.org"
    public static let baseMainnetContractAddress = "0xcd5aB54841e0571671CbFBf15328097D6143De76"
    public static let legacyBaseSepoliaRPCURL = "https://sepolia.base.org"

    public var rpcURL: String
    public var contractAddress: String
    public var autoSubmit: Bool
    public var schemaVersion: Int?

    public init(
        rpcURL: String = AgentOreConfiguration.baseMainnetRPCURL,
        contractAddress: String = AgentOreConfiguration.baseMainnetContractAddress,
        autoSubmit: Bool = true,
        schemaVersion: Int? = AgentOreConfiguration.currentSchemaVersion
    ) {
        self.rpcURL = rpcURL
        self.contractAddress = contractAddress
        self.autoSubmit = autoSubmit
        self.schemaVersion = schemaVersion
    }

    public var isChainConfigured: Bool {
        URL(string: rpcURL) != nil && contractAddress.hasPrefix("0x") && contractAddress.count == 42
    }

    @discardableResult
    public mutating func applyBaseMainnetDeploymentIfNeeded() -> Bool {
        guard contractAddress.isEmpty else { return false }

        contractAddress = Self.baseMainnetContractAddress
        if rpcURL == Self.legacyBaseSepoliaRPCURL {
            rpcURL = Self.baseMainnetRPCURL
        }
        return true
    }

    /// Migrates configurations written before v0.0.3. Those releases had no
    /// in-app switch and always created `autoSubmit` as false, so this one-time
    /// schema migration safely adopts the new default without overriding later
    /// explicit user choices.
    @discardableResult
    public mutating func applyCurrentDefaultsIfNeeded() -> Bool {
        var changed = applyBaseMainnetDeploymentIfNeeded()
        guard schemaVersion == nil else { return changed }

        autoSubmit = true
        schemaVersion = Self.currentSchemaVersion
        changed = true
        return changed
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
    public let sampledAt: Date

    public init(totalTokens: UInt64, sampledAt: Date = Date()) {
        self.totalTokens = totalTokens
        self.sampledAt = sampledAt
    }
}

public struct ChainSnapshot: Equatable, Sendable {
    public let currentEpoch: UInt64
    public let epochStartedAt: Date
    public let epochEndsAt: Date
    public let submittedThisEpoch: Bool
    public let ethBalance: String
    public let tokenBalance: String

    public init(
        currentEpoch: UInt64,
        epochStartedAt: Date,
        epochEndsAt: Date,
        submittedThisEpoch: Bool,
        ethBalance: String,
        tokenBalance: String
    ) {
        self.currentEpoch = currentEpoch
        self.epochStartedAt = epochStartedAt
        self.epochEndsAt = epochEndsAt
        self.submittedThisEpoch = submittedThisEpoch
        self.ethBalance = ethBalance
        self.tokenBalance = tokenBalance
    }
}

public enum TokenAmountFormatter {
    public static func format(
        baseUnits: String,
        decimals: Int,
        maximumFractionDigits: Int
    ) -> String {
        guard decimals > 0 else { return baseUnits }

        let padded = String(
            repeating: "0",
            count: max(0, decimals + 1 - baseUnits.count)
        ) + baseUnits
        let split = padded.index(padded.endIndex, offsetBy: -decimals)
        let whole = String(padded[..<split])
        var fraction = String(padded[split...].prefix(maximumFractionDigits))
        while fraction.last == "0" { fraction.removeLast() }
        return fraction.isEmpty ? whole : "\(whole).\(fraction)"
    }
}

public enum AgentOreError: LocalizedError {
    case invalidConfiguration
    case invalidWallet
    case missingContract
    case malformedResponse
    case codexExecutableNotFound
    case codexAppServerTimedOut
    case codexAppServerFailed(String)
    case accountUsageUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "AgentOre configuration is invalid."
        case .invalidWallet: "The local AgentOre wallet could not be loaded."
        case .missingContract: "Set a valid contract address in ~/.agentore/config.json."
        case .malformedResponse: "The RPC or contract returned an unexpected response."
        case .codexExecutableNotFound: "The Codex executable could not be found."
        case .codexAppServerTimedOut: "Codex account usage timed out."
        case let .codexAppServerFailed(message): "Codex account usage failed: \(message)"
        case .accountUsageUnavailable: "Codex did not return a lifetime token count for this account."
        }
    }
}
