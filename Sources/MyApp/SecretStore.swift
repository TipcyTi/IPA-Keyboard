import Foundation
import Security

/// API keys live in the Keychain first. Unsigned / re-signed installs sometimes
/// lack the entitlements Keychain requires, so a file fallback keeps the app usable
/// while still keeping secrets out of the conversation store.
enum SecretStore {
    private static let service = "com.tipcyti.aichat.apikey"

    private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let url = base.appendingPathComponent("AIChat", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func fileURL(_ id: UUID) -> URL {
        folder.appendingPathComponent("k-\(id.uuidString).sec")
    }

    static func save(_ value: String, for id: UUID) {
        guard !value.isEmpty else {
            delete(id)
            return
        }
        if keychainSave(value, for: id) {
            try? FileManager.default.removeItem(at: fileURL(id))
        } else {
            keychainDelete(id)
            writeFile(value, for: id)
        }
    }

    static func read(_ id: UUID) -> String? {
        if let value = keychainRead(id) { return value }
        return readFile(id)
    }

    static func delete(_ id: UUID) {
        keychainDelete(id)
        try? FileManager.default.removeItem(at: fileURL(id))
    }

    // MARK: Keychain

    private static func keychainSave(_ value: String, for id: UUID) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        keychainDelete(id)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private static func keychainRead(_ id: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainDelete(_ id: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]
        _ = SecItemDelete(query as CFDictionary)
    }

    // MARK: File fallback

    private static func writeFile(_ value: String, for id: UUID) {
        guard let data = value.data(using: .utf8) else { return }
        let url = fileURL(id)
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try? mutableURL.setResourceValues(values)
    }

    private static func readFile(_ id: UUID) -> String? {
        guard let data = try? Data(contentsOf: fileURL(id)) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
