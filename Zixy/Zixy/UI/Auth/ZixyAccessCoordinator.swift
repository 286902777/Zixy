import UIKit

final class ZixyAccessCoordinator: UINavigationController {

    var onAuthenticated: (() -> Void)?
    var onGuestAccess: (() -> Void)?
    private var pendingRegistrationIdentifier: String?
    private var pendingRegistrationPassword: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        interactivePopGestureRecognizer?.delegate = nil
        interactivePopGestureRecognizer?.isEnabled = true
        showEntry()
    }

    private func showEntry() {
        let controller = ZixyGatewayController()
        controller.onLoginByEmail = { [weak self] in
            self?.showLogin(mode: .signIn)
        }
        controller.onGuestAccess = { [weak self] in
            self?.onGuestAccess?()
        }
        controller.onSignUp = { [weak self] in
            self?.showLogin(mode: .signUp)
        }
        setViewControllers([controller], animated: false)
    }

    private func showLogin(mode: ZixySignInController.Mode) {
        let controller = ZixySignInController(mode: mode)
        controller.onSignedIn = { [weak self] identifier in
            ZixySessionStore.setCurrentUserIdentifier(identifier)
            self?.onAuthenticated?()
        }
        controller.onRegistrationReady = { [weak self] identifier, password in
            self?.pendingRegistrationIdentifier = identifier
            self?.pendingRegistrationPassword = password
            self?.showProfileSetup()
        }
        controller.onForgotPassword = { [weak self] in
            self?.showForgotPassword()
        }
        pushViewController(controller, animated: true)
    }

    private func showForgotPassword() {
        let controller = ZixyPasswordResetController()
        controller.onCompleted = { [weak self] in
            self?.popViewController(animated: true)
        }
        pushViewController(controller, animated: true)
    }

    private func showProfileSetup() {
        let controller = ZixyProfileSetupController()
        controller.onCompleted = { [weak self] username, avatarImage in
            guard let self else {
                return false
            }
            guard
                let identifier = pendingRegistrationIdentifier,
                let password = pendingRegistrationPassword
            else {
                return false
            }

            var avatarReference: String?
            do {
                if let avatarImage {
                    avatarReference = try ZixyUserAvatarStore.save(
                        avatarImage
                    )
                }
                _ = try ZixyDataStore.shared.registerUser(
                    username: username,
                    email: identifier,
                    password: password,
                    avatarAssetName: avatarReference
                        ?? "zixy_user_avatar"
                )
            } catch {
                if let avatarReference {
                    ZixyUserAvatarStore.remove(
                        reference: avatarReference
                    )
                }
                return false
            }
            ZixySessionStore.setCurrentUserIdentifier(identifier)
            pendingRegistrationIdentifier = nil
            pendingRegistrationPassword = nil
            onAuthenticated?()
            return true
        }
        pushViewController(controller, animated: true)
    }
}
