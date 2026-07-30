import UIKit

final class ZixyBlacklistController: ZixyScreenController,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    private var items: [ZixyUserRecord] = []

    private lazy var collectionView = makeCollectionView()
    private let emptyLabel = ZixyMemberListEmptyLabel(
        text: "Your blacklist is empty."
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation(title: "Blacklist")
        configureLayout()
        loadBlockedUsers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadBlockedUsers()
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
        let image = ZixyUserAvatarStore.image(for: item)
        cell.configure(
            image: image,
            name: item.username,
            actionLabel: "Remove from blacklist",
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
            removeBlockedMember(at: currentIndexPath)
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

    private func removeBlockedMember(at indexPath: IndexPath) {
        guard
            items.indices.contains(indexPath.item)
        else {
            return
        }
        let user = items[indexPath.item]
        guard (try? ZixyDataStore.shared.setBlocked(
            false,
            blockedEmail: user.email,
            blockerEmail: ZixySessionStore.currentUserIdentifier
        )) != nil else {
            showToast("Unable to update the blacklist.")
            return
        }
        items.remove(at: indexPath.item)
        collectionView.performBatchUpdates {
            collectionView.deleteItems(at: [indexPath])
        } completion: { [weak self] _ in
            self?.updateEmptyState()
        }
        NotificationCenter.default.post(
            name: .zixyBlacklistDidChange,
            object: user.email
        )
        showToast("Removed from blacklist.")
    }

    private func loadBlockedUsers() {
        guard ZixySessionStore.isAuthenticated else {
            items = []
            collectionView.reloadData()
            updateEmptyState()
            return
        }
        items = ZixyDataStore.shared.blockedUsers(
            for: ZixySessionStore.currentUserIdentifier
        )
        collectionView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        emptyLabel.isHidden = !items.isEmpty
    }
}
