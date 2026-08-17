import AgentOreCore
import XCTest

final class UsageReaderTests: XCTestCase {
    func testSumsMaximumCumulativeCountPerSession() throws {
        let root = try makeTemporaryDirectory()
        let nested = root.appendingPathComponent("2026/08/17")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let first = """
        {"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":100}}}}
        {"type":"response_item","payload":{"type":"message","content":"private prompt"}}
        {"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":250}}}}
        """
        let second = """
        {"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":75}}}}
        """

        try first.write(to: nested.appendingPathComponent("one.jsonl"), atomically: true, encoding: .utf8)
        try second.write(to: nested.appendingPathComponent("two.jsonl"), atomically: true, encoding: .utf8)
        try "ignored".write(to: nested.appendingPathComponent("note.txt"), atomically: true, encoding: .utf8)

        let snapshot = try CodexJSONLUsageReader(sessionsRoot: root).read()

        XCTAssertEqual(snapshot.totalTokens, 325)
        XCTAssertEqual(snapshot.sessionCount, 2)
    }

    func testMissingDirectoryReturnsZero() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let snapshot = try CodexJSONLUsageReader(sessionsRoot: root).read()
        XCTAssertEqual(snapshot.totalTokens, 0)
        XCTAssertEqual(snapshot.sessionCount, 0)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}

