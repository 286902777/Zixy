import Foundation
import Security

extension Notification.Name {
    static let zixyCoinBalanceDidChange = Notification.Name(
        "zixy_coin_balance_did_change"
    )
}

enum ZixyCoinBalanceStoreError: Error {
    case invalidAccount
    case keychain(OSStatus)
}

enum ZixyCoinBalanceStore {

    private static let service = "com.zixy.coin-balance"

    static func normalizedAccount(_ identifier: String) -> String {
        identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func balance(for identifier: String) -> Int {
        let account = normalizedAccount(identifier)
        guard !account.isEmpty else {
            return 0
        }
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8),
            let balance = Int(value)
        else {
            return 0
        }
        return max(0, balance)
    }

    static func setBalance(
        _ balance: Int,
        for identifier: String
    ) throws {
        let account = normalizedAccount(identifier)
        guard !account.isEmpty else {
            throw ZixyCoinBalanceStoreError.invalidAccount
        }
        let value = max(0, balance)
        let data = Data(String(value).utf8)
        let query = baseQuery(account: account)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw ZixyCoinBalanceStoreError.keychain(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw ZixyCoinBalanceStoreError.keychain(updateStatus)
        }

        NotificationCenter.default.post(
            name: .zixyCoinBalanceDidChange,
            object: account,
            userInfo: ["balance": value]
        )
    }

    @discardableResult
    static func spend(
        _ amount: Int,
        for identifier: String
    ) throws -> Bool {
        guard amount > 0 else {
            return true
        }
        let currentBalance = balance(for: identifier)
        guard currentBalance >= amount else {
            return false
        }
        try setBalance(currentBalance - amount, for: identifier)
        return true
    }

    static func deleteBalance(for identifier: String) throws {
        let account = normalizedAccount(identifier)
        guard !account.isEmpty else {
            throw ZixyCoinBalanceStoreError.invalidAccount
        }
        let status = SecItemDelete(
            baseQuery(account: account) as CFDictionary
        )
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ZixyCoinBalanceStoreError.keychain(status)
        }
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
