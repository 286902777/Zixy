import UIKit

final class ZixyChatListController: UIViewController,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    private struct ChatItem {
        let name: String
        let message: String
        let image: UIImage?
    }

    private let items = [
        ChatItem(
            name: "Sally",
            message: "Hey, how are you doing?",
            image: ZixyImageLibrary.userAvatar
        ),
        ChatItem(
            name: "Katrina✨Ray",
            message: "hello man, are you single?",
            image: ZixyImageLibrary.chatParticipantAvatar
        ),
        ChatItem(
            name: "🔥Mamazik🔥",
            message: "You are a handsome guy.",
            image: ZixyImageLibrary.userAvatar
        ),
        ChatItem(
            name: "🍷Alice🦄",
            message: "hi, what's your favorite sport?",
            image: ZixyImageLibrary.homeRoomPortrait
        )
    ]

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
        cell.configure(
            image: item.image,
            name: item.name,
            message: item.message
        )
        cell.onAvatarTapped = { [weak self] in
            self?.pushZixyOtherProfile(
                name: item.name,
                image: item.image,
                isCurrentUser: false
            )
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
            participantName: item.name,
            participantImage: item.image,
            isCurrentUser: false
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

    func configure(image: UIImage?, name: String, message: String) {
        avatarView.image = image
        nameLabel.text = name
        messageLabel.text = message
        timeLabel.text = "Just now"
        accessibilityLabel = "\(name), \(message), Just now"
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
}
