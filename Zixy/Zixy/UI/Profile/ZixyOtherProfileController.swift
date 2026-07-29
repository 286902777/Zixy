import UIKit

final class ZixyOtherProfileController: UIViewController {

    struct Profile {
        let name: String
        let image: UIImage?
        let isCurrentUser: Bool

        init(name: String, image: UIImage?, isCurrentUser: Bool = false) {
            self.name = name
            self.image = image
            self.isCurrentUser = isCurrentUser
        }
    }

    private struct Post {
        let image: UIImage?
        let heightRatio: CGFloat
        let text: String
        let likes: String
        let isVideo: Bool
    }

    private enum Layout {
        static let horizontalInset: CGFloat = 15
        static let itemSpacing: CGFloat = 10
        static let headerHeight: CGFloat = 470
        static let actionBarHeight: CGFloat = 82
    }

    private let profile: Profile
    private var isFollowing = false
    private let posts = [
        Post(
            image: ZixyImageLibrary.profileAvatar,
            heightRatio: 1.22,
            text: "A new handmade piece from my workshop.",
            likes: "1.1K",
            isVideo: false
        ),
        Post(
            image: ZixyImageLibrary.feedWoodMountain,
            heightRatio: 0.82,
            text: "The colors reflect different personalities.",
            likes: "1.2K",
            isVideo: true
        ),
        Post(
            image: ZixyImageLibrary.userAvatar,
            heightRatio: 1.05,
            text: "Making something beautiful today.",
            likes: "986",
            isVideo: false
        ),
        Post(
            image: ZixyImageLibrary.homeRoomPortrait,
            heightRatio: 1.28,
            text: "A quiet afternoon in the craft room.",
            likes: "832",
            isVideo: false
        )
    ]

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Layout.itemSpacing
        layout.minimumLineSpacing = Layout.itemSpacing
        layout.sectionInset = UIEdgeInsets(
            top: Layout.itemSpacing,
            left: Layout.horizontalInset,
            bottom: Layout.actionBarHeight + 20,
            right: Layout.horizontalInset
        )
        layout.headerReferenceSize = CGSize(
            width: UIScreen.main.bounds.width,
            height: Layout.headerHeight
        )

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .white
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            ZixyProfilePostCell.self,
            forCellWithReuseIdentifier: ZixyProfilePostCell.reuseIdentifier
        )
        collectionView.register(
            ZixyOtherProfileHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ZixyOtherProfileHeaderView.reuseIdentifier
        )
        return collectionView
    }()

    private let backButton = ZixyOtherProfileController.makeRoundButton(
        image: UIImage(named: "zixy_ai_chat_back_button"),
        accessibilityLabel: "Back"
    )
    private let followButton = UIButton()
    
    private let moreButton = ZixyOtherProfileController.makeRoundButton(
        image: ZixyImageLibrary.otherProfileMoreIcon,
        accessibilityLabel: "More"
    )
    private let actionBar = UIView()
    private let messageButton = ZixyProfileActionButton(
        title: "Messages",
        colors: [
            UIColor(red: 55 / 255, green: 199 / 255, blue: 1, alpha: 1),
            UIColor(red: 24 / 255, green: 105 / 255, blue: 1, alpha: 1)
        ]
    )
    private let videoButton = ZixyProfileActionButton(
        title: "Video Call",
        colors: [
            UIColor(red: 1, green: 100 / 255, blue: 190 / 255, alpha: 1),
            UIColor(red: 1, green: 43 / 255, blue: 144 / 255, alpha: 1)
        ]
    )

    init(profile: Profile) {
        self.profile = profile
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    convenience init(
        name: String,
        image: UIImage?,
        isCurrentUser: Bool = false
    ) {
        self.init(
            profile: Profile(
                name: name,
                image: image,
                isCurrentUser: isCurrentUser
            )
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        configureLayout()
        configureInteractions()
        updateUserActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    private func configureLayout() {
        actionBar.translatesAutoresizingMaskIntoConstraints = false
        actionBar.backgroundColor = .white

        let actionStack = UIStackView(arrangedSubviews: [messageButton, videoButton])
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.axis = .horizontal
        actionStack.spacing = 12
        actionStack.distribution = .fillEqually

        [backButton, followButton, moreButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        view.addSubview(collectionView)
        view.addSubview(actionBar)
        actionBar.addSubview(actionStack)
        view.addSubview(backButton)
        view.addSubview(followButton)
        view.addSubview(moreButton)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            actionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            actionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            actionBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            actionBar.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -Layout.actionBarHeight
            ),

            actionStack.topAnchor.constraint(equalTo: actionBar.topAnchor, constant: 10),
            actionStack.leadingAnchor.constraint(
                equalTo: actionBar.leadingAnchor,
                constant: 15
            ),
            actionStack.trailingAnchor.constraint(
                equalTo: actionBar.trailingAnchor,
                constant: -15
            ),
            actionStack.heightAnchor.constraint(equalToConstant: 46),

            backButton.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 16
            ),
            backButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalTo: backButton.widthAnchor),

            moreButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -16
            ),
            moreButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: 40),
            moreButton.heightAnchor.constraint(equalTo: moreButton.widthAnchor),

            followButton.trailingAnchor.constraint(
                equalTo: moreButton.leadingAnchor,
                constant: -10
            ),
            followButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            followButton.widthAnchor.constraint(equalToConstant: 40),
            followButton.heightAnchor.constraint(equalTo: followButton.widthAnchor)
        ])
    }

    private func configureInteractions() {
        backButton.addTarget(
            self,
            action: #selector(backTapped),
            for: .touchUpInside
        )
        followButton.addTarget(
            self,
            action: #selector(followTapped),
            for: .touchUpInside
        )
        moreButton.addTarget(
            self,
            action: #selector(moreTapped),
            for: .touchUpInside
        )
        messageButton.addTarget(
            self,
            action: #selector(messageTapped),
            for: .touchUpInside
        )
        videoButton.addTarget(
            self,
            action: #selector(videoTapped),
            for: .touchUpInside
        )
    }

    private func updateUserActions() {
        let canActOnUser = !profile.isCurrentUser
            && ZixySessionStore.allowsSocialInteraction
        followButton.isHidden = !canActOnUser
        moreButton.isHidden = !canActOnUser
        messageButton.isEnabled = canActOnUser
        videoButton.isEnabled = canActOnUser
    }

    private static func makeRoundButton(
        image: UIImage?,
        accessibilityLabel: String
    ) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.cornerRadius = 12
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowRadius = 5
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.setImage(image?.withRenderingMode(.alwaysOriginal), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.accessibilityLabel = accessibilityLabel
        return button
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func followTapped() {
        guard
            ZixySessionStore.allowsSocialInteraction,
            !profile.isCurrentUser
        else {
            return
        }
        isFollowing.toggle()
        followButton.accessibilityLabel = isFollowing ? "Unfollow" : "Follow"
        followButton.alpha = isFollowing ? 0.65 : 1
        showToast(isFollowing ? "Following \(profile.name)." : "Unfollowed \(profile.name).")
    }

    @objc private func moreTapped() {
        guard
            ZixySessionStore.allowsSocialInteraction,
            !profile.isCurrentUser
        else {
            return
        }

        let controller = ZixyMoreActionsController(targetName: profile.name)
        controller.onReport = { [weak self] in
            guard let self, !self.profile.isCurrentUser else {
                return
            }
            let reportController = ZixyReportController(
                reportedUserName: self.profile.name,
                isCurrentUser: self.profile.isCurrentUser
            )
            reportController.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(
                reportController,
                animated: true
            )
        }
        controller.onBlock = { [weak self] in
            guard let self, !self.profile.isCurrentUser else {
                return
            }
            self.showToast("\(self.profile.name) has been blocked.")
        }
        present(controller, animated: false)
    }

    @objc private func messageTapped() {
        guard !profile.isCurrentUser else {
            return
        }
        let controller = ZixyConversationController(
            participantName: profile.name,
            participantImage: profile.image,
            isCurrentUser: false
        )
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func videoTapped() {
        guard !profile.isCurrentUser else {
            return
        }
        let controller = ZixyVideoCallController(participantName: profile.name)
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }
}

extension ZixyOtherProfileController:
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        posts.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ZixyProfilePostCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyProfilePostCell else {
            return UICollectionViewCell()
        }
        let post = posts[indexPath.item]
        cell.configure(
            image: post.image,
            text: post.text,
            likes: post.likes,
            showsPlayIcon: post.isVideo
        )
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard
            kind == UICollectionView.elementKindSectionHeader,
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: ZixyOtherProfileHeaderView.reuseIdentifier,
                for: indexPath
            ) as? ZixyOtherProfileHeaderView
        else {
            return UICollectionReusableView()
        }
        header.configure(name: profile.name, image: profile.image)
        return header
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let availableWidth = collectionView.bounds.width
            - (Layout.horizontalInset * 2)
            - Layout.itemSpacing
        let width = floor(availableWidth / 2)
        return CGSize(
            width: width,
            height: (width * posts[indexPath.item].heightRatio) + 58
        )
    }
}

private final class ZixyOtherProfileHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "ZixyOtherProfileHeaderView"

    private let heroImageView = UIImageView()
    private let informationView = UIView()
    private let nameLabel = UILabel()
    private let statisticsStack = UIStackView()
    private let biographyLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(name: String, image: UIImage?) {
        nameLabel.text = name
        heroImageView.image = image ?? ZixyImageLibrary.homeRoomPortrait
        accessibilityLabel = "\(name) profile"
    }

    private func configureLayout() {
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        heroImageView.contentMode = .scaleAspectFill
        heroImageView.clipsToBounds = true

        informationView.translatesAutoresizingMaskIntoConstraints = false
        informationView.backgroundColor = .white
        informationView.layer.cornerRadius = 22
        informationView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner
        ]

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = ZixyFontBook.bold(size: 22, relativeTo: .title2)
        nameLabel.textColor = UIColor.black.withAlphaComponent(0.82)

        statisticsStack.translatesAutoresizingMaskIntoConstraints = false
        statisticsStack.axis = .horizontal
        statisticsStack.alignment = .center
        statisticsStack.distribution = .fillEqually
        [
            ZixyProfileStatisticView(value: "1.1K", title: "Following"),
            ZixyProfileStatisticView(value: "1.2K", title: "Followers"),
            ZixyProfileStatisticView(value: "1.2K", title: "Likes")
        ].forEach(statisticsStack.addArrangedSubview)

        biographyLabel.translatesAutoresizingMaskIntoConstraints = false
        biographyLabel.font = ZixyFontBook.bold(size: 13, relativeTo: .footnote)
        biographyLabel.textColor = UIColor.black.withAlphaComponent(0.55)
        biographyLabel.numberOfLines = 2
        biographyLabel.text = "The colors of the clothing reflect different personalities."

        addSubview(heroImageView)
        addSubview(informationView)
        informationView.addSubview(nameLabel)
        informationView.addSubview(statisticsStack)
        informationView.addSubview(biographyLabel)

        NSLayoutConstraint.activate([
            heroImageView.topAnchor.constraint(equalTo: topAnchor),
            heroImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            heroImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            heroImageView.heightAnchor.constraint(equalToConstant: 350),

            informationView.topAnchor.constraint(equalTo: topAnchor, constant: 334),
            informationView.leadingAnchor.constraint(equalTo: leadingAnchor),
            informationView.trailingAnchor.constraint(equalTo: trailingAnchor),
            informationView.bottomAnchor.constraint(equalTo: bottomAnchor),

            nameLabel.topAnchor.constraint(
                equalTo: informationView.topAnchor,
                constant: 15
            ),
            nameLabel.leadingAnchor.constraint(
                equalTo: informationView.leadingAnchor,
                constant: 15
            ),
            nameLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: informationView.trailingAnchor,
                constant: -15
            ),

            statisticsStack.topAnchor.constraint(
                equalTo: nameLabel.bottomAnchor,
                constant: 12
            ),
            statisticsStack.leadingAnchor.constraint(
                equalTo: informationView.leadingAnchor,
                constant: 12
            ),
            statisticsStack.trailingAnchor.constraint(
                equalTo: informationView.trailingAnchor,
                constant: -12
            ),
            statisticsStack.heightAnchor.constraint(equalToConstant: 38),

            biographyLabel.topAnchor.constraint(
                equalTo: statisticsStack.bottomAnchor,
                constant: 11
            ),
            biographyLabel.leadingAnchor.constraint(
                equalTo: informationView.leadingAnchor,
                constant: 15
            ),
            biographyLabel.trailingAnchor.constraint(
                equalTo: informationView.trailingAnchor,
                constant: -15
            )
        ])
    }
}

private final class ZixyProfileStatisticView: UIView {

    init(value: String, title: String) {
        super.init(frame: .zero)

        let valueLabel = UILabel()
        valueLabel.font = ZixyFontBook.bold(size: 16, relativeTo: .headline)
        valueLabel.textColor = UIColor.black.withAlphaComponent(0.8)
        valueLabel.text = value
        valueLabel.textAlignment = .center

        let titleLabel = UILabel()
        titleLabel.font = ZixyFontBook.bold(size: 11, relativeTo: .caption1)
        titleLabel.textColor = UIColor.black.withAlphaComponent(0.42)
        titleLabel.text = title
        titleLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = -1
        stack.alignment = .fill
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class ZixyProfileActionButton: UIButton {

    private let gradientLayer = CAGradientLayer()

    init(title: String, colors: [UIColor]) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setTitle(title, for: .normal)
        setTitleColor(.white, for: .normal)
        titleLabel?.font = ZixyFontBook.bold(size: 15, relativeTo: .headline)
        layer.cornerRadius = 23
        layer.masksToBounds = true
        gradientLayer.colors = colors.map(\.cgColor)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradientLayer, at: 0)
        accessibilityLabel = title
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

extension UIViewController {

    func pushZixyOtherProfile(
        name: String,
        image: UIImage?,
        isCurrentUser: Bool
    ) {
        guard !isCurrentUser else {
            return
        }
        let controller = ZixyOtherProfileController(
            name: name,
            image: image,
            isCurrentUser: false
        )
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }
}
