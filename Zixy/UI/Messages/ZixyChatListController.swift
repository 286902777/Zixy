import UIKit

final class ZixyChatListController: UIViewController,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    private var items: [ZixyChatSummaryRecord] = []

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 92, right: 0)

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
            ZixyChatCell.self,
            forCellWithReuseIdentifier: ZixyChatCell.reuseIdentifier
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        items = ZixyDataStore.shared.chatSummaries(
            for: ZixySessionStore.currentUserIdentifier
        )
        collectionView.reloadData()
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
            withReuseIdentifier: ZixyChatCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyChatCell else {
            return UICollectionViewCell()
        }
        let item = items[indexPath.item]
        let image = ZixyUserAvatarStore.image(for: item.participant)
        cell.configure(
            image: image,
            name: item.participant.username,
            message: item.lastMessage,
            date: item.updatedAt
        )
        cell.onAvatarTapped = { [weak self] in
            self?.pushZixyOtherProfile(userEmail: item.participant.email)
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: 80)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let item = items[indexPath.item]
        let controller = ZixyConversationController(
            participantName: item.participant.username,
            participantImage: ZixyUserAvatarStore.image(
                for: item.participant
            ),
            isCurrentUser: false,
            participantEmail: item.participant.email
        )
        navigationController?.pushViewController(controller, animated: true)
    }
}

private final class ZixyChatCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyChatCell"

    var onAvatarTapped: (() -> Void)?

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let messageLabel = UILabel()
    private let timeLabel = UILabel()

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
        image: UIImage?,
        name: String,
        message: String,
        date: Date
    ) {
        avatarView.image = image
        nameLabel.text = name
        messageLabel.text = message
        timeLabel.text = Self.relativeFormatter.localizedString(
            for: date,
            relativeTo: Date()
        )
        accessibilityLabel = "\(name), \(message), \(timeLabel.text ?? "")"
    }

    private func configureLayout() {
        [avatarView, nameLabel, messageLabel, timeLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 27
        avatarView.isUserInteractionEnabled = true
        avatarView.accessibilityTraits = .button
        avatarView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        )

        nameLabel.font = ZixyFontBook.bold(size: 18, relativeTo: .headline)
        nameLabel.textColor = UIColor(
            red: 47 / 255,
            green: 48 / 255,
            blue: 51 / 255,
            alpha: 1
        )
        messageLabel.font = ZixyFontBook.bold(size: 14, relativeTo: .subheadline)
        messageLabel.textColor = .systemGray
        timeLabel.font = ZixyFontBook.bold(size: 12, relativeTo: .caption1)
        timeLabel.textColor = .systemGray2

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 20
            ),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 54),
            avatarView.heightAnchor.constraint(equalToConstant: 54),

            nameLabel.leadingAnchor.constraint(
                equalTo: avatarView.trailingAnchor,
                constant: 11
            ),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: timeLabel.leadingAnchor,
                constant: -8
            ),

            messageLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            messageLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            messageLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: contentView.trailingAnchor,
                constant: -20
            ),

            timeLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -20
            ),
            timeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor)
        ])
    }

    @objc private func avatarTapped() {
        onAvatarTapped?()
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
