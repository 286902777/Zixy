import UIKit

final class ZixyNotificationsController: ZixyScreenController,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    private struct NotificationItem {
        let email: String
        let name: String
        let message: String
        let postID: String
        let postTitle: String
        let mediaName: String
        let avatar: UIImage?
        let postImage: UIImage?
    }

    private var notifications: [NotificationItem] = []

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.sectionInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: 24,
            right: 0
        )

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            ZixyNotificationCell.self,
            forCellWithReuseIdentifier: ZixyNotificationCell.reuseIdentifier
        )
        return collectionView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation(title: "Notifications")
        configureCollectionView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadNotifications()
    }

    private func loadNotifications() {
        let currentUserEmail = ZixySessionStore.currentUserIdentifier
        let allPosts = ZixyDataStore.shared.posts()
        var items: [NotificationItem] = []

        for post in allPosts where post.author.email != currentUserEmail {
            items.append(
                makeNotification(
                    actor: post.author,
                    message: "shared a post",
                    post: post
                )
            )
        }

        for post in allPosts where post.author.email == currentUserEmail {
            let likers = ZixyDataStore.shared.usersWhoLiked(postID: post.id)
                .filter { $0.email != currentUserEmail }
            items.append(
                contentsOf: likers.map {
                    makeNotification(
                        actor: $0,
                        message: "liked your post",
                        post: post
                    )
                }
            )

            let comments = ZixyDataStore.shared.comments(for: post.id)
                .filter { $0.author.email != currentUserEmail }
            items.append(
                contentsOf: comments.map {
                    makeNotification(
                        actor: $0.author,
                        message: "commented: \($0.body)",
                        post: post
                    )
                }
            )
        }

        notifications = items
        collectionView.reloadData()
    }

    private func makeNotification(
        actor: ZixyUserRecord,
        message: String,
        post: ZixyPostRecord
    ) -> NotificationItem {
        NotificationItem(
            email: actor.email,
            name: actor.username,
            message: message,
            postID: post.id,
            postTitle: post.title,
            mediaName: post.primaryMediaName,
            avatar: ZixyUserAvatarStore.image(for: actor),
            postImage: ZixyPostMediaStore.image(
                reference: post.primaryMediaName
            )
        )
    }

    private func configureCollectionView() {
        contentView.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        notifications.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ZixyNotificationCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyNotificationCell else {
            return UICollectionViewCell()
        }

        let item = notifications[indexPath.item]
        cell.configure(
            name: item.name,
            message: item.message,
            postTitle: item.postTitle,
            avatar: item.avatar,
            postImage: item.postImage
        )
        cell.onAvatarTapped = { [weak self] in
            self?.pushZixyOtherProfile(userEmail: item.email)
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: 96)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard notifications.indices.contains(indexPath.item) else {
            return
        }
        let item = notifications[indexPath.item]
        let media: ZixyVideoDetailController.Media
        let videoExtensions = Set(["mp4", "mov", "m4v"])
        let isVideo = videoExtensions.contains(
            (item.mediaName as NSString).pathExtension.lowercased()
        )
        if isVideo,
           let url = ZixyPostMediaStore.mediaURL(
               reference: item.mediaName
           ) {
            media = .video(url: url, poster: item.postImage)
        } else {
            media = .image(item.postImage)
        }
        push(
            ZixyVideoDetailController(
                postID: item.postID,
                media: media
            )
        )
    }
}

private final class ZixyNotificationCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyNotificationCell"

    var onAvatarTapped: (() -> Void)?

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let postTitleLabel = UILabel()
    private let messageLabel = UILabel()
    private let postImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onAvatarTapped = nil
    }

    func configure(
        name: String,
        message: String,
        postTitle: String,
        avatar: UIImage?,
        postImage: UIImage?
    ) {
        avatarView.image = avatar
        nameLabel.text = name
        postTitleLabel.text = postTitle
        messageLabel.text = message
        postImageView.image = postImage
        accessibilityLabel = "\(name), \(postTitle), \(message)"
    }

    override var isHighlighted: Bool {
        didSet {
            contentView.alpha = isHighlighted ? 0.55 : 1
        }
    }

    private func configureLayout() {
        isAccessibilityElement = true
        accessibilityTraits = .button

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 25
        avatarView.isUserInteractionEnabled = true
        avatarView.accessibilityTraits = .button
        avatarView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        )

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = ZixyFontBook.bold(size: 18, relativeTo: .headline)
        nameLabel.textColor = UIColor.black.withAlphaComponent(0.76)
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.85

        postTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        postTitleLabel.font = ZixyFontBook.bold(
            size: 13,
            relativeTo: .subheadline
        )
        postTitleLabel.textColor = UIColor.black.withAlphaComponent(0.58)
        postTitleLabel.lineBreakMode = .byTruncatingTail

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = ZixyFontBook.bold(
            size: 11,
            relativeTo: .subheadline
        )
        messageLabel.textColor = UIColor.systemGray3
        messageLabel.lineBreakMode = .byTruncatingTail

        postImageView.translatesAutoresizingMaskIntoConstraints = false
        postImageView.contentMode = .scaleAspectFill
        postImageView.clipsToBounds = true
        postImageView.layer.cornerRadius = 3

        [avatarView, nameLabel, postTitleLabel, messageLabel, postImageView].forEach(
            contentView.addSubview
        )
        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 20
            ),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 50),
            avatarView.heightAnchor.constraint(equalTo: avatarView.widthAnchor),

            postImageView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -16
            ),
            postImageView.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor
            ),
            postImageView.widthAnchor.constraint(equalToConstant: 46),
            postImageView.heightAnchor.constraint(equalToConstant: 70),

            nameLabel.leadingAnchor.constraint(
                equalTo: avatarView.trailingAnchor,
                constant: 14
            ),
            nameLabel.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 12
            ),
            nameLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: postImageView.leadingAnchor,
                constant: -10
            ),

            postTitleLabel.leadingAnchor.constraint(
                equalTo: nameLabel.leadingAnchor
            ),
            postTitleLabel.topAnchor.constraint(
                equalTo: nameLabel.bottomAnchor,
                constant: 1
            ),
            postTitleLabel.trailingAnchor.constraint(
                equalTo: postImageView.leadingAnchor,
                constant: -10
            ),

            messageLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            messageLabel.topAnchor.constraint(
                equalTo: postTitleLabel.bottomAnchor,
                constant: 2
            ),
            messageLabel.trailingAnchor.constraint(
                equalTo: postTitleLabel.trailingAnchor
            )
        ])
    }

    @objc private func avatarTapped() {
        onAvatarTapped?()
    }
}
