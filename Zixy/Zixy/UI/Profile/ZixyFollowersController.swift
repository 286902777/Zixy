import UIKit

final class ZixyFollowersController: ZixyScreenController,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    private struct FollowerItem {
        let email: String
        let name: String
        let image: UIImage?
        var isFollowed: Bool
    }

    private var followers: [FollowerItem] = []

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.sectionInset = UIEdgeInsets(
            top: 5,
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
            ZixyFollowerCell.self,
            forCellWithReuseIdentifier: ZixyFollowerCell.reuseIdentifier
        )
        return collectionView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation(title: "Followers")
        configureCollectionView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadFollowers()
    }

    private func loadFollowers() {
        let currentEmail = ZixySessionStore.currentUserIdentifier
        followers = ZixyDataStore.shared.followers(for: currentEmail).map {
            FollowerItem(
                email: $0.email,
                name: $0.username,
                image: ZixyUserAvatarStore.image(for: $0),
                isFollowed: ZixyDataStore.shared.isFollowing(
                    $0.email,
                    from: currentEmail
                )
            )
        }
        collectionView.reloadData()
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
        followers.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ZixyFollowerCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyFollowerCell else {
            return UICollectionViewCell()
        }

        let follower = followers[indexPath.item]
        cell.configure(
            image: follower.image,
            name: follower.name,
            isFollowed: follower.isFollowed
        )
        cell.onFollow = { [weak self] in
            self?.removeFollowing(at: indexPath)
        }
        cell.onAvatarTapped = { [weak self] in
            self?.pushZixyOtherProfile(userEmail: follower.email)
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: 74)
    }

    private func removeFollowing(at indexPath: IndexPath) {
        guard followers.indices.contains(indexPath.item) else {
            return
        }
        let follower = followers[indexPath.item]
        do {
            try ZixyDataStore.shared.setFollowing(
                false,
                followedEmail: follower.email,
                followerEmail: ZixySessionStore.currentUserIdentifier
            )
        } catch {
            showToast("Unable to update the follow status.")
            return
        }
        followers[indexPath.item].isFollowed = false
        collectionView.reloadItems(at: [indexPath])
        showToast("Unfollowed \(follower.name).")
    }
}

private final class ZixyFollowerCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyFollowerCell"

    var onFollow: (() -> Void)?
    var onAvatarTapped: (() -> Void)?

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let followButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onFollow = nil
        onAvatarTapped = nil
    }

    func configure(image: UIImage?, name: String, isFollowed: Bool) {
        avatarView.image = image
        nameLabel.text = name
        followButton.setImage(
            ZixyImageLibrary.profileRemove?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        followButton.backgroundColor = .clear
        followButton.accessibilityLabel = isFollowed
            ? "Unfollow \(name)"
            : "Follow \(name)"
        accessibilityLabel = name
    }

    private func configureLayout() {
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
        nameLabel.font = ZixyFontBook.bold(size: 21, relativeTo: .title3)
        nameLabel.textColor = UIColor.black.withAlphaComponent(0.78)

        followButton.translatesAutoresizingMaskIntoConstraints = false
        followButton.imageView?.contentMode = .scaleAspectFit
        followButton.addTarget(
            self,
            action: #selector(followTapped),
            for: .touchUpInside
        )

        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(followButton)
        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 23
            ),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 50),
            avatarView.heightAnchor.constraint(equalTo: avatarView.widthAnchor),

            nameLabel.leadingAnchor.constraint(
                equalTo: avatarView.trailingAnchor,
                constant: 14
            ),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: followButton.leadingAnchor,
                constant: -12
            ),

            followButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -22
            ),
            followButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            followButton.widthAnchor.constraint(equalToConstant: 36),
            followButton.heightAnchor.constraint(equalTo: followButton.widthAnchor)
        ])
    }

    @objc private func followTapped() {
        onFollow?()
    }

    @objc private func avatarTapped() {
        onAvatarTapped?()
    }
}
