import UIKit

final class ZixyRoomGridPageController: UIViewController {

    private enum Layout {
        static let horizontalInset: CGFloat = 12
        static let itemSpacing: CGFloat = 10
        static let lineSpacing: CGFloat = 10
        static let cardAspectRatio: CGFloat = 170 / 204
        static let bottomInset: CGFloat = 92
    }

    private let categoryTitle: String
    private var rooms: [ZixyRoomRecord]

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Layout.itemSpacing
        layout.minimumLineSpacing = Layout.lineSpacing
        layout.sectionInset = UIEdgeInsets(
            top: 0,
            left: Layout.horizontalInset,
            bottom: Layout.bottomInset,
            right: Layout.horizontalInset
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
            ZixyRoomCardCell.self,
            forCellWithReuseIdentifier: ZixyRoomCardCell.reuseIdentifier
        )
        return collectionView
    }()

    init(categoryTitle: String, rooms: [ZixyRoomRecord]) {
        self.categoryTitle = categoryTitle
        self.rooms = rooms
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.accessibilityLabel = "\(categoryTitle) room list"
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func reload(rooms: [ZixyRoomRecord]) {
        self.rooms = rooms
        guard isViewLoaded else {
            return
        }
        collectionView.reloadData()
    }
}

extension ZixyRoomGridPageController:
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        rooms.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ZixyRoomCardCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyRoomCardCell else {
            return UICollectionViewCell()
        }
        let room = rooms[indexPath.item]
        cell.configure(
            title: room.title,
            listenerCount: room.members.count,
            image: ZixyRoomCoverStore.image(reference: room.coverAssetName)
        )
        return cell
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
            height: width / Layout.cardAspectRatio
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard rooms.indices.contains(indexPath.item) else {
            return
        }
        var selectedRoom = rooms[indexPath.item]
        if ZixySessionStore.isAuthenticated {
            do {
                selectedRoom = try ZixyDataStore.shared.joinRoom(
                    id: selectedRoom.id,
                    userEmail: ZixySessionStore.currentUserIdentifier
                )
                rooms[indexPath.item] = selectedRoom
                collectionView.reloadItems(at: [indexPath])
                NotificationCenter.default.post(
                    name: .zixyRoomMembershipDidChange,
                    object: selectedRoom.id
                )
            } catch {
                showToast("Unable to join the room.")
                return
            }
        }
        let controller = ZixyRoomDetailController(room: selectedRoom)
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }
}

private final class ZixyRoomCardCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyRoomCardCell"

    private let portraitImageView: UIImageView = {
        let imageView = UIImageView(image: ZixyImageLibrary.homeRoomPortrait)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private let overlayImageView: UIImageView = {
        let imageView = UIImageView(image: ZixyImageLibrary.homeRoomOverlay)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleToFill
        return imageView
    }()

    private let listenerBadge = ZixyListenerBadgeView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ZixyFontBook.bold(size: 17, relativeTo: .headline)
        label.textColor = .white
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        portraitImageView.image = ZixyImageLibrary.homeRoomPortrait
    }

    func configure(title: String, listenerCount: Int, image: UIImage?) {
        portraitImageView.image = image ?? ZixyImageLibrary.homeRoomPortrait
        titleLabel.text = title
        listenerBadge.configure(listenerCount: listenerCount)
        accessibilityLabel = "\(title), \(listenerCount) listeners"
    }

    private func configureLayout() {
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        contentView.addSubview(portraitImageView)
        contentView.addSubview(overlayImageView)
        contentView.addSubview(listenerBadge)
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            portraitImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            portraitImageView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),
            portraitImageView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),
            portraitImageView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor
            ),

            overlayImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlayImageView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),
            overlayImageView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),
            overlayImageView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor
            ),

            listenerBadge.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 12
            ),
            listenerBadge.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),
            listenerBadge.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 12
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -10
            ),
            titleLabel.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -10
            )
        ])
    }
}

private final class ZixyListenerBadgeView: UIView {

    private let waveView = ZixySoundWaveView()
    private let countLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ZixyFontBook.bold(size: 14)
        label.textColor = .white
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(
            red: 1,
            green: 52 / 255,
            blue: 177 / 255,
            alpha: 1
        )
        layer.cornerRadius = 14
        layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMinXMaxYCorner
        ]

        addSubview(waveView)
        addSubview(countLabel)
        NSLayoutConstraint.activate([
            waveView.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 10
            ),
            waveView.centerYAnchor.constraint(equalTo: centerYAnchor),
            waveView.widthAnchor.constraint(equalToConstant: 18),
            waveView.heightAnchor.constraint(equalToConstant: 18),

            countLabel.leadingAnchor.constraint(
                equalTo: waveView.trailingAnchor,
                constant: 5
            ),
            countLabel.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -9
            ),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(listenerCount: Int) {
        countLabel.text = "\(listenerCount)"
    }
}

private final class ZixySoundWaveView: UIView {

    private let barHeights: [CGFloat] = [8, 15, 11, 18, 10]

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        addSubview(stack)

        for height in barHeights {
            let bar = UIView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.backgroundColor = .white
            bar.layer.cornerRadius = 1
            NSLayoutConstraint.activate([
                bar.widthAnchor.constraint(equalToConstant: 2),
                bar.heightAnchor.constraint(equalToConstant: height)
            ])
            stack.addArrangedSubview(bar)
        }

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
