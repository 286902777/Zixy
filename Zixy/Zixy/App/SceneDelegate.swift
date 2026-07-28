//
//  SceneDelegate.swift
//  Zixy
//
//  Created by myfy on 2026/7/27.
//

import UIKit
import Darwin

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let rootController: UIViewController = ZixySessionStore.hasActiveSession
            ? ZixyMainContainerController(isGuest: ZixySessionStore.isGuest)
            : makeZixyAccessCoordinator()

        if window == nil {
            window = UIWindow(windowScene: windowScene)
        }
        window?.rootViewController = rootController
        window?.makeKeyAndVisible()

        presentEULAIfNeeded(from: rootController)
    }

    private func makeZixyAccessCoordinator() -> ZixyAccessCoordinator {
        let controller = ZixyAccessCoordinator()
        controller.onAuthenticated = { [weak self] in
            self?.showMainInterface(asGuest: false)
        }
        controller.onGuestAccess = { [weak self] in
            self?.showMainInterface(asGuest: true)
        }
        return controller
    }

    private func presentEULAIfNeeded(from presenter: UIViewController) {
        guard !UserDefaults.standard.bool(
            forKey: ZixyTermsController.acceptedDefaultsKey
        ) else {
            return
        }

        let controller = ZixyTermsController(
            requiresAcceptance: true,
            onAgree: { [weak presenter] in
                presenter?.dismiss(animated: true)
            },
            onCancel: {
                exit(EXIT_SUCCESS)
            }
        )
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        DispatchQueue.main.async {
            presenter.present(controller, animated: true)
        }
    }

    private func showMainInterface(asGuest: Bool) {
        guard let window else {
            return
        }
        if asGuest {
            ZixySessionStore.markGuest()
        } else {
            ZixySessionStore.markAuthenticated()
        }
        let controller = ZixyMainContainerController(isGuest: asGuest)
        UIView.transition(
            with: window,
            duration: 0.3,
            options: [.transitionCrossDissolve],
            animations: {
                window.rootViewController = controller
            }
        )
    }

    func showAuthenticationInterface() {
        guard let window else {
            return
        }
        let controller = makeZixyAccessCoordinator()
        UIView.transition(
            with: window,
            duration: 0.3,
            options: [.transitionCrossDissolve],
            animations: {
                window.rootViewController = controller
            }
        )
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}
