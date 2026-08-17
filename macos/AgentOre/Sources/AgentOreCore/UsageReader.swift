import Foundation

public protocol UsageReading: Sendable {
    func read() throws -> UsageSnapshot
}

public struct CodexJSONLUsageReader: UsageReading {
    private let sessionsRoot: URL

    public init(sessionsRoot: URL) {
        self.sessionsRoot = sessionsRoot
    }

    public func read() throws -> UsageSnapshot {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return UsageSnapshot(totalTokens: 0, sessionCount: 0)
        }

        var aggregate: UInt64 = 0
        var countedSessions = 0

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
            guard let maximum = try maximumTokenCount(in: fileURL) else { continue }
            let (next, overflow) = aggregate.addingReportingOverflow(maximum)
            if overflow { throw AgentOreError.tokenCountOverflow }
            aggregate = next
            countedSessions += 1
        }

        return UsageSnapshot(totalTokens: aggregate, sessionCount: countedSessions)
    }

    private func maximumTokenCount(in fileURL: URL) throws -> UInt64? {
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        var maximum: UInt64?

        contents.enumerateLines { line, _ in
            guard line.contains("\"token_count\"") else { return }
            guard let data = line.data(using: .utf8) else { return }
            guard let event = try? JSONDecoder().decode(TokenCountEvent.self, from: data) else { return }
            guard event.payload?.type == "token_count" else { return }
            guard let value = event.payload?.info?.totalTokenUsage?.totalTokens else { return }
            maximum = max(maximum ?? 0, value)
        }

        return maximum
    }
}

private struct TokenCountEvent: Decodable {
    let payload: Payload?

    struct Payload: Decodable {
        let type: String?
        let info: Info?
    }

    struct Info: Decodable {
        let totalTokenUsage: TotalTokenUsage?

        enum CodingKeys: String, CodingKey {
            case totalTokenUsage = "total_token_usage"
        }
    }

    struct TotalTokenUsage: Decodable {
        let totalTokens: UInt64?

        enum CodingKeys: String, CodingKey {
            case totalTokens = "total_tokens"
        }
    }
}

