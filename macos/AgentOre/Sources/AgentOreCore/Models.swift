import Foundation
import Web3Core

public struct AgentOreConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2
    public static let baseMainnetRPCURL = "https://base-rpc.publicnode.com"
    public static let baseMainnetContractAddress = "0xcd5aB54841e0571671CbFBf15328097D6143De76"
    public static let legacyBaseMainnetRPCURL = "https://mainnet.base.org"
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

    /// Applies versioned defaults while preserving explicit user choices.
    @discardableResult
    public mutating func applyCurrentDefaultsIfNeeded() -> Bool {
        var changed = applyBaseMainnetDeploymentIfNeeded()
        let existingSchemaVersion = schemaVersion ?? 0

        if existingSchemaVersion < 1 {
            autoSubmit = true
            changed = true
        }
        if existingSchemaVersion < 2, rpcURL == Self.legacyBaseMainnetRPCURL {
            rpcURL = Self.baseMainnetRPCURL
            changed = true
        }
        if existingSchemaVersion < Self.currentSchemaVersion {
            schemaVersion = Self.currentSchemaVersion
            changed = true
        }
        return changed
    }
}

public struct AgentOreState: Codable, Equatable, Sendable {
    public var lastObservedTokens: UInt64
    public var lastSubmittedEpoch: UInt64?
    public var lastTransactionHash: String?
    public var lastSubmittedDeltaTokens: UInt64?
    public var lastSubmissionWasBaseline: Bool?

    public init(
        lastObservedTokens: UInt64 = 0,
        lastSubmittedEpoch: UInt64? = nil,
        lastTransactionHash: String? = nil,
        lastSubmittedDeltaTokens: UInt64? = nil,
        lastSubmissionWasBaseline: Bool? = nil
    ) {
        self.lastObservedTokens = lastObservedTokens
        self.lastSubmittedEpoch = lastSubmittedEpoch
        self.lastTransactionHash = lastTransactionHash
        self.lastSubmittedDeltaTokens = lastSubmittedDeltaTokens
        self.lastSubmissionWasBaseline = lastSubmissionWasBaseline
    }

    public var lastAcceptedSubmission: LastAcceptedSubmission? {
        guard let epoch = lastSubmittedEpoch else { return nil }
        if lastSubmissionWasBaseline == true {
            return .baseline(epoch: epoch)
        }
        if let lastSubmittedDeltaTokens {
            return .weighted(epoch: epoch, deltaTokens: lastSubmittedDeltaTokens)
        }
        return .accepted(epoch: epoch)
    }
}

public enum LastAcceptedSubmission: Equatable, Sendable {
    case baseline(epoch: UInt64)
    case weighted(epoch: UInt64, deltaTokens: UInt64)
    case accepted(epoch: UInt64)
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
    public let previousEpoch: UInt64?
    public let previousEpochFinalized: Bool?
    public let previousEpochHasWeight: Bool
    public let registered: Bool
    public let lastCumulativeTokens: UInt64
    public let hasGasBalance: Bool
    public let ethBalance: String
    public let tokenBalance: String

    public init(
        currentEpoch: UInt64,
        epochStartedAt: Date,
        epochEndsAt: Date,
        submittedThisEpoch: Bool,
        previousEpoch: UInt64?,
        previousEpochFinalized: Bool?,
        previousEpochHasWeight: Bool,
        registered: Bool,
        lastCumulativeTokens: UInt64,
        hasGasBalance: Bool,
        ethBalance: String,
        tokenBalance: String
    ) {
        self.currentEpoch = currentEpoch
        self.epochStartedAt = epochStartedAt
        self.epochEndsAt = epochEndsAt
        self.submittedThisEpoch = submittedThisEpoch
        self.previousEpoch = previousEpoch
        self.previousEpochFinalized = previousEpochFinalized
        self.previousEpochHasWeight = previousEpochHasWeight
        self.registered = registered
        self.lastCumulativeTokens = lastCumulativeTokens
        self.hasGasBalance = hasGasBalance
        self.ethBalance = ethBalance
        self.tokenBalance = tokenBalance
    }

    public var previousEpochNeedsFinalization: Bool {
        previousEpoch != nil && previousEpochFinalized == false && previousEpochHasWeight
    }
}

public enum AutomaticSubmissionResult: Equatable, Sendable {
    case disabled
    case alreadySubmitted
    case waitingForGas
    case submitted(String)
}

public enum MiningWeightCalculator {
    public static func pending(
        lifetimeTokens: UInt64,
        registered: Bool,
        lastCumulativeTokens: UInt64
    ) -> UInt64? {
        guard lifetimeTokens > 0,
              registered,
              lifetimeTokens >= lastCumulativeTokens
        else {
            return nil
        }
        return lifetimeTokens - lastCumulativeTokens
    }
}

public enum TokenCountFormatter {
    public static func compact(_ value: UInt64) -> String {
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
        let precision = scaled >= 100 ? 0 : 1
        return scaled.formatted(.number.precision(.fractionLength(precision))) + suffix
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
    case gasBalanceRequired
    case noPreviousEpochToFinalize

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
        case .gasBalanceRequired: "Add Base ETH to the local wallet before submitting."
        case .noPreviousEpochToFinalize: "There is no previous epoch to finalize yet."
        }
    }

    public static func userFacingMessage(for error: Error) -> String {
        if error.localizedDescription.localizedCaseInsensitiveContains("transaction underpriced") {
            return "Base rejected the gas price as too low. AgentOre will refresh fees and retry automatically."
        }
        if let web3Error = error as? Web3Error {
            switch web3Error {
            case .clientError(code: 429):
                return "Base RPC is rate limited. AgentOre will retry automatically."
            case .connectionError:
                return "Could not reach Base RPC. AgentOre will retry automatically."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}
