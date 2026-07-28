import UIKit

final class ZixyHomeController: ZixyScreenController {

    private enum Layout {
        static let bannerAspectRatio: CGFloat = 1.5
        static let categoryHeight: CGFloat = 70
    }

    private let categories = ["Leathercraft", "Resin Garage", "Talks"]
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
        stack.distribution = .fillEqually
        return stack
    }()

    private let pageController = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal
    )

    private var selectedIndex = 2

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
    }

    private func configureLayout() {
        categoryButtons.forEach(categoryStack.addArrangedSubview)

        view.addSubview(bannerButton)
        view.addSubview(categoryStack)

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

            categoryStack.topAnchor.constraint(
                equalTo: bannerButton.bottomAnchor,
                constant: -8
            ),
            categoryStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryStack.heightAnchor.constraint(
                equalToConstant: Layout.categoryHeight
            ),

            pageController.view.topAnchor.constraint(
                equalTo: categoryStack.bottomAnchor,
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
        button.addTarget(
            self,
            action: #selector(selectCategory(_:)),
            for: .touchUpInside
        )
        return button
    }

    private func makeRoomPage(
        index: Int,
        title: String
    ) -> ZixyRoomGridPageController {
        ZixyRoomGridPageController(
            categoryTitle: title,
            roomTitles: roomTitles(for: index)
        )
    }

    private func roomTitles(for index: Int) -> [String] {
        switch index {
        case 0:
            return [
                "Leather tooling chat",
                "Handmade leather room",
                "Share your latest craft",
                "Leather makers live"
            ]
        case 1:
            return [
                "Resin workshop",
                "Color mixing ideas",
                "Share your latest craft",
                "Resin makers live"
            ]
        default:
            return Array(repeating: "Here is the room...", count: 8)
        }
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
