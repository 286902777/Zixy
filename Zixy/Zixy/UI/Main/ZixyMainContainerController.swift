import UIKit

final class ZixyMainContainerController: UITabBarController {

    private let isGuest: Bool
    private let zixyTabBar = ZixyDockBar()
    private var tabBarHeightConstraint: NSLayoutConstraint?
    private var isCustomTabBarHidden = false

    init(isGuest: Bool = false) {
        self.isGuest = isGuest
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        isGuest = false
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        configureControllers()
        configureTabBar()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tabBar.isHidden = true

        let bottomInset = view.window?.safeAreaInsets.bottom ?? 0
        tabBarHeightConstraint?.constant =
            ZixyDockBar.contentHeight + bottomInset
    }

    private func configureControllers() {
        let roots: [UIViewController] = [
            ZixyHomeController(),
            ZixyFeedController(),
            ZixyMessagesController(),
            ZixyProfileController()
        ]

        viewControllers = roots.map { rootController in
            let navigationController = UINavigationController(
                rootViewController: rootController
            )
            navigationController.setNavigationBarHidden(true, animated: false)
            navigationController.interactivePopGestureRecognizer?.delegate = nil
            navigationController.interactivePopGestureRecognizer?.isEnabled =
                true
            navigationController.delegate = self
            return navigationController
        }
        selectedIndex = 0
    }

    private func configureTabBar() {
        tabBar.isHidden = true

        zixyTabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(zixyTabBar)

        let heightConstraint = zixyTabBar.heightAnchor.constraint(
            equalToConstant: ZixyDockBar.contentHeight
        )
        tabBarHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            zixyTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            zixyTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            zixyTabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            heightConstraint
        ])

        zixyTabBar.configure(
            items: [
                ZixyDockBar.Item(
                    normalImageName: "zixy_tab_home_normal",
                    selectedImageName: "zixy_tab_home_selected",
                    accessibilityLabel: "Home"
                ),
                ZixyDockBar.Item(
                    normalImageName: "zixy_tab_rooms_normal",
                    selectedImageName: "zixy_tab_rooms_selected",
                    accessibilityLabel: "Feeds"
                ),
                ZixyDockBar.Item(
                    normalImageName: "zixy_tab_messages_normal",
                    selectedImageName: "zixy_tab_messages_selected",
                    accessibilityLabel: "Messages"
                ),
                ZixyDockBar.Item(
                    normalImageName: "zixy_tab_profile_normal",
                    selectedImageName: "zixy_tab_profile_selected",
                    accessibilityLabel: "Profile"
                )
            ]
        )
        if isGuest {
            (1...3).forEach { index in
                zixyTabBar.setEnabled(false, at: index)
            }
        }

        zixyTabBar.onSelectionChanged = { [weak self] index in
            guard let self else {
                return
            }
            guard !isGuest || index == 0 else {
                zixyTabBar.select(index: 0, sendsAction: false)
                return
            }
            self.selectedIndex = index
            updateCustomTabBarVisibility(animated: false)
        }
        zixyTabBar.onUnavailableSelection = { [weak self] _ in
            self?.showGuestLoginPrompt()
        }
    }

    private func showGuestLoginPrompt() {
        guard isGuest, presentedViewController == nil else {
            return
        }
        let controller = ZixyAlertController(kind: .loginRequired)
        controller.onPrimaryAction = { [weak self] in
            guard
                let sceneDelegate = self?.view.window?.windowScene?.delegate
                    as? SceneDelegate
            else {
                return
            }
            ZixySessionStore.clear()
            sceneDelegate.showAuthenticationInterface()
        }
        present(controller, animated: true)
    }

    private func updateCustomTabBarVisibility(animated: Bool) {
        let navigationController = selectedViewController
            as? UINavigationController
        let shouldHide =
            (navigationController?.viewControllers.count ?? 1) > 1
        setCustomTabBarHidden(shouldHide, animated: animated)
    }

    private func setCustomTabBarHidden(
        _ hidden: Bool,
        animated: Bool
    ) {
        guard hidden != isCustomTabBarHidden else {
            return
        }
        isCustomTabBarHidden = hidden

        let changes = {
            self.zixyTabBar.alpha = hidden ? 0 : 1
            self.zixyTabBar.transform = hidden
                ? CGAffineTransform(
                    translationX: 0,
                    y: self.zixyTabBar.bounds.height
                )
                : .identity
        }

        if animated {
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                options: [.beginFromCurrentState, .curveEaseInOut],
                animations: changes
            )
        } else {
            changes()
        }
        zixyTabBar.isUserInteractionEnabled = !hidden
    }
}

extension ZixyMainContainerController: UINavigationControllerDelegate {

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        guard navigationController === selectedViewController else {
            return
        }
        updateCustomTabBarVisibility(animated: animated)
    }
}

extension ZixyMainContainerController: UITabBarControllerDelegate {

    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        guard isGuest else {
            return true
        }
        return viewController === viewControllers?.first
    }
}
