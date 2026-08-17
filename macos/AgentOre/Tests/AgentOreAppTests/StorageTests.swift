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
        XCTAssertTrue(configuration.autoSubmit)
        XCTAssertEqual(configuration.schemaVersion, AgentOreConfiguration.currentSchemaVersion)
    }

    func testPreSchemaConfigurationMigratesAutoSubmitToEnabled() throws {
        let data = Data("""
        {
          "rpcURL": "https://mainnet.base.org",
          "contractAddress": "0xcd5aB54841e0571671CbFBf15328097D6143De76",
          "autoSubmit": false
        }
        """.utf8)
        var configuration = try JSONDecoder().decode(AgentOreConfiguration.self, from: data)

        XCTAssertTrue(configuration.applyCurrentDefaultsIfNeeded())
        XCTAssertTrue(configuration.autoSubmit)
        XCTAssertEqual(configuration.schemaVersion, AgentOreConfiguration.currentSchemaVersion)
        XCTAssertFalse(configuration.applyCurrentDefaultsIfNeeded())
    }

    func testCurrentSchemaPreservesExplicitAutoSubmitChoice() {
        var configuration = AgentOreConfiguration(autoSubmit: false)

        XCTAssertFalse(configuration.applyCurrentDefaultsIfNeeded())
        XCTAssertFalse(configuration.autoSubmit)
    }

    func testFormatsNativeAndTokenBalancesWithoutFloatingPointLoss() {
        XCTAssertEqual(
            TokenAmountFormatter.format(
                baseUnits: "1234567890000000000",
                decimals: 18,
                maximumFractionDigits: 6
            ),
            "1.234567"
        )
        XCTAssertEqual(
            TokenAmountFormatter.format(
                baseUnits: "7200000000000000000000",
                decimals: 18,
                maximumFractionDigits: 4
            ),
            "7200"
        )
        XCTAssertEqual(
            TokenAmountFormatter.format(
                baseUnits: "1000000000000",
                decimals: 18,
                maximumFractionDigits: 6
            ),
            "0.000001"
        )
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
