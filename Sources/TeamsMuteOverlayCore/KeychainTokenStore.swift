import Foundation
import Security

public protocol TokenStore: Sendable {
    func loadToken() -> String?
    func saveToken(_ token: String) throws
    func deleteToken() throws
}

public enum KeychainTokenStoreError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed with status \(status)"
        case .deleteFailed(let status):
            return "Keychain delete failed with status \(status)"
        }
    }
}

public final class KeychainTokenStore: TokenStore {
    private let service: String
    private let account: String

    public init(service: String = "TeamsMuteOverlay", account: String = "teams-api-token") {
        self.service = service
        self.account = account
    }

    public func loadToken() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    public func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        var query = baseQuery()
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw KeychainTokenStoreError.saveFailed(updateStatus)
        }

        query[kSecValueData as String] = data
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainTokenStoreError.saveFailed(addStatus)
        }
    }

    public func deleteToken() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainTokenStoreError.deleteFailed(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

public final class MemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    public init(token: String? = nil) {
        self.token = token
    }

    public func loadToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    public func saveToken(_ token: String) {
        lock.lock()
        defer { lock.unlock() }
        self.token = token
    }

    public func deleteToken() {
        lock.lock()
        defer { lock.unlock() }
        token = nil
    }
}
