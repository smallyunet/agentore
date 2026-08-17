import Foundation
import Web3Core

public final class LocalWallet: @unchecked Sendable {
    public let keystore: EthereumKeystoreV3
    public let address: EthereumAddress

    fileprivate init(keystore: EthereumKeystoreV3, address: EthereumAddress) {
        self.keystore = keystore
        self.address = address
    }
}

public struct WalletStore: Sendable {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func loadOrCreate() throws -> LocalWallet {
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            guard let keystore = EthereumKeystoreV3(data), let address = keystore.addresses?.first else {
                throw AgentOreError.invalidWallet
            }
            return LocalWallet(keystore: keystore, address: address)
        }

        guard let keystore = try EthereumKeystoreV3(password: ""),
              let parameters = keystore.keystoreParams,
              let address = keystore.addresses?.first
        else {
            throw AgentOreError.invalidWallet
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var data = try encoder.encode(parameters)
        data.append(0x0A)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return LocalWallet(keystore: keystore, address: address)
    }
}

