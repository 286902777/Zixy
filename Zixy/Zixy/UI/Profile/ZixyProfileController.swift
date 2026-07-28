import UIKit

final class ZixyProfileController: ZixyScreenController,
    UICollectionViewDataSource,
    ZixyMasonryLayoutDelegate {

    private struct PostItem {
        let image: UIImage?
        let text: String
        let likes: String
        let showsPlayIcon: Bool
    }

    private let posts = [
        PostItem(
            image: ZixyImageLibrary.homeRoomPortrait,
            text: "I like Harry Potter, how about you?",
            likes: "1.1K",
            showsPlayIcon: false
        ),
        PostItem(
            image: ZixyImageLibrary.profileAvatar,
            text: "I like Harry Potter, how about you?",
            likes: "1.2K",
            showsPlayIcon: true
        ),
        PostItem(
            image: ZixyImageLibrary.userAvatar,
            text: "A new handmade piece from my workshop.",
            likes: "986",
            showsPlayIcon: false
        ),
        PostItem(
            image: ZixyImageLibrary.homeRoomPortrait,
            text: "Making something beautiful today.",
            likes: "832",
            showsPlayIcon: false
        )
    ]

    private lazy var collectionView: UICollectionView = {
        let layout = ZixyMasonryLayout()
        layout.delegate = self

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInset.bottom = 92
        collectionView.dataSource = self
        collectionView.register(
            ZixyProfilePostCell.self,
            forCellWithReuseIdentifier: ZixyProfilePostCell.reuseIdentifier
        )
        collectionView.register(
            ZixyProfileHeaderView.self,
            forSupplementaryViewOfKind:
                UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ZixyProfileHeaderView.reuseIdentifier
        )
        return collectionView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.isHidden = true
        configureCollectionView()
    }

    private func configureCollectionView() {
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

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
            likes: post.likes,
            showsPlayIcon: post.showsPlayIcon
        )
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: ZixyProfileHeaderView.reuseIdentifier,
            for: indexPath
        ) as? ZixyProfileHeaderView else {
            return UICollectionReusableView()
        }
        header.onAction = { [weak self] title in
            guard let self else {
                return
            }
            if title == "Edit Profile" {
                push(ZixyEditProfileController())
            } else if title == "Following" {
                push(ZixyFollowingController())
            } else if title == "Followers" {
                push(ZixyFollowersController())
            } else if title == "Blacklist" {
                push(ZixyBlacklistController())
            } else {
                showToast("\(title) is coming soon.")
            }
        }
        return header
    }

    fileprivate func masonryLayout(
        _ layout: ZixyMasonryLayout,
        imageAspectRatioAt indexPath: IndexPath
    ) -> CGFloat {
        guard
            let image = posts[indexPath.item].image,
            image.size.width > 0
        else {
            return 1
        }
        return image.size.height / image.size.width
    }
}

private final class ZixyProfileHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "ZixyProfileHeaderView"

    var onAction: ((String) -> Void)?

    private let avatarView = UIImageView(image: ZixyImageLibrary.profileAvatar)
    private let nameLabel = UILabel()
    private let bioLabel = UILabel()
    private let settingsCard = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureProfile()
        configureStats()
        configureRechargeCard()
        configureSettings()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func configureProfile() {
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 35

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = "Katrina✨Ray"
        nameLabel.font = ZixyFontBook.bold(size: 23, relativeTo: .title2)
        nameLabel.textColor = UIColor(
            red: 20 / 255,
            green: 82 / 255,
            blue: 111 / 255,
            alpha: 1
        )

        bioLabel.translatesAutoresizingMaskIntoConstraints = false
        bioLabel.text = "'News?' asked the taller of the two."
        bioLabel.font = ZixyFontBook.bold(size: 14, relativeTo: .subheadline)
        bioLabel.textColor = UIColor(
            red: 20 / 255,
            green: 82 / 255,
            blue: 111 / 255,
            alpha: 0.72
        )
        bioLabel.numberOfLines = 1
        bioLabel.adjustsFontSizeToFitWidth = true
        bioLabel.minimumScaleFactor = 0.75

        addSubview(avatarView)
        addSubview(nameLabel)
        addSubview(bioLabel)
        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            avatarView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            avatarView.widthAnchor.constraint(equalToConstant: 70),
            avatarView.heightAnchor.constraint(equalToConstant: 70),

            nameLabel.leadingAnchor.constraint(
                equalTo: avatarView.trailingAnchor,
                constant: 13
            ),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 19),
            nameLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -16
            ),

            bioLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            bioLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            bioLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }

    private func configureStats() {
        let stack = UIStackView(arrangedSubviews: [
            makeStat(title: "Following", value: "1.1 K"),
            makeStat(title: "Followers", value: "1.2 K"),
            makeStat(title: "Likes", value: "1.2 K")
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 7),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    private func configureRechargeCard() {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(
            red: 0,
            green: 43 / 255,
            blue: 32 / 255,
            alpha: 1
        )
        card.layer.cornerRadius = 20

        let coinLabel = UILabel()
        coinLabel.translatesAutoresizingMaskIntoConstraints = false
        coinLabel.text = "🪙"
        coinLabel.font = .systemFont(ofSize: 36)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "RECHARGE"
        titleLabel.font = ZixyFontBook.bold(size: 18, relativeTo: .headline)
        titleLabel.textColor = UIColor(
            red: 1,
            green: 185 / 255,
            blue: 142 / 255,
            alpha: 1
        )

        let balanceLabel = UILabel()
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        balanceLabel.text = "My Balance: 14200"
        balanceLabel.font = ZixyFontBook.bold(size: 9, relativeTo: .caption2)
        balanceLabel.textColor = .white

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Recharge   ➜", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = ZixyFontBook.bold(size: 13)
        button.backgroundColor = UIColor(
            red: 1,
            green: 185 / 255,
            blue: 142 / 255,
            alpha: 1
        )
        button.layer.cornerRadius = 15
        button.addAction(UIAction { [weak self] _ in
            self?.onAction?("Recharge")
        }, for: .touchUpInside)

        addSubview(card)
        [coinLabel, titleLabel, balanceLabel, button].forEach(card.addSubview)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor, constant: 127),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            card.heightAnchor.constraint(equalToConstant: 62),

            coinLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 13),
            coinLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            titleLabel.leadingAnchor.constraint(
                equalTo: coinLabel.trailingAnchor,
                constant: 8
            ),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            balanceLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            balanceLabel.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor,
                constant: -2
            ),

            button.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -13),
            button.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 110),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    private func configureSettings() {
        let background = UIView()
        background.translatesAutoresizingMaskIntoConstraints = false
        background.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        background.layer.cornerRadius = 17

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "Basic Settings"
        title.font = ZixyFontBook.bold(size: 16, relativeTo: .headline)
        title.textColor = .systemGray

        let postTitle = UILabel()
        postTitle.translatesAutoresizingMaskIntoConstraints = false
        postTitle.text = "My Post"
        postTitle.font = ZixyFontBook.bold(size: 17, relativeTo: .headline)
        postTitle.textColor = .systemGray

        let rows = [
            ZixyProfileSettingRow(
                image: ZixyImageLibrary.profileEdit,
                title: "Edit Profile"
            ),
            ZixyProfileSettingRow(
                image: ZixyImageLibrary.profileRoom,
                title: "My Room"
            ),
            ZixyProfileSettingRow(
                image: ZixyImageLibrary.profileBlacklist,
                title: "Blacklist"
            ),
            ZixyProfileSettingRow(
                image: ZixyImageLibrary.profileSettings,
                title: "Setting"
            )
        ]
        let stack = UIStackView(arrangedSubviews: rows)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.distribution = .fillEqually

        addSubview(title)
        addSubview(background)
        background.addSubview(stack)
        addSubview(postTitle)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: 205),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),

            background.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 9),
            background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 11),
            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            background.heightAnchor.constraint(equalToConstant: 170),

            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 5),
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -5),

            postTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            postTitle.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7)
        ])

        rows.forEach { row in
            row.onTap = { [weak self] title in
                self?.onAction?(title)
            }
        }
    }

    private func makeStat(title: String, value: String) -> UIView {
        let control = ZixyProfileStatControl(title: title, value: value)
        control.onTap = { [weak self] title in
            self?.onAction?(title)
        }
        return control
    }
}

private final class ZixyProfileStatControl: UIControl {

    var onTap: ((String) -> Void)?
    private let title: String

    init(title: String, value: String) {
        self.title = title
        super.init(frame: .zero)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        label.attributedText = NSAttributedString(
            string: "\(title)  \(value)",
            attributes: [
                .font: ZixyFontBook.bold(size: 12, relativeTo: .caption1),
                .foregroundColor: UIColor(
                    red: 20 / 255,
                    green: 82 / 255,
                    blue: 111 / 255,
                    alpha: 0.8
                )
            ]
        )
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        accessibilityLabel = "\(title), \(value)"
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func tapped() {
        onTap?(title)
    }
}

private final class ZixyProfileSettingRow: UIControl {

    var onTap: ((String) -> Void)?
    private let title: String

    init(image: UIImage?, title: String) {
        self.title = title
        super.init(frame: .zero)

        let iconView = UIImageView(image: image)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = ZixyFontBook.bold(size: 15, relativeTo: .body)
        titleLabel.textColor = UIColor.black.withAlphaComponent(0.82)

        let disclosure = UIImageView(image: ZixyImageLibrary.profileDisclosure)
        disclosure.translatesAutoresizingMaskIntoConstraints = false
        disclosure.contentMode = .scaleAspectFit

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(disclosure)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(
                equalTo: iconView.trailingAnchor,
                constant: 9
            ),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            disclosure.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            disclosure.centerYAnchor.constraint(equalTo: centerYAnchor),
            disclosure.widthAnchor.constraint(equalToConstant: 14),
            disclosure.heightAnchor.constraint(equalToConstant: 14)
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        accessibilityLabel = title
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func tapped() {
        onTap?(title)
    }
}

private final class ZixyProfilePostCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyProfilePostCell"

    private let imageView = UIImageView()
    private let textLabel = UILabel()
    private let likesLabel = UILabel()
    private let playView = UIImageView(
        image: UIImage(systemName: "play.fill")
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        image: UIImage?,
        text: String,
        likes: String,
        showsPlayIcon: Bool
    ) {
        imageView.image = image
        textLabel.text = text
        likesLabel.text = "♡ \(likes)"
        playView.isHidden = !showsPlayIcon
        accessibilityLabel = "\(text), \(likes) likes"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.layer.cornerRadius = 12
    }

    private func configureLayout() {
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = ZixyFontBook.bold(size: 12, relativeTo: .caption1)
        textLabel.textColor = UIColor.black.withAlphaComponent(0.76)
        textLabel.numberOfLines = 2

        likesLabel.translatesAutoresizingMaskIntoConstraints = false
        likesLabel.font = ZixyFontBook.bold(size: 9, relativeTo: .caption2)
        likesLabel.textColor = .systemGray

        playView.translatesAutoresizingMaskIntoConstraints = false
        playView.tintColor = UIColor.white.withAlphaComponent(0.75)
        playView.contentMode = .scaleAspectFit

        [imageView, textLabel, likesLabel, playView].forEach {
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -58
            ),

            textLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 6),
            textLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 9
            ),
            textLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -8
            ),

            likesLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -8
            ),
            likesLabel.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -5
            ),

            playView.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            playView.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            playView.widthAnchor.constraint(equalToConstant: 45),
            playView.heightAnchor.constraint(equalToConstant: 45)
        ])
    }
}

private protocol ZixyMasonryLayoutDelegate: AnyObject {
    func masonryLayout(
        _ layout: ZixyMasonryLayout,
        imageAspectRatioAt indexPath: IndexPath
    ) -> CGFloat
}

private final class ZixyMasonryLayout: UICollectionViewLayout {

    weak var delegate: ZixyMasonryLayoutDelegate?

    private let columnCount = 2
    private let horizontalInset: CGFloat = 11
    private let spacing: CGFloat = 10
    private let headerHeight: CGFloat = 430
    private let textAreaHeight: CGFloat = 58
    private var attributes: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0

    override var collectionViewContentSize: CGSize {
        CGSize(
            width: collectionView?.bounds.width ?? 0,
            height: contentHeight
        )
    }

    override func prepare() {
        super.prepare()
        guard let collectionView else {
            return
        }
        attributes.removeAll()

        let headerPath = IndexPath(item: 0, section: 0)
        let header = UICollectionViewLayoutAttributes(
            forSupplementaryViewOfKind:
                UICollectionView.elementKindSectionHeader,
            with: headerPath
        )
        header.frame = CGRect(
            x: 0,
            y: 0,
            width: collectionView.bounds.width,
            height: headerHeight
        )
        attributes.append(header)

        let availableWidth = collectionView.bounds.width
            - (horizontalInset * 2)
            - spacing
        let columnWidth = floor(availableWidth / CGFloat(columnCount))
        var columnHeights = Array(
            repeating: headerHeight,
            count: columnCount
        )

        let itemCount = collectionView.numberOfItems(inSection: 0)
        for item in 0..<itemCount {
            let indexPath = IndexPath(item: item, section: 0)
            let column = columnHeights[0] <= columnHeights[1] ? 0 : 1
            let aspectRatio = delegate?.masonryLayout(
                self,
                imageAspectRatioAt: indexPath
            ) ?? 1
            let imageHeight = columnWidth * aspectRatio
            let height = imageHeight + textAreaHeight
            let x = horizontalInset + CGFloat(column) * (columnWidth + spacing)
            let y = columnHeights[column] + spacing

            let itemAttributes = UICollectionViewLayoutAttributes(
                forCellWith: indexPath
            )
            itemAttributes.frame = CGRect(
                x: x,
                y: y,
                width: columnWidth,
                height: height
            )
            attributes.append(itemAttributes)
            columnHeights[column] = itemAttributes.frame.maxY
        }
        contentHeight = (columnHeights.max() ?? headerHeight) + spacing
    }

    override func layoutAttributesForElements(
        in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {
        attributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        attributes.first { $0.indexPath == indexPath && $0.representedElementKind == nil }
    }

    override func layoutAttributesForSupplementaryView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        attributes.first {
            $0.indexPath == indexPath
                && $0.representedElementKind == elementKind
        }
    }

    override func shouldInvalidateLayout(
        forBoundsChange newBounds: CGRect
    ) -> Bool {
        newBounds.width != collectionView?.bounds.width
    }
}
