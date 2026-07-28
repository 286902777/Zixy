import UIKit

final class ZixyMessageRoomsController: UIViewController,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    private let roomTitles = [
        "Here is the room...",
        "Here is the room...",
        "Here is the room...",
        "Here is the room..."
    ]

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 0, left: 12, bottom: 92, right: 12)

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
            ZixyMessageRoomCell.self,
            forCellWithReuseIdentifier: ZixyMessageRoomCell.reuseIdentifier
        )
        return collectionView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        roomTitles.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ZixyMessageRoomCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyMessageRoomCell else {
            return UICollectionViewCell()
        }
        cell.configure(
            title: roomTitles[indexPath.item],
            listenerCount: 832
        )
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = floor((collectionView.bounds.width - 34) / 2)
        return CGSize(width: width, height: 205)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let controller = ZixyRoomDetailController(
            roomTitle: roomTitles[indexPath.item]
        )
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }
}

private final class ZixyMessageRoomCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyMessageRoomCell"

    private let imageView = UIImageView(image: ZixyImageLibrary.homeRoomPortrait)
    private let gradientLayer = CAGradientLayer()
    private let titleLabel = UILabel()
    private let badge = ZixyMessageListenerBadge()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = contentView.bounds
    }

    func configure(title: String, listenerCount: Int) {
        titleLabel.text = title
        badge.configure(count: listenerCount)
        accessibilityLabel = "\(title), \(listenerCount) listeners"
    }

    private func configureLayout() {
        contentView.layer.cornerRadius = 9
        contentView.layer.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor(red: 55 / 255, green: 101 / 255, blue: 1, alpha: 0.95).cgColor
        ]
        gradientLayer.locations = [0.55, 1]

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = ZixyFontBook.bold(size: 14, relativeTo: .subheadline)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1

        contentView.addSubview(imageView)
        contentView.layer.addSublayer(gradientLayer)
        contentView.addSubview(titleLabel)
        contentView.addSubview(badge)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            badge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            badge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            badge.heightAnchor.constraint(equalToConstant: 26),

            titleLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 12
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -8
            ),
            titleLabel.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -10
            )
        ])
    }
}

private final class ZixyMessageListenerBadge: UIView {

    private let waveLabel = UILabel()
    private let countLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(
            red: 1,
            green: 52 / 255,
            blue: 177 / 255,
            alpha: 1
        )
        layer.cornerRadius = 13
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]

        waveLabel.translatesAutoresizingMaskIntoConstraints = false
        waveLabel.text = "▥"
        waveLabel.font = ZixyFontBook.bold(size: 12)
        waveLabel.textColor = .white
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = ZixyFontBook.bold(size: 12)
        countLabel.textColor = .white

        addSubview(waveLabel)
        addSubview(countLabel)
        NSLayoutConstraint.activate([
            waveLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            waveLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            countLabel.leadingAnchor.constraint(
                equalTo: waveLabel.trailingAnchor,
                constant: 3
            ),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(count: Int) {
        countLabel.text = "\(count)"
    }
}
