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

    func testDefaultConfigurationRequiresAContract() {
        XCTAssertFalse(AgentOreConfiguration().isChainConfigured)
        XCTAssertTrue(
            AgentOreConfiguration(
                rpcURL: "https://sepolia.base.org",
                contractAddress: "0x0000000000000000000000000000000000000001",
                autoSubmit: false
            ).isChainConfigured
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}

