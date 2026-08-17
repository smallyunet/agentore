import BigInt
import Foundation
import Web3Core
import web3swift

public protocol EthereumSubmitting: Sendable {
    func currentEpoch() async throws -> UInt64
    func submit(cumulativeTokens: UInt64) async throws -> String
    func finalize(epoch: UInt64) async throws -> String
}

public final class EthereumClient: EthereumSubmitting, @unchecked Sendable {
    private static let abi = """
    [
      {"inputs":[],"name":"currentEpoch","outputs":[{"type":"uint256"}],"stateMutability":"view","type":"function"},
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

    public func submit(cumulativeTokens: UInt64) async throws -> String {
        let (web3, contract) = try await makeContract()
        guard let operation = contract.createWriteOperation(
            "submit",
            parameters: [BigUInt(cumulativeTokens)]
        ) else {
            throw AgentOreError.malformedResponse
        }
        operation.transaction.from = wallet.address
        web3.addKeystoreManager(KeystoreManager([wallet.keystore]))
        return try await operation.writeToChain(password: "").hash
    }

    public func finalize(epoch: UInt64) async throws -> String {
        let (web3, contract) = try await makeContract()
        guard let operation = contract.createWriteOperation("finalize", parameters: [BigUInt(epoch)]) else {
            throw AgentOreError.malformedResponse
        }
        operation.transaction.from = wallet.address
        web3.addKeystoreManager(KeystoreManager([wallet.keystore]))
        return try await operation.writeToChain(password: "").hash
    }

    private func makeContract() async throws -> (Web3, Web3.Contract) {
        guard let rpcURL = URL(string: configuration.rpcURL),
              let contractAddress = EthereumAddress(configuration.contractAddress)
        else {
            throw AgentOreError.invalidConfiguration
        }

        let web3 = try await Web3.new(rpcURL)
        guard let contract = web3.contract(Self.abi, at: contractAddress, abiVersion: 2) else {
            throw AgentOreError.malformedResponse
        }
        return (web3, contract)
    }
}

