import BigInt
import Foundation
import Web3Core
import web3swift

public protocol EthereumSubmitting: Sendable {
    func currentEpoch() async throws -> UInt64
    func snapshot() async throws -> ChainSnapshot
    func submit(cumulativeTokens: UInt64) async throws -> String
    func finalize(epoch: UInt64) async throws -> String
}

public final class EthereumClient: EthereumSubmitting, @unchecked Sendable {
    static let gasPriceSafetyNumerator = BigUInt(125)
    static let gasPriceSafetyDenominator = BigUInt(100)

    private static let abi = """
    [
      {"inputs":[],"name":"currentEpoch","outputs":[{"type":"uint256"}],"stateMutability":"view","type":"function"},
      {"inputs":[],"name":"genesisTime","outputs":[{"type":"uint256"}],"stateMutability":"view","type":"function"},
      {"inputs":[],"name":"epochDuration","outputs":[{"type":"uint256"}],"stateMutability":"view","type":"function"},
      {"inputs":[{"name":"account","type":"address"}],"name":"balanceOf","outputs":[{"type":"uint256"}],"stateMutability":"view","type":"function"},
      {"inputs":[{"name":"account","type":"address"}],"name":"registered","outputs":[{"type":"bool"}],"stateMutability":"view","type":"function"},
      {"inputs":[{"name":"account","type":"address"}],"name":"lastCumulativeTokens","outputs":[{"type":"uint256"}],"stateMutability":"view","type":"function"},
      {"inputs":[{"name":"epoch","type":"uint256"},{"name":"account","type":"address"}],"name":"submittedInEpoch","outputs":[{"type":"bool"}],"stateMutability":"view","type":"function"},
      {"inputs":[{"name":"epoch","type":"uint256"}],"name":"finalized","outputs":[{"type":"bool"}],"stateMutability":"view","type":"function"},
      {"inputs":[{"name":"epoch","type":"uint256"}],"name":"totalWeight","outputs":[{"type":"uint256"}],"stateMutability":"view","type":"function"},
      {"inputs":[{"name":"cumulativeTokens","type":"uint256"}],"name":"submit","outputs":[],"stateMutability":"nonpayable","type":"function"},
      {"inputs":[{"name":"epoch","type":"uint256"}],"name":"finalize","outputs":[{"name":"selectedWinner","type":"address"}],"stateMutability":"nonpayable","type":"function"}
    ]
    """

    private let configuration: AgentOreConfiguration
    private let wallet: LocalWallet

    public init(configuration: AgentOreConfiguration, wallet: LocalWallet) throws {
        guard configuration.isChainConfigured else { throw AgentOreError.missingContract }
        self.configuration = configuration
        self.wallet = wallet
    }

    public func currentEpoch() async throws -> UInt64 {
        let (_, contract) = try await makeContract()
        guard let operation = contract.createReadOperation("currentEpoch") else {
            throw AgentOreError.malformedResponse
        }
        let response = try await operation.callContractMethod()
        guard let value = response["0"] as? BigUInt, let epoch = UInt64(exactly: value) else {
            throw AgentOreError.malformedResponse
        }
        return epoch
    }

    public func snapshot() async throws -> ChainSnapshot {
        let (web3, contract) = try await makeContract()
        let epochValue = try await readBigUInt(contract, method: "currentEpoch")
        let genesisValue = try await readBigUInt(contract, method: "genesisTime")
        let durationValue = try await readBigUInt(contract, method: "epochDuration")
        let tokenBalance = try await readBigUInt(
            contract,
            method: "balanceOf",
            parameters: [wallet.address]
        )
        let lastCumulativeValue = try await readBigUInt(
            contract,
            method: "lastCumulativeTokens",
            parameters: [wallet.address]
        )
        let registered = try await readBool(
            contract,
            method: "registered",
            parameters: [wallet.address]
        )

        guard let submittedOperation = contract.createReadOperation(
            "submittedInEpoch",
            parameters: [epochValue, wallet.address]
        ) else {
            throw AgentOreError.malformedResponse
        }
        let submittedResponse = try await submittedOperation.callContractMethod()
        guard let submitted = submittedResponse["0"] as? Bool,
              let epoch = UInt64(exactly: epochValue),
              let genesis = UInt64(exactly: genesisValue),
              let duration = UInt64(exactly: durationValue),
              let lastCumulativeTokens = UInt64(exactly: lastCumulativeValue),
              duration > 0
        else {
            throw AgentOreError.malformedResponse
        }

        let ethBalance = try await web3.eth.getBalance(for: wallet.address)
        let epochStart = genesis + epoch * duration
        let previousEpoch = epoch > 0 ? epoch - 1 : nil
        let previousEpochFinalized: Bool?
        let previousEpochHasWeight: Bool
        if let previousEpoch {
            previousEpochFinalized = try await readBool(
                contract,
                method: "finalized",
                parameters: [BigUInt(previousEpoch)]
            )
            previousEpochHasWeight = try await readBigUInt(
                contract,
                method: "totalWeight",
                parameters: [BigUInt(previousEpoch)]
            ) > 0
        } else {
            previousEpochFinalized = nil
            previousEpochHasWeight = false
        }

        return ChainSnapshot(
            currentEpoch: epoch,
            epochStartedAt: Date(timeIntervalSince1970: TimeInterval(epochStart)),
            epochEndsAt: Date(timeIntervalSince1970: TimeInterval(epochStart + duration)),
            submittedThisEpoch: submitted,
            previousEpoch: previousEpoch,
            previousEpochFinalized: previousEpochFinalized,
            previousEpochHasWeight: previousEpochHasWeight,
            registered: registered,
            lastCumulativeTokens: lastCumulativeTokens,
            hasGasBalance: ethBalance > 0,
            ethBalance: TokenAmountFormatter.format(
                baseUnits: ethBalance.description,
                decimals: 18,
                maximumFractionDigits: 6
            ),
            tokenBalance: TokenAmountFormatter.format(
                baseUnits: tokenBalance.description,
                decimals: 18,
                maximumFractionDigits: 4
            )
        )
    }

    public func submit(cumulativeTokens: UInt64) async throws -> String {
        let (web3, contract) = try await makeContract()
        web3.addKeystoreManager(KeystoreManager([wallet.keystore]))
        return try await broadcast(web3: web3) {
            contract.createWriteOperation(
                "submit",
                parameters: [BigUInt(cumulativeTokens)]
            )
        }
    }

    public func finalize(epoch: UInt64) async throws -> String {
        let (web3, contract) = try await makeContract()
        web3.addKeystoreManager(KeystoreManager([wallet.keystore]))
        return try await broadcast(web3: web3) {
            contract.createWriteOperation("finalize", parameters: [BigUInt(epoch)])
        }
    }

    private func broadcast(
        web3: Web3,
        makeOperation: () -> WriteOperation?
    ) async throws -> String {
        let quotedGasPrice = try await web3.eth.gasPrice()
        let initialGasPrice = Self.bufferedGasPrice(quotedGasPrice)

        do {
            return try await send(
                makeOperation: makeOperation,
                gasPrice: initialGasPrice
            )
        } catch where Self.isUnderpriced(error) {
            let refreshedGasPrice = try await web3.eth.gasPrice()
            let retryGasPrice = max(
                Self.bufferedGasPrice(refreshedGasPrice),
                Self.bufferedGasPrice(initialGasPrice)
            )
            return try await send(
                makeOperation: makeOperation,
                gasPrice: retryGasPrice
            )
        }
    }

    private func send(
        makeOperation: () -> WriteOperation?,
        gasPrice: BigUInt
    ) async throws -> String {
        guard let operation = makeOperation() else {
            throw AgentOreError.malformedResponse
        }
        operation.transaction.from = wallet.address
        let policies = Policies(
            noncePolicy: .pending,
            gasPricePolicy: .manual(gasPrice)
        )
        return try await operation.writeToChain(password: "", policies: policies).hash
    }

    static func bufferedGasPrice(_ gasPrice: BigUInt) -> BigUInt {
        let roundedNumerator = gasPrice * gasPriceSafetyNumerator
            + gasPriceSafetyDenominator - 1
        return roundedNumerator / gasPriceSafetyDenominator
    }

    static func isUnderpriced(_ error: Error) -> Bool {
        error.localizedDescription.localizedCaseInsensitiveContains("transaction underpriced")
    }

    private func makeContract() async throws -> (Web3, Web3.Contract) {
        guard let rpcURL = URL(string: configuration.rpcURL),
              let contractAddress = EthereumAddress(configuration.contractAddress)
        else {
            throw AgentOreError.invalidConfiguration
        }

        let web3 = try await Web3.new(
            rpcURL,
            network: .Custom(networkID: BigUInt(AgentOreChain.baseMainnetChainID))
        )
        guard let contract = web3.contract(Self.abi, at: contractAddress, abiVersion: 2) else {
            throw AgentOreError.malformedResponse
        }
        return (web3, contract)
    }

    private func readBigUInt(
        _ contract: Web3.Contract,
        method: String,
        parameters: [Any] = []
    ) async throws -> BigUInt {
        guard let operation = contract.createReadOperation(method, parameters: parameters) else {
            throw AgentOreError.malformedResponse
        }
        let response = try await operation.callContractMethod()
        guard let value = response["0"] as? BigUInt else {
            throw AgentOreError.malformedResponse
        }
        return value
    }

    private func readBool(
        _ contract: Web3.Contract,
        method: String,
        parameters: [Any] = []
    ) async throws -> Bool {
        guard let operation = contract.createReadOperation(method, parameters: parameters) else {
            throw AgentOreError.malformedResponse
        }
        let response = try await operation.callContractMethod()
        guard let value = response["0"] as? Bool else {
            throw AgentOreError.malformedResponse
        }
        return value
    }

}
