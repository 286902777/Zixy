import CoreTelephony
import Foundation
import Security
import UIKit

enum ZixyRuntimeContextError: Error {
    case keychain(OSStatus)
}

@MainActor
final class ZixyRuntimeContext {

    static let shared = ZixyRuntimeContext()

    struct SupportedApplication: Sendable {
        let displayName: String
        let urlScheme: String
    }

    private enum StorageSlot {
        static let deviceIdentifier = ZixyRuntimeText.reveal(
            [
                136, 45, 178, 183, 246, 177, 182, 27, 248, 165, 226,
                165, 148, 201, 222, 115, 168, 93, 18, 103, 28, 209
            ],
            seed: 91
        )
        static let pushToken = ZixyRuntimeText.reveal(
            [
                187, 56, 189, 66, 229, 28, 1, 46, 131, 186, 117, 154,
                183, 220, 113
            ],
            seed: 104
        )
        static let userToken = ZixyRuntimeText.reveal(
            [
                166, 203, 72, 93, 208, 7, 44, 233, 94, 169, 64, 149,
                162, 47, 124
            ],
            seed: 117
        )
        static let userPassword = ZixyRuntimeText.reveal(
            [
                81, 198, 91, 104, 223, 18, 95, 228, 73, 148, 115, 240,
                157, 138, 167, 92, 161, 30
            ],
            seed: 130
        )
        static let loginState = ZixyRuntimeText.reveal(
            [
                92, 209, 102, 123, 202, 109, 74, 247, 116, 131, 158,
                115, 40, 85, 90, 206, 164, 233, 94, 195, 64
            ],
            seed: 143
        )
    }

    private static let supportedApplications = [
        SupportedApplication(displayName: "WhatsApp", urlScheme: "whatsapp"),
        SupportedApplication(displayName: "Instagram", urlScheme: "instagram"),
        SupportedApplication(displayName: "TikTok", urlScheme: "tiktok"),
        SupportedApplication(displayName: "Google Maps", urlScheme: "comgooglemaps"),
        SupportedApplication(displayName: "X", urlScheme: "twitter"),
        SupportedApplication(displayName: "QQ", urlScheme: "mqq"),
        SupportedApplication(displayName: "WeChat", urlScheme: "wechat"),
        SupportedApplication(displayName: "Alipay", urlScheme: "alipay"),
        SupportedApplication(displayName: "PhonePe", urlScheme: "phonepe"),
        SupportedApplication(displayName: "Paytm", urlScheme: "paytmmp")
    ]

    private let preferences: UserDefaults
    private let locker: ZixyKeychainLocker

    private init(
        defaults: UserDefaults = .standard,
        secureStore: ZixyKeychainLocker? = nil
    ) {
        preferences = defaults
        locker = secureStore ?? ZixyKeychainLocker()
    }

    var pushToken: String {
        preferences.string(forKey: StorageSlot.pushToken) ?? ""
    }

    var isLoggedIn: Bool {
        preferences.bool(forKey: StorageSlot.loginState)
    }

    func updateLoginState(_ isLoggedIn: Bool) {
        preferences.set(isLoggedIn, forKey: StorageSlot.loginState)
    }

    func updatePushToken(_ token: String?) {
        let value = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            preferences.removeObject(forKey: StorageSlot.pushToken)
            return
        }
        preferences.set(value, forKey: StorageSlot.pushToken)
    }

    func installedSupportedApplications() -> [SupportedApplication] {
        Self.supportedApplications.filter { application in
            guard let url = URL(string: "\(application.urlScheme)://") else {
                return false
            }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    func storeUserToken(_ token: String) throws {
        try locker.save(token, account: StorageSlot.userToken)
    }

    func userToken() throws -> String? {
        try locker.load(account: StorageSlot.userToken)
    }

    func storeUserPassword(_ password: String) throws {
        try locker.save(password, account: StorageSlot.userPassword)
    }

    func userPassword() throws -> String? {
        try locker.load(account: StorageSlot.userPassword)
    }

    func clearUserCredentials() throws {
        var firstError: Error?

        do {
            try locker.delete(account: StorageSlot.userToken)
        } catch {
            firstError = error
        }

        do {
            try locker.delete(account: StorageSlot.userPassword)
        } catch {
            firstError = firstError ?? error
        }

        if let firstError {
            throw firstError
        }
        updateLoginState(false)
    }

    func persistentDeviceIdentifier() throws -> String {
        if let identifier = try locker.load(
            account: StorageSlot.deviceIdentifier
        ), !identifier.isEmpty {
            return identifier
        }

        let vendorIdentifier = UIDevice.current.identifierForVendor?.uuidString
            ?? UUID().uuidString
        let identifier = vendorIdentifier
            + ZixyPayloadCipher.Configuration.applicationIdentifier
        try locker.save(
            identifier,
            account: StorageSlot.deviceIdentifier
        )
        return identifier
    }

    func hasCellularSubscription() -> Bool {
        guard let providers = CTTelephonyNetworkInfo()
            .serviceSubscriberCellularProviders else {
            return false
        }

        return providers.values.contains { provider in
            let values: [String?] = [
                provider.mobileCountryCode,
                provider.mobileNetworkCode,
                provider.isoCountryCode,
                provider.carrierName
            ]

            return values.compactMap { $0 }.contains { value in
                !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

}

@MainActor
private final class ZixyKeychainLocker {

    private let service: String

    init(bundleIdentifier: String? = Bundle.main.bundleIdentifier) {
        let fallbackBundle = ZixyRuntimeText.reveal(
            [115, 224, 117, 10],
            seed: 160
        )
        let namespace = ZixyRuntimeText.reveal(
            [
                142, 147, 112, 133, 194, 207, 134,
                225, 126, 99, 184, 13, 242, 159
            ],
            seed: 173
        )
        service = "\(bundleIdentifier ?? fallbackBundle).\(namespace)"
    }

    func load(account: String) throws -> String? {
        var query = makeQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw ZixyRuntimeContextError.keychain(status)
        }
        guard
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            throw ZixyRuntimeContextError.keychain(errSecDecode)
        }
        return value
    }

    func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query = makeQuery(account: account)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw ZixyRuntimeContextError.keychain(updateStatus)
        }

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw ZixyRuntimeContextError.keychain(addStatus)
        }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(makeQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ZixyRuntimeContextError.keychain(status)
        }
    }

    private func makeQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private enum ZixyRuntimeText {

    static func reveal(_ payload: [UInt8], seed: UInt8) -> String {
        let clearBytes = payload.enumerated().map { offset, byte -> UInt8 in
            let step = UInt8(truncatingIfNeeded: offset &* 11)
            let rotated = byte ^ (seed &+ step)
            return (rotated >> 3) | (rotated << 5)
        }
        return String(decoding: clearBytes, as: UTF8.self)
    }
}
