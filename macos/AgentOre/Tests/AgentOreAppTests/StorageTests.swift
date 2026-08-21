@testable import AgentOreCore
import BigInt
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
            lastTransactionHash: "0xabc",
            lastSubmittedDeltaTokens: 12,
            lastSubmissionWasBaseline: false
        )
        try store.save(updated)
        XCTAssertEqual(try store.load(), updated)
    }

    func testLegacyStateWithoutSubmissionMetadataStillDecodes() throws {
        let data = Data("""
        {
          "lastObservedTokens": 15544460575,
          "lastSubmittedEpoch": 0,
          "lastTransactionHash": "0xabc"
        }
        """.utf8)

        let state = try JSONDecoder().decode(AgentOreState.self, from: data)

        XCTAssertEqual(state.lastAcceptedSubmission, .accepted(epoch: 0))
        XCTAssertNil(state.lastSubmittedDeltaTokens)
        XCTAssertNil(state.lastSubmissionWasBaseline)
    }

    func testLastAcceptedSubmissionDistinguishesBaselineAndWeightedDelta() {
        XCTAssertEqual(
            AgentOreState(
                lastSubmittedEpoch: 0,
                lastSubmissionWasBaseline: true
            ).lastAcceptedSubmission,
            .baseline(epoch: 0)
        )
        XCTAssertEqual(
            AgentOreState(
                lastSubmittedEpoch: 3,
                lastSubmittedDeltaTokens: 44_460_575,
                lastSubmissionWasBaseline: false
            ).lastAcceptedSubmission,
            .weighted(epoch: 3, deltaTokens: 44_460_575)
        )
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
        XCTAssertTrue(configuration.autoFinalize)
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
        XCTAssertEqual(configuration.rpcURL, AgentOreConfiguration.baseMainnetRPCURL)
        XCTAssertEqual(configuration.schemaVersion, AgentOreConfiguration.currentSchemaVersion)
        XCTAssertFalse(configuration.applyCurrentDefaultsIfNeeded())
    }

    func testVersionOneConfigurationMigratesTheLegacyDefaultRPC() throws {
        let data = Data("""
        {
          "rpcURL": "https://mainnet.base.org",
          "contractAddress": "0xcd5aB54841e0571671CbFBf15328097D6143De76",
          "autoSubmit": false,
          "schemaVersion": 1
        }
        """.utf8)
        var configuration = try JSONDecoder().decode(AgentOreConfiguration.self, from: data)

        XCTAssertTrue(configuration.applyCurrentDefaultsIfNeeded())
        XCTAssertEqual(configuration.rpcURL, AgentOreConfiguration.baseMainnetRPCURL)
        XCTAssertFalse(configuration.autoSubmit)
        XCTAssertTrue(configuration.autoFinalize)
        XCTAssertEqual(configuration.schemaVersion, AgentOreConfiguration.currentSchemaVersion)
        XCTAssertFalse(configuration.applyCurrentDefaultsIfNeeded())
    }

    func testVersionOneConfigurationPreservesACustomRPC() {
        var configuration = AgentOreConfiguration(
            rpcURL: "https://base.example.test",
            autoSubmit: false,
            schemaVersion: 1
        )

        XCTAssertTrue(configuration.applyCurrentDefaultsIfNeeded())
        XCTAssertEqual(configuration.rpcURL, "https://base.example.test")
        XCTAssertFalse(configuration.autoSubmit)
        XCTAssertTrue(configuration.autoFinalize)
        XCTAssertEqual(configuration.schemaVersion, AgentOreConfiguration.currentSchemaVersion)
    }

    func testCurrentSchemaPreservesExplicitAutoSubmitChoice() {
        var configuration = AgentOreConfiguration(autoSubmit: false)

        XCTAssertFalse(configuration.applyCurrentDefaultsIfNeeded())
        XCTAssertFalse(configuration.autoSubmit)
    }

    func testVersionTwoConfigurationEnablesAutomaticFinalizationWithoutChangingAutoSubmit() throws {
        let data = Data("""
        {
          "rpcURL": "https://base.example.test",
          "contractAddress": "0xcd5aB54841e0571671CbFBf15328097D6143De76",
          "autoSubmit": false,
          "schemaVersion": 2
        }
        """.utf8)
        var configuration = try JSONDecoder().decode(AgentOreConfiguration.self, from: data)

        XCTAssertTrue(configuration.applyCurrentDefaultsIfNeeded())
        XCTAssertFalse(configuration.autoSubmit)
        XCTAssertTrue(configuration.autoFinalize)
        XCTAssertEqual(configuration.schemaVersion, AgentOreConfiguration.currentSchemaVersion)
    }

    func testCurrentSchemaPreservesExplicitAutomaticFinalizationChoice() {
        var configuration = AgentOreConfiguration(autoFinalize: false)

        XCTAssertFalse(configuration.applyCurrentDefaultsIfNeeded())
        XCTAssertFalse(configuration.autoFinalize)
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

    func testCompactsTokenCountsForMenuAndDashboard() {
        XCTAssertEqual(TokenCountFormatter.compact(0), "0")
        XCTAssertEqual(TokenCountFormatter.compact(999), "999")
        XCTAssertEqual(TokenCountFormatter.compact(12_430_582), "12.4M")
        XCTAssertEqual(TokenCountFormatter.compact(15_544_460_575), "15.5B")
    }

    func testPendingMiningWeightUsesTheAcceptedCumulativeBaseline() {
        XCTAssertEqual(
            MiningWeightCalculator.pending(
                lifetimeTokens: 15_544_460_575,
                registered: true,
                lastCumulativeTokens: 15_500_000_000
            ),
            44_460_575
        )
        XCTAssertNil(
            MiningWeightCalculator.pending(
                lifetimeTokens: 15_544_460_575,
                registered: false,
                lastCumulativeTokens: 0
            )
        )
        XCTAssertEqual(
            MiningWeightCalculator.state(
                lifetimeTokens: 15_543_178_574,
                registered: true,
                lastCumulativeTokens: 15_544_460_575
            ),
            .counterBehind(deficit: 1_282_001)
        )
        XCTAssertEqual(
            MiningWeightCalculator.state(
                lifetimeTokens: 15_543_178_574,
                registered: true,
                lastCumulativeTokens: 15_544_460_575
            ).displayedTokens,
            0
        )
        XCTAssertFalse(
            MiningWeightCalculator.state(
                lifetimeTokens: 15_543_178_574,
                registered: true,
                lastCumulativeTokens: 15_544_460_575
            ).canSubmit
        )
    }

    func testPreviousEpochOnlyNeedsFinalizationWhenItHasWeightAndIsUnfinalized() {
        let ready = chainSnapshot(
            previousEpoch: 4,
            previousEpochFinalized: false,
            previousEpochHasWeight: true
        )
        XCTAssertTrue(ready.previousEpochNeedsFinalization)
        XCTAssertEqual(ready.automaticFinalizationReadiness, .ready(epoch: 4))
        XCTAssertFalse(
            chainSnapshot(
                previousEpoch: 4,
                previousEpochFinalized: true,
                previousEpochHasWeight: true
            ).previousEpochNeedsFinalization
        )
        XCTAssertFalse(
            chainSnapshot(
                previousEpoch: 4,
                previousEpochFinalized: false,
                previousEpochHasWeight: false
            ).previousEpochNeedsFinalization
        )
        XCTAssertFalse(
            chainSnapshot(
                previousEpoch: nil,
                previousEpochFinalized: nil,
                previousEpochHasWeight: false
            ).previousEpochNeedsFinalization
        )
        XCTAssertEqual(
            chainSnapshot(
                previousEpoch: 4,
                previousEpochFinalized: false,
                previousEpochHasWeight: true,
                hasGasBalance: false
            ).automaticFinalizationReadiness,
            .waitingForGas
        )
    }

    func testEpochZeroFinalizationErrorIsActionable() {
        XCTAssertEqual(
            AgentOreError.noPreviousEpochToFinalize.errorDescription,
            "There is no previous epoch to finalize yet."
        )
    }

    func testBaseGasPriceAddsSafetyMarginAndRoundsUp() {
        XCTAssertEqual(EthereumClient.bufferedGasPrice(BigUInt(6_000_000)), BigUInt(7_500_000))
        XCTAssertEqual(EthereumClient.bufferedGasPrice(BigUInt(1)), BigUInt(2))
    }

    func testUnderpricedRPCErrorIsRecognizedAndExplained() {
        let error = AgentOreError.codexAppServerFailed(
            "Server error. Error code: -32000. transaction underpriced"
        )

        XCTAssertTrue(EthereumClient.isUnderpriced(error))
        XCTAssertEqual(
            AgentOreError.userFacingMessage(for: error),
            "Base rejected the gas price as too low. AgentOre will refresh fees and retry automatically."
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

    private func chainSnapshot(
        previousEpoch: UInt64?,
        previousEpochFinalized: Bool?,
        previousEpochHasWeight: Bool,
        hasGasBalance: Bool = true
    ) -> ChainSnapshot {
        ChainSnapshot(
            currentEpoch: 5,
            epochStartedAt: Date(timeIntervalSince1970: 0),
            epochEndsAt: Date(timeIntervalSince1970: 86_400),
            submittedThisEpoch: false,
            previousEpoch: previousEpoch,
            previousEpochFinalized: previousEpochFinalized,
            previousEpochHasWeight: previousEpochHasWeight,
            registered: true,
            lastCumulativeTokens: 1,
            hasGasBalance: hasGasBalance,
            ethBalance: "0.001",
            tokenBalance: "0"
        )
    }
}
