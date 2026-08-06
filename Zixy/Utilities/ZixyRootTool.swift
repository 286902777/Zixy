import Foundation
import UIKit

@MainActor
final class ZixyRootTool {

    static let shared = ZixyRootTool()

    private enum RemotePath {
        static let routeConfiguration = ZixyRouteText.open(
            [239, 1, 255, 196, 20, 220, 217, 53, 41, 65, 71, 60],
            salt: 37
        )
        static let automaticLogin = ZixyRouteText.open(
            [2, 20, 18, 215, 39, 239, 236, 72, 60, 84, 90, 78],
            salt: 56
        )
        static let webOpenTime = ZixyRouteText.open(
            [8, 26, 24, 221, 45, 245, 242, 78, 66, 90, 96, 92],
            salt: 62
        )
        static let payment = ZixyRouteText.open(
            [21, 39, 37, 234, 58, 2, 255, 91, 79, 103, 109, 109],
            salt: 75
        )
    }

    private enum RoutePreference {
        static let enabled = ZixyRouteText.open(
            [
                61, 49, 73, 79, 5, 88, 72, 87, 96, 110, 100, 165, 137,
                131, 144, 152, 142, 96, 156, 174, 174, 184, 193, 191, 199
            ],
            salt: 94
        )
        static let host = ZixyRouteText.open(
            [
                80, 68, 92, 98, 24, 107, 91, 106, 115, 129, 119, 184,
                156, 150, 163, 171, 161, 115, 188, 192, 211, 213, 5, 226,
                240, 233
            ],
            salt: 113
        )
        static let loginFlag = ZixyRouteText.open(
            [
                99, 87, 111, 117, 43, 126, 110, 125, 134, 148, 138, 203,
                175, 169, 182, 190, 180, 134, 203, 211, 210, 227, 233, 31,
                239, 252, 254, 3
            ],
            salt: 132
        )
    }

    private enum ReplyRule {
        static let acceptedCode = ZixyRouteText.open(
            [44, 51, 58, 65],
            salt: 151
        )
    }

    private enum HeaderField {
        static let appVersion = ZixyRouteText.open(
            [110, 134, 141, 178, 134, 164, 170, 167, 172, 180],
            salt: 170
        )
        static let bundleVersion = ZixyRouteText.open(
            [
                163, 167, 178, 162, 164, 161, 176, 174, 235, 201, 205,
                225, 226, 11, 223, 253, 3, 0, 5, 13, 63, 33, 46, 42,
                48, 46
            ],
            salt: 189
        )
        static let fallbackVersion = ZixyRouteText.open(
            [100, 98, 115, 112, 129],
            salt: 208
        )
        static let deviceNumber = ZixyRouteText.open(
            [164, 170, 196, 196, 197, 198, 248, 222],
            salt: 227
        )
        static let pushToken = ZixyRouteText.open(
            [203, 205, 218, 216, 3, 227, 238, 231, 249],
            salt: 246
        )
        static let loginToken = ZixyRouteText.open(
            [210, 218, 217, 234, 240, 29, 253, 8, 1, 19],
            salt: 9
        )
        static let applicationIdentifier = ZixyRouteText.open(
            [224, 248, 255, 29, 249],
            salt: 28
        )
    }

    private let apiClient: ZixyAPIClient
    private let runtimeContext: ZixyRuntimeContext
    private let defaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var routeTask: Task<Void, Never>?

    private init(
        apiClient: ZixyAPIClient? = nil,
        runtimeContext: ZixyRuntimeContext? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.apiClient = apiClient ?? .shared
        self.runtimeContext = runtimeContext ?? .shared
        self.defaults = defaults
    }

    func start() {
        routeTask?.cancel()
        routeTask = Task { [weak self] in
            guard let self else {
                return
            }
            _ = await refreshRouteConfiguration()
            guard !Task.isCancelled else {
                return
            }
            restoreSessionRoot()
            routeTask = nil
        }
    }

    func restoreSessionRoot(animated: Bool = true) {
        if ZixySessionStore.hasActiveSession {
            showMain(asGuest: ZixySessionStore.isGuest, animated: animated)
        } else {
            showAuthentication(animated: animated)
        }
    }

    func showMain(asGuest: Bool, animated: Bool = true) {
        if asGuest {
            ZixySessionStore.markGuest()
        } else {
            ZixySessionStore.markAuthenticated()
        }

        replaceRoot(
            with: ZixyMainContainerController(isGuest: asGuest),
            animated: animated
        )
    }

    func showAuthentication(
        clearingSession: Bool = false,
        animated: Bool = true
    ) {
        if clearingSession {
            ZixySessionStore.clear()
        }

        let controller = ZixyAccessCoordinator()
        controller.onAuthenticated = { [weak self] in
            self?.showMain(asGuest: false)
        }
        controller.onGuestAccess = { [weak self] in
            self?.showMain(asGuest: true)
        }
        replaceRoot(with: controller, animated: animated)
    }

    @discardableResult
    func refreshRouteConfiguration() async -> Bool {
        do {
            let payload = RouteProbe(
                hasCellularSubscription: runtimeContext.hasCellularSubscription() ? 1 : 0,
                installedApplications: runtimeContext
                    .installedSupportedApplications()
                    .map(\.displayName),
                debugFlag: 0
            )
            let envelope: ZixyRemoteEnvelope = try await apiClient.request(
                RemotePath.routeConfiguration,
                method: .post,
                body: payload,
                headers: try makeRequestHeaders()
            )
            guard let configuration: RouteDirective = unpackResult(
                from: envelope
            ) else {
                return false
            }

            defaults.set(true, forKey: RoutePreference.enabled)
            defaults.set(configuration.loginFlag, forKey: RoutePreference.loginFlag)
            if let hostURL = configuration.hostURL, !hostURL.isEmpty {
                defaults.set(hostURL, forKey: RoutePreference.host)
            }
            return true
        } catch {
            return false
        }
    }

    func performAutomaticLogin() async -> Bool {
        do {
            let payload = AccessProbe(
                account: "",
                password: try runtimeContext.userPassword() ?? "",
                deviceIdentifier: try runtimeContext.persistentDeviceIdentifier()
            )
            let envelope: ZixyRemoteEnvelope = try await apiClient.request(
                RemotePath.automaticLogin,
                method: .post,
                body: payload,
                headers: try makeRequestHeaders()
            )
            guard let credentials: AccessGrant = unpackResult(
                from: envelope
            ) else {
                return false
            }

            if let token = credentials.token, !token.isEmpty {
                try runtimeContext.storeUserToken(token)
            }
            if let password = credentials.password, !password.isEmpty {
                try runtimeContext.storeUserPassword(password)
            }
            let didAuthenticate = credentials.token?.isEmpty == false
            if didAuthenticate {
                runtimeContext.updateLoginState(true)
            }
            return didAuthenticate
        } catch {
            return false
        }
    }

    func reportWebOpen(time: String) async -> Bool {
        let value = time.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return false
        }

        do {
            let envelope: ZixyRemoteEnvelope = try await apiClient.request(
                RemotePath.webOpenTime,
                method: .post,
                body: PortalOpenReport(time: value),
                headers: try makeRequestHeaders()
            )
            return envelope.code == ReplyRule.acceptedCode
        } catch {
            return false
        }
    }

    func reportPayment(
        transactionNumber: String,
        orderCode: String,
        receipt: String
    ) async -> Bool {
        guard
            !transactionNumber.isEmpty,
            !orderCode.isEmpty,
            !receipt.isEmpty,
            let orderData = try? encoder.encode(PaymentOrder(code: orderCode)),
            let orderJSON = String(data: orderData, encoding: .utf8)
        else {
            return false
        }

        do {
            let envelope: ZixyRemoteEnvelope = try await apiClient.request(
                RemotePath.payment,
                method: .post,
                body: CommerceReport(
                    transactionNumber: transactionNumber,
                    receipt: receipt,
                    orderJSON: orderJSON
                ),
                headers: try makeRequestHeaders()
            )
            return envelope.code == ReplyRule.acceptedCode
        } catch {
            return false
        }
    }

    private func makeRequestHeaders() throws -> [String: String] {
        [
            HeaderField.appVersion: Bundle.main.object(
                forInfoDictionaryKey: HeaderField.bundleVersion
            ) as? String ?? HeaderField.fallbackVersion,
            HeaderField.deviceNumber: try runtimeContext
                .persistentDeviceIdentifier(),
            HeaderField.pushToken: runtimeContext.pushToken,
            HeaderField.loginToken: try runtimeContext.userToken() ?? "",
            HeaderField.applicationIdentifier:
                ZixyPayloadCipher.Configuration.applicationIdentifier
        ]
    }

    private func unpackResult<Value: Decodable>(
        from envelope: ZixyRemoteEnvelope
    ) -> Value? {
        guard
            envelope.code == ReplyRule.acceptedCode,
            let encryptedResult = envelope.result,
            !encryptedResult.isEmpty
        else {
            return nil
        }

        let decryptedResult = ZixyPayloadCipher.decrypt(encryptedResult)
        guard let data = decryptedResult.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(Value.self, from: data)
    }

    private func replaceRoot(
        with controller: UIViewController,
        animated: Bool
    ) {
        guard let window = currentWindow() else {
            return
        }

        guard animated else {
            window.rootViewController = controller
            window.makeKeyAndVisible()
            return
        }

        UIView.transition(
            with: window,
            duration: 0.3,
            options: [.transitionCrossDissolve, .allowAnimatedContent],
            animations: {
                window.rootViewController = controller
            }
        )
    }

    private func currentWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        return scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
    }
}

private struct ZixyRemoteEnvelope: Decodable {
    let code: String
    let message: String?
    let result: String?
}

private struct RouteProbe: Encodable {
    let hasCellularSubscription: Int
    let installedApplications: [String]
    let debugFlag: Int

    enum CodingKeys: String, CodingKey {
        case hasCellularSubscription = "zixyd"
        case installedApplications = "zixys"
        case debugFlag = "zixyg"
    }
}

private struct AccessProbe: Encodable {
    let account: String
    let password: String
    let deviceIdentifier: String

    enum CodingKeys: String, CodingKey {
        case account = "zixya"
        case password = "zixyd"
        case deviceIdentifier = "zixyn"
    }
}

private struct PortalOpenReport: Encodable {
    let time: String

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        let key = ZixyRouteText.open([68, 56, 80, 86, 75], salt: 101)
        try container.encode(time, forKey: DynamicCodingKey(key))
    }
}

private struct CommerceReport: Encodable {
    let transactionNumber: String
    let receipt: String
    let orderJSON: String

    enum CodingKeys: String, CodingKey {
        case transactionNumber = "zixyt"
        case receipt = "zixyp"
        case orderJSON = "zixyc"
    }
}

private struct PaymentOrder: Encodable {
    let code: String

    enum CodingKeys: String, CodingKey {
        case code = "orderCode"
    }
}

private struct AccessGrant: Decodable {
    let token: String?
    let password: String?
}

private struct RouteDirective: Decodable {
    let hostURL: String?
    let loginFlag: Int

    enum CodingKeys: String, CodingKey {
        case hostURL = "openValue"
        case loginFlag
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hostURL = try? values.decodeIfPresent(String.self, forKey: .hostURL)

        if let value = try? values.decode(Int.self, forKey: .loginFlag) {
            loginFlag = value
        } else if let value = try? values.decode(String.self, forKey: .loginFlag) {
            loginFlag = Int(value) ?? 0
        } else if let value = try? values.decode(Bool.self, forKey: .loginFlag) {
            loginFlag = value ? 1 : 0
        } else {
            loginFlag = 0
        }
    }
}

private enum ZixyRouteText {

    static func open(_ payload: [UInt8], salt: UInt8) -> String {
        let clearBytes = payload.enumerated().map { offset, byte in
            let step = UInt8(truncatingIfNeeded: offset &* 7)
            return (byte &- salt &- step) ^ 0xA5
        }
        return String(decoding: clearBytes, as: UTF8.self)
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        return nil
    }
}
