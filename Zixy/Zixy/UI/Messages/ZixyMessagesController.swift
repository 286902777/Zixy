import UIKit

final class ZixyMessagesController: ZixyScreenController,
    UIPageViewControllerDataSource,
    UIPageViewControllerDelegate {

    private enum Page: Int, CaseIterable {
        case chats
        case rooms
    }

    private let titleImageView: UIImageView = {
        let imageView = UIImageView(image: ZixyImageLibrary.messagesTitle)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.accessibilityLabel = "Messages"
        return imageView
    }()

    private let chatButton = ZixyMessagesSegmentButton(title: "Chats")
    private let roomsButton = ZixyMessagesSegmentButton(title: "Rooms")
    private let aiRow = ZixyPinnedMessageRow(
        image: ZixyImageLibrary.messagesAI,
        title: "Zixy Ai",
        message: "Hey! What's up😊?",
        showsTime: false
    )

    private lazy var pageControllers: [UIViewController] = [
        ZixyChatListController(),
        ZixyMessageRoomsController()
    ]
    private lazy var pageController = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal
    )

    private var selectedPage: Page = .chats

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation(title: "", showsBackButton: false)
        configureTitle()
        configurePinnedRows()
        configurePageController()
        updateSelection(for: .chats, animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshAIMessage()
    }

    private func configureTitle() {
        navigationBar.addSubview(titleImageView)
        NSLayoutConstraint.activate([
            titleImageView.leadingAnchor.constraint(
                equalTo: navigationBar.leadingAnchor,
                constant: 20
            ),
            titleImageView.centerYAnchor.constraint(
                equalTo: navigationBar.centerYAnchor,
                constant: 2
            ),
            titleImageView.widthAnchor.constraint(equalToConstant: 306),
            titleImageView.heightAnchor.constraint(equalToConstant: 69)
        ])
    }

    private func configurePinnedRows() {
        let notificationsRow = ZixyPinnedMessageRow(
            image: ZixyImageLibrary.messagesNotifications,
            title: "Notifications",
            message: "",
            showsTime: false
        )
        notificationsRow.addTarget(
            self,
            action: #selector(showNotifications),
            for: .touchUpInside
        )
        aiRow.addTarget(
            self,
            action: #selector(showAIChat),
            for: .touchUpInside
        )
        let segmentStack = UIStackView(arrangedSubviews: [chatButton, roomsButton])
        segmentStack.translatesAutoresizingMaskIntoConstraints = false
        segmentStack.axis = .horizontal
        segmentStack.alignment = .fill
        segmentStack.distribution = .fillEqually

        [notificationsRow, aiRow, segmentStack].forEach {
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            notificationsRow.topAnchor.constraint(equalTo: contentView.topAnchor),
            notificationsRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            notificationsRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            notificationsRow.heightAnchor.constraint(equalToConstant: 72),

            aiRow.topAnchor.constraint(equalTo: notificationsRow.bottomAnchor),
            aiRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            aiRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            aiRow.heightAnchor.constraint(equalToConstant: 72),

            segmentStack.topAnchor.constraint(equalTo: aiRow.bottomAnchor),
            segmentStack.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 12
            ),
            segmentStack.widthAnchor.constraint(equalToConstant: 174),
            segmentStack.heightAnchor.constraint(equalToConstant: 48)
        ])

        chatButton.addTarget(self, action: #selector(showChats), for: .touchUpInside)
        roomsButton.addTarget(self, action: #selector(showRooms), for: .touchUpInside)
    }

    private func refreshAIMessage() {
        aiRow.updateMessage(
            ZixyAIChatHistoryStore.latestMessage ?? "Hey! What's up😊?"
        )
    }

    private func configurePageController() {
        pageController.dataSource = self
        pageController.delegate = self
        addChild(pageController)
        pageController.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pageController.view)
        NSLayoutConstraint.activate([
            pageController.view.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 192
            ),
            pageController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pageController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pageController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        pageController.didMove(toParent: self)
        pageController.setViewControllers(
            [pageControllers[Page.chats.rawValue]],
            direction: .forward,
            animated: false
        )
    }

    private func setPage(_ page: Page) {
        guard page != selectedPage else {
            return
        }
        let direction: UIPageViewController.NavigationDirection =
            page.rawValue > selectedPage.rawValue ? .forward : .reverse
        pageController.setViewControllers(
            [pageControllers[page.rawValue]],
            direction: direction,
            animated: true
        )
        updateSelection(for: page, animated: true)
    }

    private func updateSelection(for page: Page, animated: Bool) {
        selectedPage = page
        chatButton.isSelected = page == .chats
        roomsButton.isSelected = page == .rooms
    }

    @objc private func showChats() {
        setPage(.chats)
    }

    @objc private func showRooms() {
        setPage(.rooms)
    }

    @objc private func showNotifications() {
        push(ZixyNotificationsController())
    }

    @objc private func showAIChat() {
        push(ZixyAIChatController())
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard
            let index = pageControllers.firstIndex(where: { $0 === viewController }),
            index > 0
        else {
            return nil
        }
        return pageControllers[index - 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard
            let index = pageControllers.firstIndex(where: { $0 === viewController }),
            index < pageControllers.count - 1
        else {
            return nil
        }
        return pageControllers[index + 1]
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard
            completed,
            let visibleController = pageViewController.viewControllers?.first,
            let index = pageControllers.firstIndex(where: {
                $0 === visibleController
            }),
            let page = Page(rawValue: index)
        else {
            return
        }
        updateSelection(for: page, animated: true)
    }
}

private final class ZixyMessagesSegmentButton: UIButton {

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

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setTitle(title, for: .normal)
        setTitleColor(.lightGray, for: .normal)
        setTitleColor(
            UIColor(red: 47 / 255, green: 48 / 255, blue: 51 / 255, alpha: 1),
            for: .selected
        )
        titleLabel?.font = ZixyFontBook.bold(size: 25, relativeTo: .title2)
        contentHorizontalAlignment = .center
        accessibilityTraits = .button

        insertSubview(indicatorImageView, at: 0)
        let widthConstraint = indicatorImageView.widthAnchor.constraint(
            equalToConstant: 0
        )
        indicatorWidthConstraint = widthConstraint
        NSLayoutConstraint.activate([
            indicatorImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicatorImageView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -4
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

private final class ZixyPinnedMessageRow: UIControl {

    private let messageLabel = UILabel()
    private let showsTime: Bool
    private let title: String

    init(
        image: UIImage?,
        title: String,
        message: String,
        showsTime: Bool = true
    ) {
        self.title = title
        self.showsTime = showsTime
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: image)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = ZixyFontBook.bold(size: 18, relativeTo: .headline)
        titleLabel.textColor = UIColor(
            red: 47 / 255,
            green: 48 / 255,
            blue: 51 / 255,
            alpha: 1
        )

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = message
        messageLabel.font = ZixyFontBook.bold(size: 14, relativeTo: .subheadline)
        messageLabel.textColor = .systemGray

        let timeLabel = UILabel()
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.text = showsTime ? "Just now" : nil
        timeLabel.isHidden = !showsTime
        timeLabel.font = ZixyFontBook.bold(size: 12, relativeTo: .caption1)
        timeLabel.textColor = .systemGray2

        [iconView, titleLabel, messageLabel, timeLabel].forEach(addSubview)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 54),
            iconView.heightAnchor.constraint(equalToConstant: 54),

            titleLabel.leadingAnchor.constraint(
                equalTo: iconView.trailingAnchor,
                constant: 11
            ),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: timeLabel.leadingAnchor,
                constant: -8
            ),

            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            messageLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -20
            ),

            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            timeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        updateMessage(message)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func updateMessage(_ message: String) {
        messageLabel.text = message
        accessibilityLabel = showsTime
            ? "\(title), \(message), Just now"
            : "\(title), \(message)"
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.55 : 1
        }
    }
}
