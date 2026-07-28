import UIKit

final class ZixyFeedController: ZixyScreenController {

    private struct FeedItem {
        let imageName: String
        let title: String
        let isVideo: Bool
        var likeCount: Int
        var isLiked: Bool
    }

    private enum Layout {
        static let headerHeight: CGFloat = 82
        static let titleWidth: CGFloat = 205
        static let titleHeight: CGFloat = 69
        static let releaseWidth: CGFloat = 115
        static let releaseHeight: CGFloat = 30
        static let cardTextSize: CGFloat = 17
        static let cardHorizontalInset: CGFloat = 10
        static let cardVerticalPadding: CGFloat = 12
        static let cardFooterHeight: CGFloat = 34
    }

    private var items: [FeedItem] = [
        FeedItem(
            imageName: "zixy_home_room_portrait",
            title: "Technical explanation by a master woodcarver",
            isVideo: false,
            likeCount: 1_100,
            isLiked: false
        ),
        FeedItem(
            imageName: "zixy_feed_wood_mountain",
            title: "Excellent works in the woodcarving competition",
            isVideo: true,
            likeCount: 1_100,
            isLiked: false
        ),
        FeedItem(
            imageName: "zixy_user_avatar",
            title: "Resin figurine coloring tutorial",
            isVideo: false,
            likeCount: 1_100,
            isLiked: false
        ),
        FeedItem(
            imageName: "zixy_ai_chat_background",
            title: "Share finished handmade crafts",
            isVideo: true,
            likeCount: 1_100,
            isLiked: false
        ),
        FeedItem(
            imageName: "zixy_home_ai_banner",
            title: "Creative felt flower basket",
            isVideo: false,
            likeCount: 846,
            isLiked: false
        ),
        FeedItem(
            imageName: "zixy_feed_wood_mountain",
            title: "Detailed sculpture finishing process",
            isVideo: false,
            likeCount: 972,
            isLiked: false
        ),
        FeedItem(
            imageName: "zixy_home_room_portrait",
            title: "Small craft studio inspiration",
            isVideo: true,
            likeCount: 625,
            isLiked: false
        ),
        FeedItem(
            imageName: "zixy_user_avatar",
            title: "Hand-painted character study",
            isVideo: false,
            likeCount: 508,
            isLiked: false
        )
    ]

    private let headerView = UIView()

    private let titleImageView: UIImageView = {
        let imageView = UIImageView(image: ZixyImageLibrary.feedTitle)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.accessibilityLabel = "Feeds"
        return imageView
    }()

    private let releaseButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(ZixyImageLibrary.feedReleaseButton, for: .normal)
        button.accessibilityLabel = "Release a craft post"
        return button
    }()

    private let waterfallLayout = ZixyWaterfallLayout()

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: waterfallLayout
        )
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            ZixyFeedCardCell.self,
            forCellWithReuseIdentifier: ZixyFeedCardCell.reuseIdentifier
        )
        return collectionView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.isHidden = true
        waterfallLayout.delegate = self
        configureLayout()
        configureInteractions()
    }

    private func configureLayout() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .clear
        view.addSubview(headerView)
        view.addSubview(collectionView)
        headerView.addSubview(titleImageView)
        headerView.addSubview(releaseButton)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(
                equalToConstant: Layout.headerHeight
            ),

            titleImageView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleImageView.widthAnchor.constraint(
                equalToConstant: Layout.titleWidth
            ),
            titleImageView.heightAnchor.constraint(
                equalToConstant: Layout.titleHeight
            ),

            releaseButton.trailingAnchor.constraint(
                equalTo: headerView.trailingAnchor,
                constant: 32
            ),
            releaseButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            releaseButton.widthAnchor.constraint(
                equalToConstant: Layout.releaseWidth
            ),
            releaseButton.heightAnchor.constraint(
                equalToConstant: Layout.releaseHeight
            ),

            collectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureInteractions() {
        releaseButton.addTarget(
            self,
            action: #selector(openReleaseEditor),
            for: .touchUpInside
        )
    }

    private func imageHeight(for item: FeedItem, itemWidth: CGFloat) -> CGFloat {
        guard let image = UIImage(named: item.imageName),
              image.size.width > 0 else {
            return itemWidth
        }
        return ceil(itemWidth * image.size.height / image.size.width)
    }

    private func titleHeight(for item: FeedItem, itemWidth: CGFloat) -> CGFloat {
        let availableWidth = itemWidth - Layout.cardHorizontalInset * 2
        let font = ZixyFontBook.bold(size: Layout.cardTextSize)
        let rect = (item.title as NSString).boundingRect(
            with: CGSize(
                width: availableWidth,
                height: .greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.height)
    }

    private func formattedLikeCount(_ count: Int) -> String {
        if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    @objc private func openReleaseEditor() {
        push(ZixyReleaseController())
    }
}

extension ZixyFeedController:
    UICollectionViewDataSource,
    UICollectionViewDelegate {

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
            withReuseIdentifier: ZixyFeedCardCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyFeedCardCell else {
            return UICollectionViewCell()
        }

        let item = items[indexPath.item]
        let itemWidth = waterfallLayout.layoutAttributesForItem(
            at: indexPath
        )?.frame.width ?? 172
        cell.configure(
            imageName: item.imageName,
            imageHeight: imageHeight(for: item, itemWidth: itemWidth),
            title: item.title,
            isVideo: item.isVideo,
            likeCount: formattedLikeCount(item.likeCount),
            isLiked: item.isLiked
        )
        cell.onLikeTapped = { [weak self] in
            self?.toggleLike(at: indexPath)
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard items.indices.contains(indexPath.item) else {
            return
        }
        let item = items[indexPath.item]
        let poster = UIImage(named: item.imageName)
        let media: ZixyVideoDetailController.Media
        if item.isVideo,
           let url = Bundle.main.url(
               forResource: "zixy_sample_craft_video",
               withExtension: "mp4"
           ) {
            media = .video(url: url, poster: poster)
        } else {
            media = .image(poster)
        }
        push(ZixyVideoDetailController(media: media))
    }

    private func toggleLike(at indexPath: IndexPath) {
        guard ZixySessionStore.allowsSocialInteraction else {
            showToast("Sign in to like posts.")
            return
        }
        guard items.indices.contains(indexPath.item) else {
            return
        }
        items[indexPath.item].isLiked.toggle()
        items[indexPath.item].likeCount += items[indexPath.item].isLiked ? 1 : -1
        collectionView.reloadItems(at: [indexPath])
    }
}

extension ZixyFeedController: ZixyWaterfallLayoutDelegate {

    func collectionView(
        _ collectionView: UICollectionView,
        heightForItemAt indexPath: IndexPath,
        itemWidth: CGFloat
    ) -> CGFloat {
        let item = items[indexPath.item]
        return imageHeight(for: item, itemWidth: itemWidth)
            + titleHeight(for: item, itemWidth: itemWidth)
            + Layout.cardVerticalPadding * 2
            + Layout.cardFooterHeight
    }
}

private final class ZixyFeedCardCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyFeedCardCell"

    var onLikeTapped: (() -> Void)?

    private let craftImageView = UIImageView()
    private let playImageView = UIImageView(
        image: ZixyImageLibrary.feedVideoPlay
    )
    private let titleLabel = UILabel()
    private let likeButton = UIButton(type: .custom)
    private let likeCountLabel = UILabel()
    private var imageHeightConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
        likeButton.addTarget(
            self,
            action: #selector(toggleLike),
            for: .touchUpInside
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onLikeTapped = nil
        craftImageView.image = nil
    }

    func configure(
        imageName: String,
        imageHeight: CGFloat,
        title: String,
        isVideo: Bool,
        likeCount: String,
        isLiked: Bool
    ) {
        craftImageView.image = UIImage(named: imageName)
        imageHeightConstraint?.constant = imageHeight
        titleLabel.text = title
        playImageView.isHidden = !isVideo
        likeCountLabel.text = likeCount
        let image = isLiked
            ? UIImage(systemName: "heart.fill")
            : ZixyImageLibrary.feedHeartOutline
        likeButton.setImage(image, for: .normal)
        likeButton.tintColor = isLiked
            ? UIColor(red: 1, green: 69 / 255, blue: 149 / 255, alpha: 1)
            : UIColor.black.withAlphaComponent(0.78)
        likeButton.accessibilityLabel = isLiked ? "Unlike" : "Like"
        accessibilityLabel = "\(title), \(likeCount) likes"
    }

    private func configureLayout() {
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true

        craftImageView.translatesAutoresizingMaskIntoConstraints = false
        craftImageView.contentMode = .scaleAspectFill
        craftImageView.clipsToBounds = true
        playImageView.translatesAutoresizingMaskIntoConstraints = false
        playImageView.contentMode = .scaleAspectFit
        playImageView.isUserInteractionEnabled = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = ZixyFontBook.bold(size: 17, relativeTo: .headline)
        titleLabel.textColor = UIColor.black.withAlphaComponent(0.78)
        titleLabel.numberOfLines = 0

        likeButton.translatesAutoresizingMaskIntoConstraints = false
        likeButton.accessibilityLabel = "Like"
        likeCountLabel.translatesAutoresizingMaskIntoConstraints = false
        likeCountLabel.font = ZixyFontBook.bold(size: 14, relativeTo: .footnote)
        likeCountLabel.textColor = UIColor.black.withAlphaComponent(0.78)

        contentView.addSubview(craftImageView)
        contentView.addSubview(playImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(likeButton)
        contentView.addSubview(likeCountLabel)

        let imageConstraint = craftImageView.heightAnchor.constraint(
            equalToConstant: 172
        )
        imageHeightConstraint = imageConstraint

        NSLayoutConstraint.activate([
            craftImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            craftImageView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor
            ),
            craftImageView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor
            ),
            imageConstraint,

            playImageView.centerXAnchor.constraint(
                equalTo: craftImageView.centerXAnchor
            ),
            playImageView.centerYAnchor.constraint(
                equalTo: craftImageView.centerYAnchor
            ),
            playImageView.widthAnchor.constraint(equalToConstant: 56),
            playImageView.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.topAnchor.constraint(
                equalTo: craftImageView.bottomAnchor,
                constant: 9
            ),
            titleLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 10
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -10
            ),

            likeButton.trailingAnchor.constraint(
                equalTo: likeCountLabel.leadingAnchor,
                constant: -5
            ),
            likeButton.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -9
            ),
            likeButton.widthAnchor.constraint(equalToConstant: 20),
            likeButton.heightAnchor.constraint(equalToConstant: 20),

            likeCountLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -11
            ),
            likeCountLabel.centerYAnchor.constraint(
                equalTo: likeButton.centerYAnchor
            ),
            titleLabel.bottomAnchor.constraint(
                lessThanOrEqualTo: likeButton.topAnchor,
                constant: -5
            )
        ])
    }

    @objc private func toggleLike() {
        onLikeTapped?()
    }
}
