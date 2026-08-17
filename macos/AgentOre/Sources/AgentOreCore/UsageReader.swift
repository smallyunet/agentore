import Foundation

public protocol UsageReading: Sendable {
    func read() async throws -> UsageSnapshot
}

public struct CodexAccountUsageReader: UsageReading {
    private let executableURL: URL?
    private let timeout: TimeInterval

    public init(executableURL: URL? = nil, timeout: TimeInterval = 15) {
        self.executableURL = executableURL
        self.timeout = timeout
    }

    public func read() async throws -> UsageSnapshot {
        try await Task.detached {
            try readSynchronously()
        }.value
    }

    private func readSynchronously() throws -> UsageSnapshot {
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let executable = try executableURL ?? Self.locateCodexExecutable()

        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.standardError

        do {
            try process.run()
        } catch {
            throw AgentOreError.codexAppServerFailed(error.localizedDescription)
        }

        let timeoutWork = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

        defer {
            timeoutWork.cancel()
            try? inputPipe.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
            }
            process.waitUntilExit()
        }

        try send(
            [
                "method": "initialize",
                "id": 0,
                "params": [
                    "clientInfo": [
                        "name": "agentore",
                        "title": "AgentOre",
                        "version": "0.0.3"
                    ]
                ]
            ],
            to: inputPipe.fileHandleForWriting
        )
        try send(["method": "initialized", "params": [:]], to: inputPipe.fileHandleForWriting)
        try send(["method": "account/usage/read", "id": 1], to: inputPipe.fileHandleForWriting)

        let deadline = Date().addingTimeInterval(timeout)
        var buffer = Data()

        while process.isRunning || !buffer.isEmpty {
            let data = outputPipe.fileHandleForReading.availableData
            if data.isEmpty {
                break
            }
            buffer.append(data)

            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer[..<newline]
                buffer.removeSubrange(...newline)
                guard let response = try decodeUsageResponse(from: Data(line)) else { continue }
                return response
            }
        }

        if Date() >= deadline {
            throw AgentOreError.codexAppServerTimedOut
        }
        throw AgentOreError.codexAppServerFailed("The process exited before returning account usage.")
    }

    private func send(_ message: [String: Any], to handle: FileHandle) throws {
        var data = try JSONSerialization.data(
            withJSONObject: message,
            options: [.withoutEscapingSlashes]
        )
        data.append(0x0A)
        try handle.write(contentsOf: data)
    }

    private func decodeUsageResponse(from data: Data) throws -> UsageSnapshot? {
        guard let identity = try? JSONDecoder().decode(ResponseIdentity.self, from: data),
              identity.id == 1
        else {
            return nil
        }

        let response = try JSONDecoder().decode(AccountUsageResponse.self, from: data)
        if let error = response.error {
            throw AgentOreError.codexAppServerFailed(error.message)
        }
        guard let lifetimeTokens = response.result?.summary.lifetimeTokens,
              lifetimeTokens >= 0
        else {
            throw AgentOreError.accountUsageUnavailable
        }

        return UsageSnapshot(totalTokens: UInt64(lifetimeTokens))
    }

    private static func locateCodexExecutable() throws -> URL {
        var candidates: [String] = []
        if let configured = ProcessInfo.processInfo.environment["CODEX_BIN"] {
            candidates.append(configured)
        }
        candidates.append(contentsOf: [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ])
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/codex" })
        }

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        throw AgentOreError.codexExecutableNotFound
    }
}

private struct ResponseIdentity: Decodable {
    let id: Int?
}

private struct AccountUsageResponse: Decodable {
    let result: Result?
    let error: RPCError?

    struct Result: Decodable {
        let summary: Summary
    }

    struct Summary: Decodable {
        let lifetimeTokens: Int64?
    }

    struct RPCError: Decodable {
        let message: String
    }
}
