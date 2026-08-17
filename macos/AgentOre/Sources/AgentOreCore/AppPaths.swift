import Foundation

public struct AppPaths: Sendable {
    public let root: URL
    public let config: URL
    public let state: URL
    public let wallet: URL

    public init(
        root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentore")
    ) {
        self.root = root
        self.config = root.appendingPathComponent("config.json")
        self.state = root.appendingPathComponent("state.json")
        self.wallet = root.appendingPathComponent("wallet.json")
    }

    public func prepare() throws {
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
    }
}
