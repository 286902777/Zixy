import UIKit

class ZixyScreenController: UIViewController {

    private enum Layout {
        static let navigationHeight: CGFloat = 72
    }

    let navigationBar = ZixyScreenHeader()
    let contentView = UIView()

    private let backgroundImageView = ZixyImageLibrary.makePageBackgroundView()
    private var navigationTitle = ""
    private var backButtonOverride: Bool?
    private var configuredRightView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureBackground()
        configureLayout()
        configureInteractions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        refreshNavigationBar()
    }

    func configureNavigation(
        title: String,
        showsBackButton: Bool? = nil,
        rightView: UIView? = nil
    ) {
        navigationTitle = title
        backButtonOverride = showsBackButton
        configuredRightView = rightView

        guard isViewLoaded else {
            return
        }
        refreshNavigationBar()
    }

    func push(_ controller: UIViewController, animated: Bool = true) {
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: animated)
    }

    @objc private func navigateBack() {
        navigationController?.popViewController(animated: true)
    }

    private func configureBackground() {
        view.backgroundColor = ZixyColorPalette.pageBackground
        view.addSubview(backgroundImageView)
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureLayout() {
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear

        view.addSubview(navigationBar)
        view.addSubview(contentView)

        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationBar.heightAnchor.constraint(
                equalToConstant: Layout.navigationHeight
            ),

            contentView.topAnchor.constraint(
                equalTo: navigationBar.bottomAnchor
            ),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureInteractions() {
        navigationBar.backButton.addTarget(
            self,
            action: #selector(navigateBack),
            for: .touchUpInside
        )
    }

    private func refreshNavigationBar() {
        let isChild = (navigationController?.viewControllers.count ?? 1) > 1
        navigationBar.configure(
            title: navigationTitle,
            showsBackButton: backButtonOverride ?? isChild,
            rightView: configuredRightView
        )
    }
}
