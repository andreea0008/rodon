import Foundation
import Security

// Reads the WireGuard private key from the shared Keychain access group,
// where the main app stores it. Service/account/group MUST match the app's
// KeychainStore (KeychainStore_apple.mm).
enum KeychainBridge {
    private static let service = "com.rodon.vpn"
    private static let account = "wg-private-key"
    private static let accessGroup = "H8GLL2MY9E.com.rodon.shared"

    static func loadPrivateKey() -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        query[kSecAttrAccessGroup as String] = accessGroup

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key
    }
}
