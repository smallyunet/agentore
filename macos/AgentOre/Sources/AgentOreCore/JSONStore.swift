import Foundation

public struct JSONStore<Value: Codable & Sendable>: Sendable {
    private let url: URL
    private let defaultValue: Value

    public init(url: URL, defaultValue: Value) {
        self.url = url
        self.defaultValue = defaultValue
    }

    public func load() throws -> Value {
        guard FileManager.default.fileExists(atPath: url.path) else {
            try save(defaultValue)
            return defaultValue
        }
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }

    public func save(_ value: Value) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var data = try encoder.encode(value)
        data.append(0x0A)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

