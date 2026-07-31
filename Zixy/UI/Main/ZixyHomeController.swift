import UIKit

final class ZixyHomeController: ZixyScreenController {

    private static var hasShownInitialLoading = false

    private enum Layout {
        static let bannerAspectRatio: CGFloat = 1.5
        static let categoryHeight: CGFloat = 70
    }

    private let categories = ZixyRoomCatalog.categories
    private lazy var categoryButtons = categories.enumerated().map(makeCategoryButton)
    private lazy var pages = categories.enumerated().map(makeRoomPage)

    private let bannerButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(ZixyImageLibrary.homeAIBanner, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.accessibilityLabel = "Open Zixy AI craft assistant"
        return button
    }()

    private let categoryStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 16
        return stack
    }()

    private let categoryScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isDirectionalLockEnabled = true
        return scrollView
    }()

    private let pageController = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal
    )
    private let loadingOverlay = ZixyLoadingOverlay()

    private var selectedIndex = 0
    private var isShowingInitialLoading = false

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.isHidden = true
        bannerButton.addTarget(
            self,
            action: #selector(openAIChat),
            for: .touchUpInside
        )
        configureLayout()
        configurePageController()
        updateCategorySelection()
        configureLoadingOverlay()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(blacklistDidChange),
            name: .zixyBlacklistDidChange,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !Self.hasShownInitialLoading {
            Self.hasShownInitialLoading = true
            isShowingInitialLoading = true
            loadingOverlay.show(message: "Loading home")
        }
        reloadRooms()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard isShowingInitialLoading else {
            return
        }
        isShowingInitialLoading = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.loadingOverlay.hide()
        }
    }

    private func configureLayout() {
        categoryButtons.forEach(categoryStack.addArrangedSubview)

        view.addSubview(bannerButton)
        view.addSubview(categoryScrollView)
        categoryScrollView.addSubview(categoryStack)

        addChild(pageController)
        pageController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageController.view)
        pageController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            bannerButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            bannerButton.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 16
            ),
            bannerButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerButton.heightAnchor.constraint(
                equalTo: bannerButton.widthAnchor,
                multiplier: 1 / Layout.bannerAspectRatio
            ),

            categoryScrollView.topAnchor.constraint(
                equalTo: bannerButton.bottomAnchor,
                constant: -8
            ),
            categoryScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryScrollView.heightAnchor.constraint(
                equalToConstant: Layout.categoryHeight
            ),

            categoryStack.topAnchor.constraint(
                equalTo: categoryScrollView.contentLayoutGuide.topAnchor
            ),
            categoryStack.leadingAnchor.constraint(
                equalTo: categoryScrollView.contentLayoutGuide.leadingAnchor,
                constant: 16
            ),
            categoryStack.trailingAnchor.constraint(
                equalTo: categoryScrollView.contentLayoutGuide.trailingAnchor,
                constant: -16
            ),
            categoryStack.bottomAnchor.constraint(
                equalTo: categoryScrollView.contentLayoutGuide.bottomAnchor
            ),
            categoryStack.heightAnchor.constraint(
                equalTo: categoryScrollView.frameLayoutGuide.heightAnchor
            ),
            categoryStack.widthAnchor.constraint(
                greaterThanOrEqualTo: categoryScrollView.frameLayoutGuide.widthAnchor,
                constant: -32
            ),

            pageController.view.topAnchor.constraint(
                equalTo: categoryScrollView.bottomAnchor,
                constant: 4
            ),
            pageController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configurePageController() {
        pageController.dataSource = self
        pageController.delegate = self
        pageController.setViewControllers(
            [pages[selectedIndex]],
            direction: .forward,
            animated: false
        )
    }

    private func configureLoadingOverlay() {
        view.addSubview(loadingOverlay)
        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func reloadRooms() {
        for (index, category) in categories.enumerated() {
            pages[index].reload(
                rooms: ZixySessionStore.homeRooms(category: category)
            )
        }
    }

    @objc private func blacklistDidChange() {
        reloadRooms()
    }

    private func makeCategoryButton(
        index: Int,
        title: String
    ) -> ZixyHomeCategoryButton {
        let button = ZixyHomeCategoryButton()
        button.tag = index
        button.accessibilityLabel = "\(title) rooms"
        button.titleLabel?.font = ZixyFontBook.bold(size: 25)
        button.setTitle(title, for: .normal)
        button.setTitleColor(
            UIColor.black.withAlphaComponent(0.3),
            for: .normal
        )
        button.setTitleColor(
            UIColor.black.withAlphaComponent(0.82),
            for: .selected
        )
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.68
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addTarget(
            self,
            action: #selector(selectCategory(_:)),
            for: .touchUpInside
        )
        return button
    }

    private func makeRoomPage(
        index _: Int,
        title: String
    ) -> ZixyRoomGridPageController {
        ZixyRoomGridPageController(
            categoryTitle: title,
            rooms: ZixySessionStore.homeRooms(category: title)
        )
    }

    private func updateCategorySelection() {
        for (index, button) in categoryButtons.enumerated() {
            button.isSelected = index == selectedIndex
        }
    }

    @objc private func openAIChat() {
        push(ZixyAIChatController())
    }

    @objc private func selectCategory(_ sender: UIButton) {
        let nextIndex = sender.tag
        guard pages.indices.contains(nextIndex),
              nextIndex != selectedIndex else {
            return
        }

        let direction: UIPageViewController.NavigationDirection =
            nextIndex > selectedIndex ? .forward : .reverse
        selectedIndex = nextIndex
        updateCategorySelection()
        pageController.setViewControllers(
            [pages[nextIndex]],
            direction: direction,
            animated: true
        )
    }
}

private final class ZixyHomeCategoryButton: UIButton {

    private var indicatorWidthConstraint: NSLayoutConstraint?

    private let indicatorImageView: UIImageView = {
        let imageView = UIImageView(
            image: ZixyImageLibrary.homeCategoryIndicator
        )
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleToFill
        imageView.isHidden = true
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    override var isSelected: Bool {
        didSet {
            indicatorImageView.isHidden = !isSelected
            accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    init() {
        super.init(frame: .zero)
        insertSubview(indicatorImageView, at: 0)
        let widthConstraint = indicatorImageView.widthAnchor.constraint(
            equalToConstant: 0
        )
        indicatorWidthConstraint = widthConstraint
        NSLayoutConstraint.activate([
            indicatorImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicatorImageView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -16
            ),
            widthConstraint,
            indicatorImageView.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let textWidth = titleLabel?.intrinsicContentSize.width ?? 0
        indicatorWidthConstraint?.constant = min(textWidth, bounds.width)
    }
}

extension ZixyHomeController:
    UIPageViewControllerDataSource,
    UIPageViewControllerDelegate {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let index = pages.firstIndex(where: { $0 === viewController }),
              index > 0 else {
            return nil
        }
        return pages[index - 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let index = pages.firstIndex(where: { $0 === viewController }),
              index + 1 < pages.count else {
            return nil
        }
        return pages[index + 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let visibleController = pageViewController.viewControllers?.first,
              let index = pages.firstIndex(where: {
                  $0 === visibleController
              }) else {
            return
        }
        selectedIndex = index
        updateCategorySelection()
    }
}
