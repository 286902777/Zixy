import UIKit

final class ZixyBlacklistController: ZixyScreenController,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    private struct BlockedItem {
        let id: Int
        let name: String
        let image: UIImage?
        let isCurrentUser: Bool
    }

    private var items = [
        BlockedItem(
            id: 0,
            name: "Marry✨",
            image: ZixyImageLibrary.homeRoomPortrait,
            isCurrentUser: false
        ),
        BlockedItem(
            id: 1,
            name: "Marry✨",
            image: ZixyImageLibrary.profileAvatar,
            isCurrentUser: false
        ),
        BlockedItem(
            id: 2,
            name: "Marry✨",
            image: ZixyImageLibrary.userAvatar,
            isCurrentUser: false
        ),
        BlockedItem(
            id: 3,
            name: "Marry✨",
            image: ZixyImageLibrary.homeRoomPortrait,
            isCurrentUser: false
        )
    ]

    private lazy var collectionView = makeCollectionView()
    private let emptyLabel = ZixyMemberListEmptyLabel(
        text: "Your blacklist is empty."
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation(title: "Blacklist")
        configureLayout()
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
            actionLabel: "Remove from blacklist"
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
            items.indices.contains(indexPath.item),
            !items[indexPath.item].isCurrentUser
        else {
            return
        }
        items.remove(at: indexPath.item)
        collectionView.performBatchUpdates {
            collectionView.deleteItems(at: [indexPath])
        } completion: { [weak self] _ in
            self?.updateEmptyState()
        }
        showToast("Removed from blacklist.")
    }

    private func updateEmptyState() {
        emptyLabel.isHidden = !items.isEmpty
    }
}
