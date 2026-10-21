import Foundation

// MARK: - Cloud Provider Protocol
protocol CloudProvider {
    var id: String { get }
    var displayName: String { get }
    var isAuthenticated: Bool { get }

    func authenticate() async throws
    func upload(data: Data, remotePath: String) async throws -> URL
    func download(remotePath: String) async throws -> Data
    func list(path: String) async throws -> [CloudFile]
    func delete(path: String) async throws
}

// MARK: - Cloud File Model
struct CloudFile: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modifiedAt: Date
}

// MARK: - Cloud Provider Error
enum CloudProviderError: Error {
    case notAuthenticated
    case uploadFailed(String)
    case downloadFailed(String)
    case networkError(Error)
}
