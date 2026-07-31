import UIKit

final class ZixyFollowingController: ZixyScreenController,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    private struct FollowingItem {
        let email: String
        let name: String
        let image: UIImage?
        let isCurrentUser: Bool
    }

    private var items: [FollowingItem] = []

    private lazy var collectionView = makeCollectionView()
    private let emptyLabel = ZixyMemberListEmptyLabel(
        text: "You are not following anyone yet."
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation(title: "Following")
        configureLayout()
        updateEmptyState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadFollowing()
    }

    private func loadFollowing() {
        items = ZixyDataStore.shared.following(
            for: ZixySessionStore.currentUserIdentifier
        ).map {
            FollowingItem(
                email: $0.email,
                name: $0.username,
                image: ZixyUserAvatarStore.image(for: $0),
                isCurrentUser: false
            )
        }
        collectionView.reloadData()
        updateEmptyState()
    }

    private func makeCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 5, left: 0, bottom: 24, right: 0)

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
            ZixyMemberRemovalCell.self,
            forCellWithReuseIdentifier: ZixyMemberRemovalCell.reuseIdentifier
        )
        return collectionView
    }

    private func configureLayout() {
        contentView.addSubview(collectionView)
        contentView.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            emptyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 80),
            emptyLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: contentView.leadingAnchor,
                constant: 24
            ),
            emptyLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: contentView.trailingAnchor,
                constant: -24
            )
        ])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        items.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ZixyMemberRemovalCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyMemberRemovalCell else {
            return UICollectionViewCell()
        }
        let item = items[indexPath.item]
        cell.configure(
            image: item.image,
            name: item.name,
            actionLabel: "Unfollow",
            actionImage: ZixyImageLibrary.profileRemove
        )
        cell.onRemove = { [weak self, weak cell] in
            guard
                let self,
                let cell,
                let currentIndexPath = collectionView.indexPath(for: cell)
            else {
                return
            }
            removeFollowing(at: currentIndexPath)
        }
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
        CGSize(width: collectionView.bounds.width, height: 74)
    }

    private func removeFollowing(at indexPath: IndexPath) {
        guard
            items.indices.contains(indexPath.item),
            !items[indexPath.item].isCurrentUser
        else {
            return
        }
        guard ZixySessionStore.allowsSocialInteraction else {
            showToast("Sign in to update the follow status.")
            return
        }
        let item = items[indexPath.item]
        do {
            try ZixyDataStore.shared.setFollowing(
                false,
                followedEmail: item.email,
                followerEmail: ZixySessionStore.currentUserIdentifier
            )
        } catch {
            showToast("Unable to update the follow status.")
            return
        }
        items.remove(at: indexPath.item)
        collectionView.deleteItems(at: [indexPath])
        updateEmptyState()
        showToast("Unfollowed \(item.name).")
    }

    private func updateEmptyState() {
        emptyLabel.isHidden = !items.isEmpty
    }
}

final class ZixyMemberRemovalCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyMemberRemovalCell"

    var onRemove: (() -> Void)?
    var onAvatarTapped: (() -> Void)?

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let removeButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onRemove = nil
        onAvatarTapped = nil
    }

    func configure(
        image: UIImage?,
        name: String,
        actionLabel: String,
        actionImage: UIImage?
    ) {
        avatarView.image = image
        nameLabel.text = name
        removeButton.setImage(
            actionImage?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        removeButton.accessibilityLabel = "\(actionLabel) \(name)"
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

        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.imageView?.contentMode = .scaleAspectFit
        removeButton.addTarget(
            self,
            action: #selector(removeTapped),
            for: .touchUpInside
        )

        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(removeButton)
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
                lessThanOrEqualTo: removeButton.leadingAnchor,
                constant: -12
            ),

            removeButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -22
            ),
            removeButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 36),
            removeButton.heightAnchor.constraint(equalTo: removeButton.widthAnchor)
        ])
    }

    @objc private func removeTapped() {
        onRemove?()
    }

    @objc private func avatarTapped() {
        onAvatarTapped?()
    }
}

final class ZixyMemberListEmptyLabel: UILabel {

    init(text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        self.text = text
        textAlignment = .center
        numberOfLines = 0
        font = ZixyFontBook.bold(size: 16, relativeTo: .body)
        textColor = .systemGray
        isUserInteractionEnabled = false
        isHidden = true
    }

    required init?(coder: NSCoder) {
        nil
    }
}
