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

    private enum Configuration {
        static let deviceIdentifierKey = "zixy.device.identifier"
        static let pushTokenKey = "zixy.push.token"
        static let userTokenKey = "zixy.user.token"
        static let userPasswordKey = "zixy.user.password"
    }

    private static let supportedApplications = [
        SupportedApplication(displayName: "WhatsApp", urlScheme: "whatsapp"),
        SupportedApplication(displayName: "Instagram", urlScheme: "instagram"),
        SupportedApplication(displayName: "TikTok", urlScheme: "tiktok"),
        SupportedApplication(displayName: "Google Maps", urlScheme: "comgooglemaps"),
        SupportedApplication(displayName: "X", urlScheme: "twitter"),
        SupportedApplication(displayName: "QQ", urlScheme: "mqq"),
        SupportedApplication(displayName: "WeChat", urlScheme: "wechat"),
        SupportedApplication(displayName: "Alipay", urlScheme: "alipay")
    ]

    private let defaults: UserDefaults
    private let secureStore: ZixyDeviceSecureStore

    private init(
        defaults: UserDefaults = .standard,
        secureStore: ZixyDeviceSecureStore? = nil
    ) {
        self.defaults = defaults
        self.secureStore = secureStore ?? ZixyDeviceSecureStore()
    }

    var pushToken: String {
        defaults.string(forKey: Configuration.pushTokenKey) ?? ""
    }

    func updatePushToken(_ token: String?) {
        let value = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            defaults.removeObject(forKey: Configuration.pushTokenKey)
            return
        }
        defaults.set(value, forKey: Configuration.pushTokenKey)
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
        try secureStore.save(token, account: Configuration.userTokenKey)
    }

    func userToken() throws -> String? {
        try secureStore.load(account: Configuration.userTokenKey)
    }

    func storeUserPassword(_ password: String) throws {
        try secureStore.save(password, account: Configuration.userPasswordKey)
    }

    func userPassword() throws -> String? {
        try secureStore.load(account: Configuration.userPasswordKey)
    }

    func clearUserCredentials() throws {
        var firstError: Error?

        do {
            try secureStore.delete(account: Configuration.userTokenKey)
        } catch {
            firstError = error
        }

        do {
            try secureStore.delete(account: Configuration.userPasswordKey)
        } catch {
            firstError = firstError ?? error
        }

        if let firstError {
            throw firstError
        }
    }

    func persistentDeviceIdentifier() throws -> String {
        if let identifier = try secureStore.load(
            account: Configuration.deviceIdentifierKey
        ), !identifier.isEmpty {
            return identifier
        }

        let vendorIdentifier = UIDevice.current.identifierForVendor?.uuidString
            ?? UUID().uuidString
        let identifier = vendorIdentifier
            + ZixyPayloadCipher.Configuration.applicationIdentifier
        try secureStore.save(
            identifier,
            account: Configuration.deviceIdentifierKey
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
private final class ZixyDeviceSecureStore {

    private let service: String

    init(bundleIdentifier: String? = Bundle.main.bundleIdentifier) {
        service = "\(bundleIdentifier ?? "zixy").device-context"
    }

    func load(account: String) throws -> String? {
        var query = baseQuery(account: account)
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
        let query = baseQuery(account: account)
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
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ZixyRuntimeContextError.keychain(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
