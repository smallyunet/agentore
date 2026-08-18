import AgentOreCore
import XCTest

final class ChainMetadataTests: XCTestCase {
    func testBaseMainnetChainID() {
        XCTAssertEqual(AgentOreChain.baseMainnetChainID, 8_453)
    }
}
