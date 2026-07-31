import AVFoundation
import UIKit

final class ZixyOtherProfileController: UIViewController {

    struct Profile {
        let email: String
        let name: String
        let image: UIImage?
        let biography: String
        let isCurrentUser: Bool

        init(user: ZixyUserRecord) {
            email = user.email
            name = user.username
            image = ZixyUserAvatarStore.image(for: user)
            biography = user.bio
            isCurrentUser = user.email.lowercased()
                == ZixySessionStore.currentUserIdentifier.lowercased()
        }
    }

    private struct Post {
        let id: String
        let mediaName: String
        let text: String
        let likeCount: Int
        let showsPlayIcon: Bool
        var image: UIImage?
    }

    private enum Layout {
        static let horizontalInset: CGFloat = 15
        static let itemSpacing: CGFloat = 10
        static let headerHeight: CGFloat = 470
        static let actionBarHeight: CGFloat = 82
    }

    private var profile: Profile
    private var isFollowing = false
    private var posts: [Post] = []
    private var followingCount = 0
    private var followerCount = 0
    private var likesCount = 0
    private var videoCoverCache: [String: UIImage] = [:]
    private var videoCoverGenerators: [String: AVAssetImageGenerator] = [:]

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
    private let followButton = ZixyOtherProfileController.makeRoundButton(
        image: ZixyImageLibrary.otherProfileFollowIcon,
        accessibilityLabel: "Follow"
    )

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

    convenience init(user: ZixyUserRecord) {
        self.init(profile: Profile(user: user))
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        configureLayout()
        configureInteractions()
        reloadProfile()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        reloadProfile()
    }

    private func reloadProfile() {
        guard let user = ZixyDataStore.shared.user(email: profile.email) else {
            return
        }
        profile = Profile(user: user)
        let userPosts = ZixyDataStore.shared.posts(for: user.email)
        posts = userPosts.map { post in
            let isVideo = Self.isVideoMedia(post.primaryMediaName)
            return Post(
                id: post.id,
                mediaName: post.primaryMediaName,
                text: post.title,
                likeCount: post.likeCount,
                showsPlayIcon: isVideo,
                image: isVideo
                    ? videoCoverCache[post.primaryMediaName]
                    : Self.postImage(named: post.primaryMediaName)
            )
        }
        followingCount = ZixyDataStore.shared.following(for: user.email).count
        followerCount = ZixyDataStore.shared.followers(for: user.email).count
        likesCount = userPosts.reduce(0) { $0 + $1.likeCount }
        isFollowing = ZixyDataStore.shared.isFollowing(
            user.email,
            from: ZixySessionStore.currentUserIdentifier
        )
        updateUserActions()
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()

        let videoNames = Set(
            posts
                .filter { $0.showsPlayIcon && $0.image == nil }
                .map(\.mediaName)
        )
        videoNames.forEach(loadFirstFrame)
    }

    private static func postImage(named mediaName: String) -> UIImage? {
        ZixyPostMediaStore.image(reference: mediaName)
    }

    private static func mediaURL(named mediaName: String) -> URL? {
        ZixyPostMediaStore.mediaURL(reference: mediaName)
    }

    private func loadFirstFrame(for mediaName: String) {
        guard
            videoCoverCache[mediaName] == nil,
            videoCoverGenerators[mediaName] == nil,
            let url = Self.mediaURL(named: mediaName)
        else {
            return
        }

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        videoCoverGenerators[mediaName] = generator
        generator.generateCGImagesAsynchronously(
            forTimes: [NSValue(time: .zero)]
        ) { [weak self] _, image, _, result, _ in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.videoCoverGenerators[mediaName] = nil
                guard result == .succeeded, let image else {
                    return
                }
                let cover = UIImage(cgImage: image)
                self.videoCoverCache[mediaName] = cover
                let indexes = self.posts.indices.filter {
                    self.posts[$0].mediaName == mediaName
                }
                indexes.forEach { self.posts[$0].image = cover }
                let indexPaths = indexes.map {
                    IndexPath(item: $0, section: 0)
                }
                guard !indexPaths.isEmpty else {
                    return
                }
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.reloadItems(at: indexPaths)
            }
        }
    }

    private static func isVideoMedia(_ mediaName: String) -> Bool {
        Set(["mp4", "mov", "m4v"]).contains(
            (mediaName as NSString).pathExtension.lowercased()
        )
    }

    private static func formattedCount(_ count: Int) -> String {
        count >= 1_000
            ? String(format: "%.1fK", Double(count) / 1_000)
            : "\(count)"
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
        followButton.isHidden = !canActOnUser || isFollowing
        moreButton.isHidden = !canActOnUser
        messageButton.isEnabled = canActOnUser
        videoButton.isEnabled = canActOnUser
        followButton.accessibilityLabel = "Follow"
        followButton.alpha = 1
    }

    private var targetUserEmail: String? {
        profile.email
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
            !profile.isCurrentUser,
            !isFollowing
        else {
            return
        }
        if let targetEmail = targetUserEmail {
            do {
                try ZixyDataStore.shared.setFollowing(
                    true,
                    followedEmail: targetEmail,
                    followerEmail: ZixySessionStore.currentUserIdentifier
                )
            } catch {
                showToast("Unable to update the follow status.")
                return
            }
        }
        isFollowing = true
        updateUserActions()
        reloadProfile()
        showToast("Following \(profile.name).")
    }

    @objc private func moreTapped() {
        guard
            ZixySessionStore.allowsSocialInteraction,
            !profile.isCurrentUser
        else {
            return
        }

        let controller = ZixyMoreActionsController(
            targetName: profile.name,
            isFollowing: isFollowing
        )
        controller.onFollowed = { [weak self] in
            guard let self else {
                return
            }
            guard
                ZixySessionStore.allowsSocialInteraction,
                !self.profile.isCurrentUser,
                let targetEmail = self.targetUserEmail
            else {
                self.showToast("Unable to follow \(self.profile.name).")
                return
            }
            do {
                try ZixyDataStore.shared.setFollowing(
                    true,
                    followedEmail: targetEmail,
                    followerEmail: ZixySessionStore.currentUserIdentifier
                )
                self.isFollowing = true
                self.updateUserActions()
                self.reloadProfile()
                self.showToast("Followed \(self.profile.name).")
            } catch {
                self.showToast("Unable to follow \(self.profile.name).")
            }
        }
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
            guard
                let self,
                ZixySessionStore.allowsSocialInteraction,
                !self.profile.isCurrentUser
            else {
                return
            }
            do {
                try ZixyDataStore.shared.setBlocked(
                    true,
                    blockedEmail: self.profile.email,
                    blockerEmail: ZixySessionStore.currentUserIdentifier
                )
                self.showToast("\(self.profile.name) has been blocked.")
            } catch {
                self.showToast("Unable to update the blacklist.")
            }
        }
        present(controller, animated: false)
    }

    @objc private func messageTapped() {
        guard
            ZixySessionStore.allowsSocialInteraction,
            !profile.isCurrentUser
        else {
            return
        }
        let currentUserEmail = ZixySessionStore.currentUserIdentifier
        let currentUserFollowsTarget = ZixyDataStore.shared.isFollowing(
            profile.email,
            from: currentUserEmail
        )
        let targetFollowsCurrentUser = ZixyDataStore.shared.isFollowing(
            currentUserEmail,
            from: profile.email
        )
        guard currentUserFollowsTarget, targetFollowsCurrentUser else {
            showToast("You can message each other after following each other.")
            return
        }
        let controller = ZixyConversationController(
            participantName: profile.name,
            participantImage: profile.image,
            isCurrentUser: false,
            participantEmail: profile.email
        )
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func videoTapped() {
        guard !profile.isCurrentUser else {
            return
        }
        let controller = ZixyVideoCallController(
            participantName: profile.name,
            participantEmail: profile.email,
            participantImage: profile.image
        )
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
            likes: Self.formattedCount(post.likeCount),
            showsPlayIcon: post.showsPlayIcon
        )
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard posts.indices.contains(indexPath.item) else {
            return
        }
        let post = posts[indexPath.item]
        let media: ZixyVideoDetailController.Media
        if post.showsPlayIcon,
           let url = Self.mediaURL(named: post.mediaName) {
            media = .video(url: url, poster: post.image)
        } else {
            media = .image(post.image)
        }
        let controller = ZixyVideoDetailController(
            postID: post.id,
            media: media
        )
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
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
        header.configure(
            name: profile.name,
            image: profile.image,
            biography: profile.biography,
            followingCount: followingCount,
            followerCount: followerCount,
            likesCount: likesCount
        )
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
        let ratio: CGFloat
        if let image = posts[indexPath.item].image,
           image.size.width > 0 {
            ratio = image.size.height / image.size.width
        } else {
            ratio = 1
        }
        return CGSize(
            width: width,
            height: (width * ratio) + 58
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
    private let followingView = ZixyProfileStatisticView(
        value: "0",
        title: "Following"
    )
    private let followerView = ZixyProfileStatisticView(
        value: "0",
        title: "Followers"
    )
    private let likesView = ZixyProfileStatisticView(value: "0", title: "Likes")

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        name: String,
        image: UIImage?,
        biography: String,
        followingCount: Int,
        followerCount: Int,
        likesCount: Int
    ) {
        nameLabel.text = name
        heroImageView.image = image ?? ZixyImageLibrary.homeRoomPortrait
        biographyLabel.text = biography
        followingView.update(value: Self.formattedCount(followingCount))
        followerView.update(value: Self.formattedCount(followerCount))
        likesView.update(value: Self.formattedCount(likesCount))
        accessibilityLabel = "\(name) profile"
    }

    private static func formattedCount(_ count: Int) -> String {
        count >= 1_000
            ? String(format: "%.1fK", Double(count) / 1_000)
            : "\(count)"
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
        [followingView, followerView, likesView]
            .forEach(statisticsStack.addArrangedSubview)

        biographyLabel.translatesAutoresizingMaskIntoConstraints = false
        biographyLabel.font = ZixyFontBook.bold(size: 13, relativeTo: .footnote)
        biographyLabel.textColor = UIColor.black.withAlphaComponent(0.55)
        biographyLabel.numberOfLines = 2

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

    private let valueLabel = UILabel()

    init(value: String, title: String) {
        super.init(frame: .zero)

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

    func update(value: String) {
        valueLabel.text = value
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

    func pushZixyOtherProfile(userEmail: String) {
        guard
            userEmail.lowercased()
                != ZixySessionStore.currentUserIdentifier.lowercased(),
            let user = ZixyDataStore.shared.user(email: userEmail)
        else {
            return
        }
        let controller = ZixyOtherProfileController(user: user)
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }
}
