import UIKit

final class ZixyAccessCoordinator: UINavigationController {

    var onAuthenticated: (() -> Void)?
    var onGuestAccess: (() -> Void)?
    private var pendingRegistrationIdentifier: String?

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
        controller.onRegistrationReady = { [weak self] identifier in
            self?.pendingRegistrationIdentifier = identifier
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
        controller.onCompleted = { [weak self] in
            guard let self else {
                return
            }
            if let identifier = pendingRegistrationIdentifier {
                ZixySessionStore.setCurrentUserIdentifier(identifier)
            }
            pendingRegistrationIdentifier = nil
            onAuthenticated?()
        }
        pushViewController(controller, animated: true)
    }
}
