import Foundation
import UIKit

@MainActor
final class ZixyRootTool {

    static let shared = ZixyRootTool()

    private enum Endpoint {
        static let routeConfiguration = "opi/v1/zixyo"
        static let automaticLogin = "opi/v1/zixyl"
        static let webOpenTime = "opi/v1/zixyt"
        static let payment = "opi/v1/zixyp"
    }

    private enum DefaultsKey {
        static let remoteRouteEnabled = "zixy.remote_route.enabled"
        static let remoteHostURL = "zixy.remote_route.host_url"
        static let loginFlag = "zixy.remote_route.login_flag"
    }

    private enum Configuration {
        static let successCode = "0000"
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
            let payload = RouteRequest(
                hasCellularSubscription: runtimeContext.hasCellularSubscription() ? 1 : 0,
                installedApplications: runtimeContext
                    .installedSupportedApplications()
                    .map(\.displayName),
                debugFlag: 0
            )
            let envelope: APIEnvelope = try await apiClient.request(
                Endpoint.routeConfiguration,
                method: .post,
                body: payload,
                headers: try requestHeaders()
            )
            guard let configuration: RouteConfiguration = decodedResult(
                from: envelope
            ) else {
                return false
            }

            defaults.set(true, forKey: DefaultsKey.remoteRouteEnabled)
            defaults.set(configuration.loginFlag, forKey: DefaultsKey.loginFlag)
            if let hostURL = configuration.hostURL, !hostURL.isEmpty {
                defaults.set(hostURL, forKey: DefaultsKey.remoteHostURL)
            }
            return true
        } catch {
            return false
        }
    }

    func performAutomaticLogin() async -> Bool {
        do {
            let payload = LoginRequest(
                account: "",
                password: try runtimeContext.userPassword() ?? "",
                deviceIdentifier: try runtimeContext.persistentDeviceIdentifier()
            )
            let envelope: APIEnvelope = try await apiClient.request(
                Endpoint.automaticLogin,
                method: .post,
                body: payload,
                headers: try requestHeaders()
            )
            guard let credentials: LoginCredentials = decodedResult(
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
            return credentials.token?.isEmpty == false
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
            let envelope: APIEnvelope = try await apiClient.request(
                Endpoint.webOpenTime,
                method: .post,
                body: WebOpenRequest(time: value),
                headers: try requestHeaders()
            )
            return envelope.code == Configuration.successCode
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
            let envelope: APIEnvelope = try await apiClient.request(
                Endpoint.payment,
                method: .post,
                body: PaymentRequest(
                    transactionNumber: transactionNumber,
                    receipt: receipt,
                    orderJSON: orderJSON
                ),
                headers: try requestHeaders()
            )
            return envelope.code == Configuration.successCode
        } catch {
            return false
        }
    }

    private func requestHeaders() throws -> [String: String] {
        [
            "appVersion": Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "1.0.0",
            "deviceNo": try runtimeContext.persistentDeviceIdentifier(),
            "pushToken": runtimeContext.pushToken,
            "loginToken": try runtimeContext.userToken() ?? "",
            "appId": ZixyPayloadCipher.Configuration.applicationIdentifier
        ]
    }

    private func decodedResult<Value: Decodable>(
        from envelope: APIEnvelope
    ) -> Value? {
        guard
            envelope.code == Configuration.successCode,
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

private struct APIEnvelope: Decodable {
    let code: String
    let message: String?
    let result: String?
}

private struct RouteRequest: Encodable {
    let hasCellularSubscription: Int
    let installedApplications: [String]
    let debugFlag: Int

    enum CodingKeys: String, CodingKey {
        case hasCellularSubscription = "zixyd"
        case installedApplications = "zixys"
        case debugFlag = "zixyg"
    }
}

private struct LoginRequest: Encodable {
    let account: String
    let password: String
    let deviceIdentifier: String

    enum CodingKeys: String, CodingKey {
        case account = "zixya"
        case password = "zixyd"
        case deviceIdentifier = "zixyn"
    }
}

private struct WebOpenRequest: Encodable {
    let time: String

    enum CodingKeys: String, CodingKey {
        case time = "zixyo"
    }
}

private struct PaymentRequest: Encodable {
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

private struct LoginCredentials: Decodable {
    let token: String?
    let password: String?
}

private struct RouteConfiguration: Decodable {
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
