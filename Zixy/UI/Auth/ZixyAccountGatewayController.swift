import UIKit

final class ZixyAccountGatewayController: ZixyAuthCanvasController {

    var onLoginByEmail: (() -> Void)?

    private struct PortalOpenParameters: Encodable {
        let token: String
        let timestamp: Int64
    }

    private enum DefaultsKey {
        static let remoteHostURL = "zixy.remote_route.host_url"
    }

    private var loginTask: Task<Void, Never>?
    private var pendingWebController: ZixyInteractiveWebController?
    private var loadingStartedAt: Date?
    private var hasCheckedStoredPortal = false
    private var isPerformingAutomaticLogin = false
    private let loadingOverlay = ZixyLoadingOverlay()

    private lazy var loginButton: AuthEntryActionButton = {
        let button = AuthEntryActionButton(
            title: "Sign in by email",
            titleCenterOffset: 8,
            reversesGradient: false
        )
        button.addTarget(
            self,
            action: #selector(loginByEmail),
            for: .touchUpInside
        )
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureBackground()
        configureContent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enterStoredPortalIfAvailable()
    }

    private func enterStoredPortalIfAvailable() {
        guard
            !hasCheckedStoredPortal,
            ZixyRuntimeContext.shared.isLoggedIn
        else {
            return
        }
        hasCheckedStoredPortal = true

        guard let portalURL = makeLoginPortalURL() else {
            return
        }
        beginPortalOperation(message: "Loading...")
        presentPortal(at: portalURL)
    }

    private func configureBackground() {
        let backgroundView = UIImageView(
            image: ZixyImageLibrary.authEntryBackground
        )
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.contentMode = .scaleAspectFill
        backgroundView.clipsToBounds = true
        backgroundView.isUserInteractionEnabled = false

        view.insertSubview(backgroundView, belowSubview: scrollView)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureContent() {
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Handcraft Community"
        subtitleLabel.font = ZixyFontBook.bold(size: 20, relativeTo: .title3)
        subtitleLabel.textColor = UIColor(
            red: 20 / 255,
            green: 82 / 255,
            blue: 111 / 255,
            alpha: 1
        )
        subtitleLabel.textAlignment = .center

        [subtitleLabel, loginButton].forEach(view.addSubview)
        view.addSubview(loadingOverlay)

        let subtitleCenterY = NSLayoutConstraint(
            item: subtitleLabel,
            attribute: .centerY,
            relatedBy: .equal,
            toItem: view,
            attribute: .bottom,
            multiplier: 0.49,
            constant: 0
        )
        let loginCenterY = NSLayoutConstraint(
            item: loginButton,
            attribute: .centerY,
            relatedBy: .equal,
            toItem: view,
            attribute: .bottom,
            multiplier: 0.615,
            constant: 0
        )
        NSLayoutConstraint.activate([
            subtitleCenterY,
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            loginCenterY,
            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.widthAnchor.constraint(equalToConstant: 286),
            loginButton.heightAnchor.constraint(equalToConstant: 72),

            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func loginByEmail() {
        guard !isPerformingAutomaticLogin else {
            return
        }

        beginPortalOperation(message: "Signing in...")

        loginTask = Task { [weak self] in
            let succeeded = await ZixyRootTool.shared.performAutomaticLogin()
            guard let self, !Task.isCancelled else {
                return
            }

            await waitForMinimumLoadingDuration()
            guard !Task.isCancelled else {
                return
            }

            if succeeded, let portalURL = makeLoginPortalURL() {
                presentPortal(at: portalURL)
            } else {
                finishAutomaticLogin()
                if succeeded {
                    showToast("Unable to open the account page.")
                } else {
                    onLoginByEmail?()
                }
            }
        }
    }

    private func makeLoginPortalURL() -> URL? {
        guard
            let token = try? ZixyRuntimeContext.shared.userToken(),
            !token.isEmpty,
            let host = UserDefaults.standard.string(
                forKey: DefaultsKey.remoteHostURL
            ),
            !host.isEmpty,
            var components = URLComponents(string: host)
        else {
            return nil
        }

        let parameters = PortalOpenParameters(
            token: token,
            timestamp: Int64(Date().timeIntervalSince1970 * 1_000)
        )
        guard
            let data = try? JSONEncoder().encode(parameters),
            let json = String(data: data, encoding: .utf8),
            let encryptedParameters = try? ZixyPayloadCipher.encrypt(json)
        else {
            return nil
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll {
            $0.name == "openParams" || $0.name == "appId"
        }
        queryItems.append(
            URLQueryItem(name: "openParams", value: encryptedParameters)
        )
        queryItems.append(
            URLQueryItem(
                name: "appId",
                value: ZixyPayloadCipher.Configuration.applicationIdentifier
            )
        )
        components.queryItems = queryItems
        return components.url
    }

    private func presentPortal(at url: URL) {
        guard
            presentedViewController == nil,
            pendingWebController == nil
        else {
            finishAutomaticLogin()
            showToast("Unable to open the account page.")
            return
        }

        let controller = ZixyInteractiveWebController(destination: url)
        pendingWebController = controller
        controller.didResolveFirstNavigation = { [weak self, weak controller] succeeded in
            guard
                let self,
                let controller,
                pendingWebController === controller
            else {
                return
            }

            controller.didResolveFirstNavigation = nil
            resolvePresentedPortal(controller, succeeded: succeeded)
        }
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: false)
    }

    private func beginPortalOperation(message: String) {
        isPerformingAutomaticLogin = true
        loginButton.isEnabled = false
        loadingStartedAt = Date()
        loadingOverlay.show(message: message)
    }

    private func waitForMinimumLoadingDuration() async {
        guard let loadingStartedAt else {
            return
        }
        let elapsed = Date().timeIntervalSince(loadingStartedAt)
        guard elapsed < 1 else {
            return
        }
        let remainingNanoseconds = UInt64((1 - elapsed) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: remainingNanoseconds)
    }

    private func resolvePresentedPortal(
        _ controller: ZixyInteractiveWebController,
        succeeded: Bool
    ) {
        finishAutomaticLogin()
        guard !succeeded else {
            return
        }
        ZixyRuntimeContext.shared.updateLoginState(false)
        guard presentedViewController === controller else {
            showToast("Unable to open the account page.")
            return
        }
        dismiss(animated: false) { [weak self] in
            self?.showToast("Unable to open the account page.")
        }
    }

    private func finishAutomaticLogin() {
        loginTask = nil
        pendingWebController = nil
        loadingStartedAt = nil
        isPerformingAutomaticLogin = false
        loginButton.isEnabled = true
        loadingOverlay.hide()
    }
}
