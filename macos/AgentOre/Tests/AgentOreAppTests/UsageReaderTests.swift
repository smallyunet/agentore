import AgentOreCore
import XCTest

final class UsageReaderTests: XCTestCase {
    func testReadsLifetimeTokensFromAccountUsage() async throws {
        let executable = try makeAppServerFixture(response: """
        {"id":1,"result":{"summary":{"lifetimeTokens":1234567},"dailyUsageBuckets":[]}}
        """)

        let snapshot = try await CodexAccountUsageReader(executableURL: executable).read()

        XCTAssertEqual(snapshot.totalTokens, 1_234_567)
    }

    func testRejectsMissingLifetimeTokensWithoutFallback() async throws {
        let executable = try makeAppServerFixture(response: """
        {"id":1,"result":{"summary":{"lifetimeTokens":null},"dailyUsageBuckets":null}}
        """)

        do {
            _ = try await CodexAccountUsageReader(executableURL: executable).read()
            XCTFail("Expected account usage to be unavailable")
        } catch AgentOreError.accountUsageUnavailable {
            // Expected. AgentOre must not silently switch to local session files.
        }
    }

    private func makeAppServerFixture(response: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }

        let executable = root.appendingPathComponent("codex-fixture")
        let script = """
        #!/bin/sh
        while IFS= read -r line; do
          case "$line" in
            *account/usage/read*)
              printf '%s\\n' '\(response)'
              exit 0
              ;;
          esac
        done
        """
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        return executable
    }
}
