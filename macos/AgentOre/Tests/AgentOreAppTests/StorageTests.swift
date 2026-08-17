import AgentOreCore
import XCTest

final class StorageTests: XCTestCase {
    func testJSONStoreCreatesAndPersistsState() throws {
        let root = try makeTemporaryDirectory()
        let url = root.appendingPathComponent("state.json")
        let store = JSONStore(url: url, defaultValue: AgentOreState())

        XCTAssertEqual(try store.load(), AgentOreState())

        let updated = AgentOreState(
            lastObservedTokens: 42,
            lastSubmittedEpoch: 7,
            lastTransactionHash: "0xabc"
        )
        try store.save(updated)
        XCTAssertEqual(try store.load(), updated)
    }

    func testWalletPersistsTheSameAddress() throws {
        let root = try makeTemporaryDirectory()
        let url = root.appendingPathComponent("wallet.json")
        let store = WalletStore(url: url)

        let first = try store.loadOrCreate()
        let second = try store.loadOrCreate()

        XCTAssertEqual(first.address.address.lowercased(), second.address.address.lowercased())
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testDefaultConfigurationUsesBaseMainnetDeployment() {
        let configuration = AgentOreConfiguration()

        XCTAssertTrue(configuration.isChainConfigured)
        XCTAssertEqual(configuration.rpcURL, AgentOreConfiguration.baseMainnetRPCURL)
        XCTAssertEqual(
            configuration.contractAddress,
            AgentOreConfiguration.baseMainnetContractAddress
        )
        XCTAssertFalse(configuration.autoSubmit)
    }

    func testLegacyEmptyConfigurationMigratesToBaseMainnetDeployment() {
        var configuration = AgentOreConfiguration(
            rpcURL: AgentOreConfiguration.legacyBaseSepoliaRPCURL,
            contractAddress: "",
            autoSubmit: false
        )

        XCTAssertTrue(configuration.applyBaseMainnetDeploymentIfNeeded())
        XCTAssertEqual(configuration.rpcURL, AgentOreConfiguration.baseMainnetRPCURL)
        XCTAssertEqual(
            configuration.contractAddress,
            AgentOreConfiguration.baseMainnetContractAddress
        )
        XCTAssertFalse(configuration.applyBaseMainnetDeploymentIfNeeded())
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
