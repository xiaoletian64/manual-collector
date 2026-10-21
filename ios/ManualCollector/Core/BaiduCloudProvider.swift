import Foundation
import AuthenticationServices

final class BaiduCloudProvider: NSObject, CloudProvider {
    let id = "baidu"
    let displayName = "百度网盘"
    private(set) var isAuthenticated = false

    private var accessToken: String?
    private var refreshToken: String?
    private var expiresAt: Date?

    private let authURL = "https://openapi.baidu.com/oauth/2.0/authorize"
    private let tokenURL = "https://openapi.baidu.com/oauth/2.0/token"
    private let apiBase = "https://pan.baidu.com/rest/2.0/xpan/file"

    private let appKey: String
    private let secretKey: String
    private let redirectURI = "com.manualcollector://oauth/callback"

    init(appKey: String = "YOUR_BAIDU_APP_KEY", secretKey: String = "YOUR_BAIDU_SECRET_KEY") {
        self.appKey = appKey
        self.secretKey = secretKey
    }

    // MARK: - Authentication

    func authenticate() async throws {
        let scope = "basic,netdisk"
        let encodedRedirect = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let authURLString = "\(authURL)?response_type=code&client_id=\(appKey)&redirect_uri=\(encodedRedirect)&scope=\(scope)"

        guard let url = URL(string: authURLString) else {
            throw CloudProviderError.uploadFailed("Invalid auth URL")
        }

        let code = try await performOAuthFlow(authURL: url)

        let token = try await exchangeCodeForToken(code: code)
        self.accessToken = token.accessToken
        self.refreshToken = token.refreshToken
        self.expiresAt = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        self.isAuthenticated = true

        try saveToKeychain(token: token.accessToken, refresh: token.refreshToken ?? "")
    }

    func upload(data: Data, remotePath: String) async throws -> URL {
        guard let token = accessToken else {
            throw CloudProviderError.notAuthenticated
        }

        // Step 1: Precreate - get uploadid
        let precreate = try await precreateFile(accessToken: token, remotePath: remotePath, fileSize: data.count)
        let uploadID = precreate["uploadid"] as? String ?? ""
        let blockList = precreate["block_list"] as? [Int] ?? [0]

        // Step 2: Slice upload (single block for files < 4MB)
        for (i, blockIdx) in blockList.enumerated() {
            let blockSize = min(4 * 1024 * 1024, data.count - i * 4 * 1024 * 1024)
            let start = i * 4 * 1024 * 1024
            let end = min(start + blockSize, data.count)
            let blockData = data.subdata(in: start..<end)

            try await uploadSlice(
                accessToken: token,
                remotePath: remotePath,
                uploadID: uploadID,
                blockIndex: blockIdx,
                data: blockData
            )
        }

        // Step 3: Create (merge)
        let result = try await createFile(
            accessToken: token,
            remotePath: remotePath,
            uploadID: uploadID,
            blockList: blockList
        )

        guard let path = result["path"] as? String,
              let url = URL(string: "https://pan.baidu.com\(path)") else {
            throw CloudProviderError.uploadFailed("File created but URL unavailable")
        }
        return url
    }

    func download(remotePath: String) async throws -> Data {
        guard let token = accessToken else {
            throw CloudProviderError.notAuthenticated
        }

        var components = URLComponents(string: "\(apiBase)/download")!
        components.queryItems = [
            URLQueryItem(name: "access_token", value: token),
            URLQueryItem(name: "path", value: remotePath)
        ]

        guard let url = components.url else {
            throw CloudProviderError.downloadFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudProviderError.downloadFailed("HTTP error")
        }

        return data
    }

    func list(path: String) async throws -> [CloudFile] {
        guard let token = accessToken else {
            throw CloudProviderError.notAuthenticated
        }

        var components = URLComponents(string: "\(apiBase)/list")!
        components.queryItems = [
            URLQueryItem(name: "access_token", value: token),
            URLQueryItem(name: "path", value: path),
            URLQueryItem(name: "dir", value: "1"),
            URLQueryItem(name: "order", value: "time"),
            URLQueryItem(name: "desc", value: "1")
        ]

        guard let url = components.url else {
            throw CloudProviderError.uploadFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudProviderError.uploadFailed("List API error")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let list = json?["list"] as? [[String: Any]] ?? []

        return list.compactMap { item in
            guard let path = item["path"] as? String,
                  let name = item["filename"] as? String ?? item["server_filename"] as? String,
                  let isdirInt = item["isdir"] as? Int,
                  let size = item["size"] as? Int64 else { return nil }

            let modifiedAt: Date
            if let mtime = item["mtime"] as? TimeInterval {
                modifiedAt = Date(timeIntervalSince1970: mtime)
            } else {
                modifiedAt = Date()
            }

            return CloudFile(
                path: path,
                name: name,
                isDirectory: isdirInt == 1,
                size: size,
                modifiedAt: modifiedAt
            )
        }
    }

    func delete(path: String) async throws {
        guard let token = accessToken else {
            throw CloudProviderError.notAuthenticated
        }

        var components = URLComponents(string: "\(apiBase)/delete")!
        components.queryItems = [
            URLQueryItem(name: "access_token", value: token),
            URLQueryItem(name: "path", value: path)
        ]

        guard let url = components.url else {
            throw CloudProviderError.uploadFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudProviderError.uploadFailed("Delete API error")
        }
    }

    // MARK: - OAuth Flow

    private func performOAuthFlow(authURL: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            var authSession: ASWebAuthenticationSession?

            authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.manualcollector",
                completionHandler: { callbackURL, error in
                    if let error = error {
                        continuation.resume(throwing: CloudProviderError.networkError(error))
                        return
                    }

                    guard let callbackURL = callbackURL,
                          let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                          let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                        continuation.resume(throwing: CloudProviderError.uploadFailed("No auth code received"))
                        return
                    }

                    continuation.resume(returning: code)
                }
            )

            authSession?.presentationContextProvider = self
            authSession?.start()
        }
    }

    private func exchangeCodeForToken(code: String) async throws -> (accessToken: String, refreshToken: String?, expiresIn: Int) {
        var components = URLComponents(string: tokenURL)!
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: appKey),
            URLQueryItem(name: "client_secret", value: secretKey),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]

        guard let url = components.url else {
            throw CloudProviderError.uploadFailed("Invalid token URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudProviderError.uploadFailed("Token exchange failed")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let accessToken = json["access_token"] as? String else {
            throw CloudProviderError.uploadFailed("No access token in response")
        }

        let refreshToken = json["refresh_token"] as? String
        let expiresIn = json["expires_in"] as? Int ?? 2592000

        return (accessToken, refreshToken, expiresIn)
    }

    private func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw CloudProviderError.notAuthenticated
        }

        var components = URLComponents(string: tokenURL)!
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: appKey),
            URLQueryItem(name: "client_secret", value: secretKey)
        ]

        guard let url = components.url else {
            throw CloudProviderError.uploadFailed("Invalid refresh URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudProviderError.uploadFailed("Token refresh failed")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let accessToken = json["access_token"] as? String else {
            throw CloudProviderError.uploadFailed("No access token in refresh response")
        }

        self.accessToken = accessToken
        self.refreshToken = json["refresh_token"] as? String ?? refreshToken
        self.expiresAt = Date().addingTimeInterval(TimeInterval(json["expires_in"] as? Int ?? 2592000))
        self.isAuthenticated = true

        try saveToKeychain(token: accessToken, refresh: self.refreshToken ?? "")
    }

    // MARK: - Baidu Pan API

    private func precreateFile(accessToken: String, remotePath: String, fileSize: Int) async throws -> [String: Any] {
        var components = URLComponents(string: "\(apiBase)/precreate")!
        components.queryItems = [
            URLQueryItem(name: "access_token", value: accessToken)
        ]

        guard let url = components.url else {
            throw CloudProviderError.uploadFailed("Invalid precreate URL")
        }

        let body: [String: Any] = [
            "path": remotePath,
            "size": fileSize,
            "rtype": 1,
            "autoinit": 1,
            "block_list": [0]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudProviderError.uploadFailed("Precreate failed")
        }

        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private func uploadSlice(accessToken: String, remotePath: String, uploadID: String, blockIndex: Int, data: Data) async throws {
        var components = URLComponents(string: "\(apiBase)/upload")!
        components.queryItems = [
            URLQueryItem(name: "access_token", value: accessToken),
            URLQueryItem(name: "type", value: "tmpfile"),
            URLQueryItem(name: "path", value: remotePath),
            URLQueryItem(name: "uploadid", value: uploadID),
            URLQueryItem(name: "partseq", value: "\(blockIndex)")
        ]

        guard let url = components.url else {
            throw CloudProviderError.uploadFailed("Invalid upload URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudProviderError.uploadFailed("Slice upload failed at block \(blockIndex)")
        }
    }

    private func createFile(accessToken: String, remotePath: String, uploadID: String, blockList: [Int]) async throws -> [String: Any] {
        var components = URLComponents(string: "\(apiBase)/create")!
        components.queryItems = [
            URLQueryItem(name: "access_token", value: accessToken)
        ]

        guard let url = components.url else {
            throw CloudProviderError.uploadFailed("Invalid create URL")
        }

        let body: [String: Any] = [
            "path": remotePath,
            "size": -1,
            "rtype": 1,
            "uploadid": uploadID,
            "block_list": ["0"]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudProviderError.uploadFailed("File creation failed")
        }

        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    // MARK: - Keychain

    private func saveToKeychain(token: String, refresh: String) throws {
        let tokenData = token.data(using: .utf8)!
        let refreshData = refresh.data(using: .utf8)!

        let tokenQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.manualcollector.baidu.token",
            kSecValueData as String: tokenData
        ]
        SecItemDelete(tokenQuery as CFDictionary)
        SecItemAdd(tokenQuery as CFDictionary, nil)

        let refreshQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.manualcollector.baidu.refresh",
            kSecValueData as String: refreshData
        ]
        SecItemDelete(refreshQuery as CFDictionary)
        SecItemAdd(refreshQuery as CFDictionary, nil)
    }

    private func loadFromKeychain() -> (token: String?, refresh: String?) {
        let tokenQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.manualcollector.baidu.token",
            kSecReturnData as String: true
        ]
        var tokenResult: AnyObject?
        SecItemCopyMatching(tokenQuery as CFDictionary, &tokenResult)
        let token = (tokenResult as? Data).flatMap { String(data: $0, encoding: .utf8) }

        let refreshQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.manualcollector.baidu.refresh",
            kSecReturnData as String: true
        ]
        var refreshResult: AnyObject?
        SecItemCopyMatching(refreshQuery as CFDictionary, &refreshResult)
        let refresh = (refreshResult as? Data).flatMap { String(data: $0, encoding: .utf8) }

        return (token, refresh)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension BaiduCloudProvider: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    if window.isKeyWindow {
                        return window
                    }
                }
            }
        }
        return UIWindow()
    }
}
