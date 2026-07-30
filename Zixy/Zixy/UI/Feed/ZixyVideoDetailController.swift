import AVFoundation
import UIKit

final class ZixyVideoDetailController: ZixyScreenController {

    enum Media {
        case image(UIImage?)
        case video(url: URL, poster: UIImage?)
    }

    private struct Comment {
        let email: String
        let avatar: UIImage?
        let author: String
        let date: String
        let text: String
        let isCurrentUser: Bool
        var isLiked: Bool
        var likeCount: Int
    }

    private enum Layout {
        static let floatingButtonSize: CGFloat = 40
        static let composerHeight: CGFloat = 72
        static let panelTop: CGFloat = 165
    }

    private let postID: String
    private let media: Media
    private var post: ZixyPostRecord?
    private var comments: [Comment] = []

    private let mediaView = UIView()
    private let posterImageView = UIImageView()
    private let imagePagingScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.isDirectionalLockEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.accessibilityLabel = "Post images"
        scrollView.isHidden = true
        return scrollView
    }()
    private let imagePageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.hidesForSinglePage = true
        pageControl.isUserInteractionEnabled = false
        pageControl.isHidden = true
        return pageControl
    }()
    private var imagePageViews: [UIImageView] = []
    private let shadeView = ZixyVideoGradientView()
    private let playButton = UIButton(type: .system)
    private let backButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)
    private let detailView = UIView()
    private let compactAuthorView = UIView()
    private let commentPanel = UIView()
    private let composerView = UIView()
    private let commentField = UITextField()
    private let editIconView = UIImageView()
    private let commentButton = UIButton(type: .custom)
    private let commentCountLabel = UILabel()
    private let likeCountLabel = UILabel()
    private let likeButton = UIButton(type: .custom)
    private let playbackTrackView = UIView()
    private let playbackProgressView = UIView()
    private var composerBottomConstraint: NSLayoutConstraint?
    private var playbackProgressWidthConstraint: NSLayoutConstraint?
    private var panelTopConstraint: NSLayoutConstraint?
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playbackTimeObserver: Any?
    private var isPlaying = false
    private var isLiked = false
    private var likeCount = 1_100
    private var areCommentsVisible = false

    private var isCurrentUserContent: Bool {
        guard let post else {
            return false
        }
        return post.author.email.lowercased()
            == ZixySessionStore.currentUserIdentifier.lowercased()
    }

    private lazy var commentsCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
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
            ZixyVideoCommentCell.self,
            forCellWithReuseIdentifier: ZixyVideoCommentCell.reuseIdentifier
        )
        return collectionView
    }()

    init(postID: String, media: Media) {
        self.postID = postID
        self.media = media
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.isHidden = true
        view.backgroundColor = .black
        guard loadPostData() else {
            showToast("Post unavailable.")
            DispatchQueue.main.async { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
            return
        }
        configureMedia()
        configureFloatingButtons()
        configureComposer()
        configureDetail()
        configureCommentPanel()
        configureKeyboard()
        updateLikeAppearance()
    }

    private func loadPostData() -> Bool {
        guard let loadedPost = ZixyDataStore.shared.post(id: postID) else {
            return false
        }
        post = loadedPost
        likeCount = loadedPost.likeCount
        isLiked = loadedPost.isLikedByCurrentUser
        let currentEmail = ZixySessionStore.currentUserIdentifier.lowercased()
        comments = ZixyDataStore.shared.comments(for: postID).map {
            Comment(
                email: $0.author.email,
                avatar: ZixyUserAvatarStore.image(for: $0.author),
                author: $0.author.username,
                date: Self.commentDateFormatter.string(from: $0.createdAt),
                text: $0.body,
                isCurrentUser: $0.author.email.lowercased() == currentEmail,
                isLiked: false,
                likeCount: 0
            )
        }
        return true
    }

    private static let commentDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    private static func postDateText(id: String) -> String {
        guard id.hasPrefix("published_"),
              let milliseconds = Int64(
                  id.split(separator: "_").dropFirst().first ?? ""
              ) else {
            return ""
        }
        return commentDateFormatter.string(
            from: Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = mediaView.bounds
        layoutImagePages()
        updatePlaybackProgress()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pauseVideo()
        view.endEditing(true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent
            || isBeingDismissed
            || navigationController?.isBeingDismissed == true {
            removePlaybackTimeObserver()
        }
    }

    private func configureMedia() {
        [
            mediaView,
            posterImageView,
            imagePagingScrollView,
            imagePageControl,
            shadeView
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        mediaView.backgroundColor = .black
        posterImageView.contentMode = .scaleAspectFill
        posterImageView.clipsToBounds = true
        imagePagingScrollView.delegate = self
        view.addSubview(mediaView)
        mediaView.addSubview(posterImageView)
        mediaView.addSubview(imagePagingScrollView)
        mediaView.addSubview(shadeView)
        mediaView.addSubview(imagePageControl)

        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.setImage(ZixyImageLibrary.feedVideoPlay, for: .normal)
        playButton.imageView?.contentMode = .scaleAspectFit
        playButton.backgroundColor = .clear
        playButton.accessibilityLabel = "Play video"
        playButton.addTarget(self, action: #selector(toggleVideo), for: .touchUpInside)
        mediaView.addSubview(playButton)

        switch media {
        case let .image(image):
            configureImagePages(fallbackImage: image)
            playButton.isHidden = true
        case let .video(_, poster):
            posterImageView.image = poster
            posterImageView.isHidden = false
            imagePagingScrollView.isHidden = true
            imagePageControl.isHidden = true
            playButton.isHidden = false
        }

        NSLayoutConstraint.activate([
            mediaView.topAnchor.constraint(equalTo: view.topAnchor),
            mediaView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mediaView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            posterImageView.topAnchor.constraint(equalTo: mediaView.topAnchor),
            posterImageView.leadingAnchor.constraint(equalTo: mediaView.leadingAnchor),
            posterImageView.trailingAnchor.constraint(equalTo: mediaView.trailingAnchor),
            posterImageView.bottomAnchor.constraint(equalTo: mediaView.bottomAnchor),
            imagePagingScrollView.topAnchor.constraint(equalTo: mediaView.topAnchor),
            imagePagingScrollView.leadingAnchor.constraint(equalTo: mediaView.leadingAnchor),
            imagePagingScrollView.trailingAnchor.constraint(equalTo: mediaView.trailingAnchor),
            imagePagingScrollView.bottomAnchor.constraint(equalTo: mediaView.bottomAnchor),
            shadeView.topAnchor.constraint(equalTo: mediaView.topAnchor),
            shadeView.leadingAnchor.constraint(equalTo: mediaView.leadingAnchor),
            shadeView.trailingAnchor.constraint(equalTo: mediaView.trailingAnchor),
            shadeView.bottomAnchor.constraint(equalTo: mediaView.bottomAnchor),
            imagePageControl.trailingAnchor.constraint(
                equalTo: mediaView.trailingAnchor,
                constant: -16
            ),
            playButton.centerXAnchor.constraint(equalTo: mediaView.centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: mediaView.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 78),
            playButton.heightAnchor.constraint(equalToConstant: 78)
        ])
    }

    private func configureImagePages(fallbackImage: UIImage?) {
        imagePageViews.forEach { $0.removeFromSuperview() }

        var images = post?.mediaNames.compactMap {
            ZixyPostMediaStore.image(reference: $0)
        } ?? []
        if images.isEmpty, let fallbackImage {
            images = [fallbackImage]
        }

        imagePageViews = images.map { image in
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imagePagingScrollView.addSubview(imageView)
            return imageView
        }
        imagePageControl.numberOfPages = imagePageViews.count
        imagePageControl.currentPage = 0
        updateImagePageIndicators()
        posterImageView.isHidden = !imagePageViews.isEmpty
        posterImageView.image = fallbackImage
        imagePagingScrollView.isHidden = imagePageViews.isEmpty
        imagePageControl.isHidden = imagePageViews.count < 2
        view.setNeedsLayout()
    }

    private func layoutImagePages() {
        guard !imagePagingScrollView.isHidden else {
            return
        }
        let pageSize = imagePagingScrollView.bounds.size
        guard pageSize.width > 0, pageSize.height > 0 else {
            return
        }
        imagePageViews.enumerated().forEach { index, imageView in
            imageView.frame = CGRect(
                x: CGFloat(index) * pageSize.width,
                y: 0,
                width: pageSize.width,
                height: pageSize.height
            )
        }
        imagePagingScrollView.contentSize = CGSize(
            width: pageSize.width * CGFloat(imagePageViews.count),
            height: pageSize.height
        )
        if !imagePagingScrollView.isDragging
            && !imagePagingScrollView.isDecelerating {
            imagePagingScrollView.contentOffset.x =
                CGFloat(imagePageControl.currentPage) * pageSize.width
        }
    }

    private func updateImagePageIndicators() {
        for page in 0..<imagePageControl.numberOfPages {
            imagePageControl.setIndicatorImage(
                page == imagePageControl.currentPage
                    ? Self.currentPageIndicatorImage
                    : Self.pageIndicatorImage,
                forPage: page
            )
        }
    }

    private static func makePageIndicatorImage(width: CGFloat) -> UIImage {
        let size = CGSize(width: width, height: 6)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.white.setFill()
            UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: size),
                cornerRadius: 3
            ).fill()
        }.withRenderingMode(.alwaysOriginal)
    }

    private static let pageIndicatorImage = makePageIndicatorImage(width: 6)
    private static let currentPageIndicatorImage = makePageIndicatorImage(width: 18)

    private func configureFloatingButtons() {
        configureFloatingButton(
            backButton,
            imageName: "arrow.left",
            accessibilityLabel: "Back"
        )
        configureFloatingButton(
            moreButton,
            imageName: "equal",
            accessibilityLabel: "More"
        )
        let canUseMore = !isCurrentUserContent
            && ZixySessionStore.allowsSocialInteraction
        moreButton.isHidden = !canUseMore
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        if canUseMore {
            moreButton.addTarget(self, action: #selector(showMore), for: .touchUpInside)
        }
        view.addSubview(backButton)
        view.addSubview(moreButton)
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 6
            ),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.widthAnchor.constraint(equalToConstant: Layout.floatingButtonSize),
            backButton.heightAnchor.constraint(equalToConstant: Layout.floatingButtonSize),
            moreButton.topAnchor.constraint(equalTo: backButton.topAnchor),
            moreButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            moreButton.widthAnchor.constraint(equalToConstant: Layout.floatingButtonSize),
            moreButton.heightAnchor.constraint(equalToConstant: Layout.floatingButtonSize)
        ])
    }

    private func configureFloatingButton(
        _ button: UIButton,
        imageName: String,
        accessibilityLabel: String
    ) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor.white.withAlphaComponent(0.94)
        button.tintColor = .black
        let configuration = UIImage.SymbolConfiguration(
            pointSize: 21,
            weight: .bold
        )
        button.setImage(
            UIImage(systemName: imageName, withConfiguration: configuration),
            for: .normal
        )
        button.layer.cornerRadius = 12
        button.accessibilityLabel = accessibilityLabel
    }

    private func configureDetail() {
        detailView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(detailView)

        let authorRow = makeAuthorRow(compact: false)
        let titleLabel = makeLabel(
            text: post?.title ?? "",
            size: 16,
            color: .white,
            lines: 1
        )
        let descriptionLabel = makeLabel(
            text: post?.body ?? "",
            size: 12,
            color: UIColor.white.withAlphaComponent(0.76),
            lines: 0
        )
        [authorRow, titleLabel, descriptionLabel].forEach(detailView.addSubview)
        NSLayoutConstraint.activate([
            detailView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            detailView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            detailView.bottomAnchor.constraint(
                equalTo: composerView.topAnchor,
                constant: -13
            ),
            imagePageControl.bottomAnchor.constraint(
                equalTo: authorRow.topAnchor,
                constant: -24
            ),
            authorRow.topAnchor.constraint(equalTo: detailView.topAnchor),
            authorRow.leadingAnchor.constraint(equalTo: detailView.leadingAnchor),
            authorRow.trailingAnchor.constraint(equalTo: detailView.trailingAnchor),
            authorRow.heightAnchor.constraint(equalToConstant: 38),
            titleLabel.topAnchor.constraint(equalTo: authorRow.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: detailView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: detailView.trailingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            descriptionLabel.leadingAnchor.constraint(equalTo: detailView.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: detailView.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: detailView.bottomAnchor)
        ])
    }

    private func configureCommentPanel() {
        commentPanel.translatesAutoresizingMaskIntoConstraints = false
        commentPanel.backgroundColor = .white
        commentPanel.layer.cornerRadius = 24
        commentPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        commentPanel.clipsToBounds = true
        commentPanel.isHidden = true
        view.addSubview(commentPanel)

        compactAuthorView.translatesAutoresizingMaskIntoConstraints = false
        compactAuthorView.isHidden = true
        compactAuthorView.addSubview(makeAuthorRow(compact: true))
        view.addSubview(compactAuthorView)
        if let authorRow = compactAuthorView.subviews.first {
            authorRow.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                authorRow.topAnchor.constraint(equalTo: compactAuthorView.topAnchor),
                authorRow.leadingAnchor.constraint(equalTo: compactAuthorView.leadingAnchor),
                authorRow.trailingAnchor.constraint(equalTo: compactAuthorView.trailingAnchor),
                authorRow.bottomAnchor.constraint(equalTo: compactAuthorView.bottomAnchor)
            ])
        }

        let titleLabel = makeLabel(
            text: post?.title ?? "",
            size: 22,
            color: UIColor.black.withAlphaComponent(0.82),
            lines: 2
        )
        let descriptionLabel = makeLabel(
            text: post?.body ?? "",
            size: 15,
            color: UIColor.black.withAlphaComponent(0.56),
            lines: 0
        )
        let dateLabel = makeLabel(
            text: post.map { Self.postDateText(id: $0.id) } ?? "",
            size: 11,
            color: UIColor.black.withAlphaComponent(0.38),
            lines: 1
        )
        let sectionIcon = UIImageView(image: ZixyImageLibrary.videoCommentBadge)
        sectionIcon.translatesAutoresizingMaskIntoConstraints = false
        let sectionLabel = makeLabel(
            text: "Comment",
            size: 17,
            color: UIColor.black.withAlphaComponent(0.78),
            lines: 1
        )
        [titleLabel, descriptionLabel, dateLabel, sectionIcon, sectionLabel,
         commentsCollectionView].forEach(commentPanel.addSubview)

        panelTopConstraint = commentPanel.topAnchor.constraint(
            equalTo: view.topAnchor,
            constant: Layout.panelTop
        )
        NSLayoutConstraint.activate([
            panelTopConstraint!,
            commentPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            commentPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            commentPanel.bottomAnchor.constraint(equalTo: composerView.topAnchor),
            compactAuthorView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 76
            ),
            compactAuthorView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 18
            ),
            compactAuthorView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -18
            ),
            compactAuthorView.heightAnchor.constraint(equalToConstant: 36),
            titleLabel.topAnchor.constraint(equalTo: commentPanel.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: commentPanel.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: commentPanel.trailingAnchor, constant: -20),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            dateLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 3),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            sectionIcon.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 14),
            sectionIcon.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            sectionIcon.widthAnchor.constraint(equalToConstant: 20),
            sectionIcon.heightAnchor.constraint(equalToConstant: 20),
            sectionLabel.centerYAnchor.constraint(equalTo: sectionIcon.centerYAnchor),
            sectionLabel.leadingAnchor.constraint(equalTo: sectionIcon.trailingAnchor, constant: 7),
            commentsCollectionView.topAnchor.constraint(equalTo: sectionIcon.bottomAnchor, constant: 4),
            commentsCollectionView.leadingAnchor.constraint(equalTo: commentPanel.leadingAnchor),
            commentsCollectionView.trailingAnchor.constraint(equalTo: commentPanel.trailingAnchor),
            commentsCollectionView.bottomAnchor.constraint(equalTo: commentPanel.bottomAnchor)
        ])
    }

    private func configureComposer() {
        composerView.translatesAutoresizingMaskIntoConstraints = false
        composerView.backgroundColor = UIColor.black.withAlphaComponent(0.88)
        view.addSubview(composerView)

        playbackTrackView.translatesAutoresizingMaskIntoConstraints = false
        playbackTrackView.backgroundColor = UIColor.white.withAlphaComponent(0.48)
        playbackProgressView.translatesAutoresizingMaskIntoConstraints = false
        playbackProgressView.backgroundColor = UIColor(
            red: 26 / 255,
            green: 86 / 255,
            blue: 1,
            alpha: 1
        )

        editIconView.translatesAutoresizingMaskIntoConstraints = false
        editIconView.image = ZixyImageLibrary.videoEdit?.withRenderingMode(.alwaysTemplate)
        editIconView.tintColor = .white
        editIconView.contentMode = .scaleAspectFit

        commentField.translatesAutoresizingMaskIntoConstraints = false
        commentField.borderStyle = .none
        commentField.textColor = .white
        commentField.tintColor = .white
        commentField.font = ZixyFontBook.bold(size: 14, relativeTo: .body)
        commentField.attributedPlaceholder = NSAttributedString(
            string: "Say something...",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.62)]
        )
        commentField.returnKeyType = .send
        commentField.delegate = self
        commentField.accessibilityLabel = "Comment"

        commentButton.translatesAutoresizingMaskIntoConstraints = false
        commentButton.setImage(
            ZixyImageLibrary.videoComment?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        commentButton.tintColor = .white
        commentButton.addTarget(self, action: #selector(showComments), for: .touchUpInside)
        commentCountLabel.translatesAutoresizingMaskIntoConstraints = false
        styleMetricLabel(
            commentCountLabel,
            text: formattedCount(post?.commentCount ?? 0)
        )
        likeButton.translatesAutoresizingMaskIntoConstraints = false
        likeButton.addTarget(self, action: #selector(toggleLike), for: .touchUpInside)
        likeCountLabel.translatesAutoresizingMaskIntoConstraints = false
        styleMetricLabel(likeCountLabel, text: formattedCount(likeCount))

        [playbackTrackView, playbackProgressView, editIconView, commentField,
         commentButton, commentCountLabel, likeButton,
         likeCountLabel].forEach(composerView.addSubview)
        composerBottomConstraint = composerView.bottomAnchor.constraint(
            equalTo: view.bottomAnchor
        )
        playbackProgressWidthConstraint = playbackProgressView.widthAnchor.constraint(
            equalToConstant: 0
        )
        NSLayoutConstraint.activate([
            composerBottomConstraint!,
            composerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composerView.heightAnchor.constraint(equalToConstant: Layout.composerHeight),
            playbackTrackView.topAnchor.constraint(equalTo: composerView.topAnchor),
            playbackTrackView.leadingAnchor.constraint(equalTo: composerView.leadingAnchor),
            playbackTrackView.trailingAnchor.constraint(equalTo: composerView.trailingAnchor),
            playbackTrackView.heightAnchor.constraint(equalToConstant: 1),
            playbackProgressView.topAnchor.constraint(equalTo: composerView.topAnchor),
            playbackProgressView.leadingAnchor.constraint(equalTo: composerView.leadingAnchor),
            playbackProgressWidthConstraint!,
            playbackProgressView.heightAnchor.constraint(equalToConstant: 2),
            editIconView.leadingAnchor.constraint(equalTo: composerView.leadingAnchor, constant: 16),
            editIconView.centerYAnchor.constraint(equalTo: composerView.centerYAnchor, constant: -5),
            editIconView.widthAnchor.constraint(equalToConstant: 22),
            editIconView.heightAnchor.constraint(equalToConstant: 22),
            commentField.leadingAnchor.constraint(equalTo: editIconView.trailingAnchor, constant: 2),
            commentField.centerYAnchor.constraint(equalTo: editIconView.centerYAnchor),
            commentField.heightAnchor.constraint(equalToConstant: 40),
            commentButton.leadingAnchor.constraint(
                equalTo: commentField.trailingAnchor,
                constant: 8
            ),
            commentButton.centerYAnchor.constraint(
                equalTo: composerView.centerYAnchor,
                constant: -7
            ),
            commentButton.widthAnchor.constraint(equalToConstant: 28),
            commentButton.heightAnchor.constraint(equalToConstant: 28),
            commentCountLabel.centerXAnchor.constraint(
                equalTo: commentButton.centerXAnchor
            ),
            commentCountLabel.topAnchor.constraint(
                equalTo: commentButton.bottomAnchor,
                constant: -3
            ),
            likeButton.leadingAnchor.constraint(
                equalTo: commentButton.trailingAnchor,
                constant: 17
            ),
            likeButton.centerYAnchor.constraint(equalTo: commentButton.centerYAnchor),
            likeButton.widthAnchor.constraint(equalToConstant: 28),
            likeButton.heightAnchor.constraint(equalToConstant: 28),
            likeButton.trailingAnchor.constraint(
                equalTo: composerView.trailingAnchor,
                constant: -19
            ),
            likeCountLabel.centerXAnchor.constraint(
                equalTo: likeButton.centerXAnchor
            ),
            likeCountLabel.topAnchor.constraint(
                equalTo: likeButton.bottomAnchor,
                constant: -3
            )
        ])
    }

    private func makeMetricButton(image: UIImage?, action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(image, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func styleMetricLabel(_ label: UILabel, text: String) {
        label.text = text
        label.font = ZixyFontBook.bold(size: 10, relativeTo: .caption2)
        label.textColor = .white
        label.textAlignment = .center
    }

    private func makeAuthorRow(compact: Bool) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        let avatar = UIImageView(
            image: post.flatMap { ZixyUserAvatarStore.image(for: $0.author) }
        )
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 17
        avatar.isUserInteractionEnabled = true
        avatar.accessibilityTraits = .button
        avatar.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(openPostAuthorProfile)
            )
        )
        let label = makeLabel(
            text: post?.author.username ?? "",
            size: compact ? 16 : 17,
            color: .white,
            lines: 1
        )
        row.addSubview(avatar)
        row.addSubview(label)
        let diameter: CGFloat = 34
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            avatar.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: diameter),
            avatar.heightAnchor.constraint(equalToConstant: diameter),
            label.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 9),
            label.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor)
        ])
        return row
    }

    @objc private func openPostAuthorProfile() {
        guard let email = post?.author.email else {
            return
        }
        pushZixyOtherProfile(userEmail: email)
    }

    private func makeLabel(
        text: String,
        size: CGFloat,
        color: UIColor,
        lines: Int
    ) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = ZixyFontBook.bold(size: size)
        label.textColor = color
        label.numberOfLines = lines
        return label
    }

    private func configureKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleBackgroundTap(_:))
        )
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    private func configurePlayerIfNeeded() {
        guard player == nil, case let .video(url, _) = media else {
            return
        }
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .pause
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = mediaView.bounds
        mediaView.layer.insertSublayer(layer, above: posterImageView.layer)
        self.player = player
        playerLayer = layer
        playbackTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            self?.updatePlaybackProgress()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(videoDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
    }

    private func updatePlaybackProgress() {
        guard
            let player,
            let duration = player.currentItem?.duration.seconds,
            duration.isFinite,
            duration > 0
        else {
            playbackProgressWidthConstraint?.constant = 0
            return
        }
        let currentTime = player.currentTime().seconds
        let fraction = min(max(currentTime / duration, 0), 1)
        playbackProgressWidthConstraint?.constant =
            composerView.bounds.width * fraction
    }

    private func removePlaybackTimeObserver() {
        guard let playbackTimeObserver, let player else {
            return
        }
        player.removeTimeObserver(playbackTimeObserver)
        self.playbackTimeObserver = nil
    }

    private func pauseVideo() {
        player?.pause()
        isPlaying = false
        if case .video = media {
            playButton.isHidden = false
            playButton.accessibilityLabel = "Play video"
        }
    }

    private func setCommentsVisible(_ visible: Bool) {
        guard commentPanel.isHidden == visible else {
            return
        }
        if visible {
            pauseVideo()
            commentPanel.alpha = 0
            commentPanel.transform = CGAffineTransform(translationX: 0, y: 80)
            commentPanel.isHidden = false
            compactAuthorView.isHidden = false
        }
        areCommentsVisible = visible
        detailView.isHidden = visible
        composerView.backgroundColor = visible ? .white : UIColor.black.withAlphaComponent(0.88)
        let composerForeground = visible
            ? UIColor.black.withAlphaComponent(0.78)
            : UIColor.white
        editIconView.tintColor = composerForeground
        commentButton.tintColor = composerForeground
        playbackProgressView.isHidden = visible
        playbackTrackView.backgroundColor = visible
            ? UIColor.black.withAlphaComponent(0.18)
            : UIColor.white.withAlphaComponent(0.48)
        commentField.textColor = visible ? UIColor.black.withAlphaComponent(0.78) : .white
        commentField.tintColor = visible ? .systemBlue : .white
        commentField.attributedPlaceholder = NSAttributedString(
            string: "Say something...",
            attributes: [
                .foregroundColor: visible
                    ? UIColor.black.withAlphaComponent(0.38)
                    : UIColor.white.withAlphaComponent(0.62)
            ]
        )
        [commentCountLabel, likeCountLabel].forEach {
            $0.textColor = visible ? UIColor.black.withAlphaComponent(0.58) : .white
        }
        updateLikeAppearance()
        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            self.commentPanel.alpha = visible ? 1 : 0
            self.commentPanel.transform = visible ? .identity
                : CGAffineTransform(translationX: 0, y: 80)
        } completion: { _ in
            if !visible {
                self.commentPanel.isHidden = true
                self.compactAuthorView.isHidden = true
            }
        }
    }

    private func updateLikeAppearance() {
        let image = isLiked
            ? UIImage(systemName: "heart.fill")
            : ZixyImageLibrary.videoLikeOutline?.withRenderingMode(.alwaysTemplate)
        likeButton.setImage(image, for: .normal)
        likeButton.tintColor = isLiked
            ? .systemPink
            : (areCommentsVisible
                ? UIColor.black.withAlphaComponent(0.78)
                : .white)
        likeCountLabel.text = formattedCount(likeCount)
        likeButton.accessibilityLabel = isLiked ? "Unlike" : "Like"
    }

    private func formattedCount(_ count: Int) -> String {
        count >= 1_000
            ? String(format: "%.1fK", Double(count) / 1_000)
            : "\(count)"
    }

    @objc private func toggleVideo() {
        configurePlayerIfNeeded()
        guard let player else {
            return
        }
        if isPlaying {
            pauseVideo()
        } else {
            player.play()
            isPlaying = true
            playButton.isHidden = true
            playButton.accessibilityLabel = "Pause video"
        }
    }

    @objc private func videoDidFinish() {
        pauseVideo()
        player?.seek(to: .zero) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePlaybackProgress()
            }
        }
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func showMore() {
        guard
            ZixySessionStore.allowsSocialInteraction,
            !isCurrentUserContent
        else {
            return
        }
        let targetName = post?.author.username ?? "User"
        let controller = ZixyMoreActionsController(targetName: targetName)
        controller.onFollowed = { [weak self] in
            guard let self else {
                return
            }
            guard
                ZixySessionStore.allowsSocialInteraction,
                !self.isCurrentUserContent,
                let followedEmail = self.post?.author.email
            else {
                self.showToast("Unable to follow \(targetName).")
                return
            }
            do {
                try ZixyDataStore.shared.setFollowing(
                    true,
                    followedEmail: followedEmail,
                    followerEmail: ZixySessionStore.currentUserIdentifier
                )
                self.showToast("Followed \(targetName).")
            } catch {
                self.showToast("Unable to follow \(targetName).")
            }
        }
        controller.onReport = { [weak self] in
            guard let self, !self.isCurrentUserContent else {
                return
            }
            let reportController = ZixyReportController(
                reportedUserName: targetName,
                isCurrentUser: false
            )
            self.push(reportController)
        }
        controller.onBlock = { [weak self] in
            guard
                let self,
                ZixySessionStore.allowsSocialInteraction,
                !self.isCurrentUserContent,
                let blockedEmail = self.post?.author.email
            else {
                return
            }
            do {
                try ZixyDataStore.shared.setBlocked(
                    true,
                    blockedEmail: blockedEmail,
                    blockerEmail: ZixySessionStore.currentUserIdentifier
                )
                NotificationCenter.default.post(
                    name: .zixyBlacklistDidChange,
                    object: blockedEmail
                )
                if let navigationController = self.navigationController,
                   navigationController.viewControllers.count > 1 {
                    let previousController = navigationController.viewControllers[
                        navigationController.viewControllers.count - 2
                    ]
                    navigationController.popViewController(animated: true)
                    previousController.showToast("\(targetName) was blocked.")
                } else {
                    self.dismiss(animated: true)
                }
            } catch {
                self.showToast("Unable to update the blacklist.")
            }
        }
        present(controller, animated: true)
    }

    @objc private func showComments() {
        setCommentsVisible(true)
    }

    @objc private func toggleLike() {
        guard ZixySessionStore.allowsSocialInteraction else {
            showToast("Sign in to like posts.")
            return
        }
        guard let updatedPost = try? ZixyDataStore.shared.setPostLiked(
            !isLiked,
            postID: postID
        ) else {
            showToast("Unable to update the post.")
            return
        }
        post = updatedPost
        isLiked = updatedPost.isLikedByCurrentUser
        likeCount = updatedPost.likeCount
        updateLikeAppearance()
    }

    @objc private func handleBackgroundTap(
        _ gestureRecognizer: UITapGestureRecognizer
    ) {
        view.endEditing(true)
        guard areCommentsVisible else {
            return
        }
        let location = gestureRecognizer.location(in: view)
        let protectedFrames = [
            commentPanel.frame,
            composerView.frame,
            backButton.frame,
            moreButton.frame
        ]
        guard !protectedFrames.contains(where: { $0.contains(location) }) else {
            return
        }
        setCommentsVisible(false)
    }

    @objc private func keyboardWillChange(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
            let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
            let curveValue = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else {
            return
        }
        let convertedFrame = view.convert(frame, from: nil)
        let overlap = max(0, view.bounds.maxY - convertedFrame.minY)
        composerBottomConstraint?.constant = -overlap
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curveValue << 16)
        ) {
            self.view.layoutIfNeeded()
        }
    }
}

extension ZixyVideoDetailController:
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard
            scrollView === imagePagingScrollView,
            scrollView.bounds.width > 0,
            !imagePageViews.isEmpty
        else {
            return
        }
        let page = Int(
            round(scrollView.contentOffset.x / scrollView.bounds.width)
        )
        let currentPage = min(max(page, 0), imagePageViews.count - 1)
        guard imagePageControl.currentPage != currentPage else {
            return
        }
        imagePageControl.currentPage = currentPage
        updateImagePageIndicators()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        comments.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ZixyVideoCommentCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyVideoCommentCell else {
            return UICollectionViewCell()
        }
        let comment = comments[indexPath.item]
        cell.configure(
            avatar: comment.avatar,
            author: comment.author,
            date: comment.date,
            text: comment.text,
            isCurrentUser: comment.isCurrentUser,
            isLiked: comment.isLiked,
            likeCount: comment.likeCount
        )
        cell.onLike = { [weak self, weak collectionView] in
            guard let self else {
                return
            }
            guard ZixySessionStore.allowsSocialInteraction else {
                showToast("Sign in to like comments.")
                return
            }
            guard comments.indices.contains(indexPath.item) else {
                return
            }
            comments[indexPath.item].isLiked.toggle()
            comments[indexPath.item].likeCount += comments[indexPath.item].isLiked ? 1 : -1
            collectionView?.reloadItems(at: [indexPath])
        }
        cell.onAvatarTapped = { [weak self] in
            self?.pushZixyOtherProfile(userEmail: comment.email)
        }
        cell.onReport = { [weak self] in
            guard
                let self,
                ZixySessionStore.allowsSocialInteraction,
                !comment.isCurrentUser
            else {
                return
            }
            let reportController = ZixyReportController(
                reportedUserName: comment.author,
                isCurrentUser: false
            )
            self.push(reportController)
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(
            width: collectionView.bounds.width,
            height: ZixyVideoCommentCell.preferredHeight(
                text: comments[indexPath.item].text,
                width: collectionView.bounds.width
            )
        )
    }
}

extension ZixyVideoDetailController: UITextFieldDelegate {

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        guard ZixySessionStore.allowsSocialInteraction else {
            showToast("Sign in to comment.")
            return false
        }
        setCommentsVisible(true)
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard ZixySessionStore.allowsSocialInteraction else {
            showToast("Sign in to comment.")
            textField.resignFirstResponder()
            return false
        }
        let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            showToast("Enter a comment first.")
            return false
        }
        guard let savedComment = try? ZixyDataStore.shared.addComment(
            to: postID,
            body: text
        ) else {
            showToast("Unable to add the comment.")
            return false
        }
        comments.insert(
            Comment(
                email: savedComment.author.email,
                avatar: ZixyUserAvatarStore.image(for: savedComment.author),
                author: savedComment.author.username,
                date: Self.commentDateFormatter.string(
                    from: savedComment.createdAt
                ),
                text: savedComment.body,
                isCurrentUser: true,
                isLiked: false,
                likeCount: 0
            ),
            at: 0
        )
        post = ZixyDataStore.shared.post(id: postID)
        commentCountLabel.text = formattedCount(post?.commentCount ?? comments.count)
        textField.text = nil
        textField.resignFirstResponder()
        commentsCollectionView.reloadData()
        commentsCollectionView.setContentOffset(.zero, animated: true)
        return true
    }
}

extension ZixyVideoDetailController: UIGestureRecognizerDelegate {

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard let touchedView = touch.view else {
            return true
        }
        return !touchedView.isDescendant(of: commentField)
    }
}

private final class ZixyVideoGradientView: UIView {

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        guard let gradient = layer as? CAGradientLayer else {
            return
        }
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.08).cgColor,
            UIColor.black.withAlphaComponent(0.82).cgColor
        ]
        gradient.locations = [0, 0.52, 1]
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class ZixyVideoCommentCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyVideoCommentCell"
    private static let horizontalBodyInset: CGFloat = 88
    private static let bottomSpacing: CGFloat = 16

    var onLike: (() -> Void)?
    var onReport: (() -> Void)?
    var onAvatarTapped: (() -> Void)?

    private let avatarView = UIImageView()
    private let authorLabel = UILabel()
    private let dateLabel = UILabel()
    private let bodyLabel = UILabel()
    private let likeButton = UIButton(type: .custom)
    private let likeLabel = UILabel()
    private let reportButton = UIButton(type: .custom)

    static func preferredHeight(text: String, width: CGFloat) -> CGFloat {
        let bodyFont = ZixyFontBook.bold(size: 12)
        let bodyWidth = max(1, width - horizontalBodyInset)
        let bodyHeight = ceil(
            (text as NSString).boundingRect(
                with: CGSize(
                    width: bodyWidth,
                    height: .greatestFiniteMagnitude
                ),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: bodyFont],
                context: nil
            ).height
        )
        let fixedHeight: CGFloat = 11
            + ZixyFontBook.bold(size: 17).lineHeight
            - 1
            + ZixyFontBook.bold(size: 10).lineHeight
            + 7
            + 3
            + 18
            + bottomSpacing
        return ceil(fixedHeight + bodyHeight)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onLike = nil
        onReport = nil
        onAvatarTapped = nil
    }

    func configure(
        avatar: UIImage?,
        author: String,
        date: String,
        text: String,
        isCurrentUser: Bool,
        isLiked: Bool,
        likeCount: Int
    ) {
        avatarView.image = avatar
        authorLabel.text = author
        dateLabel.text = date
        bodyLabel.text = text
        likeButton.setImage(
            ZixyImageLibrary.videoLikeOutline?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        likeButton.setImage(
            ZixyImageLibrary.videoLikeFilled?.withRenderingMode(.alwaysTemplate),
            for: .selected
        )
        likeButton.isSelected = isLiked
        likeButton.tintColor = isLiked ? .systemPink : UIColor.black.withAlphaComponent(0.62)
        likeLabel.text = likeCount >= 1_000
            ? String(format: "%.1fK", Double(likeCount) / 1_000)
            : "\(likeCount)"
        reportButton.isHidden = isCurrentUser
    }

    private func configureLayout() {
        [avatarView, authorLabel, dateLabel, bodyLabel, likeButton,
         likeLabel, reportButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 19
        avatarView.isUserInteractionEnabled = true
        avatarView.accessibilityTraits = .button
        avatarView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(avatarTapped)
            )
        )
        authorLabel.font = ZixyFontBook.bold(size: 17)
        authorLabel.textColor = UIColor.black.withAlphaComponent(0.78)
        dateLabel.font = ZixyFontBook.bold(size: 10)
        dateLabel.textColor = UIColor.black.withAlphaComponent(0.34)
        bodyLabel.font = ZixyFontBook.bold(size: 12)
        bodyLabel.textColor = UIColor.black.withAlphaComponent(0.62)
        bodyLabel.numberOfLines = 0
        likeLabel.font = ZixyFontBook.bold(size: 12)
        likeLabel.textColor = UIColor.black.withAlphaComponent(0.42)
        likeLabel.textAlignment = .center
        likeButton.addTarget(self, action: #selector(likeTapped), for: .touchUpInside)
        reportButton.setImage(ZixyImageLibrary.videoReport, for: .normal)
        reportButton.accessibilityLabel = "Report comment"
        reportButton.addTarget(self, action: #selector(reportTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            avatarView.widthAnchor.constraint(equalToConstant: 38),
            avatarView.heightAnchor.constraint(equalToConstant: 38),
            authorLabel.topAnchor.constraint(equalTo: avatarView.topAnchor, constant: -1),
            authorLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            authorLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: reportButton.leadingAnchor,
                constant: -8
            ),
            dateLabel.leadingAnchor.constraint(equalTo: authorLabel.leadingAnchor),
            dateLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: -1),
            bodyLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 7),
            bodyLabel.leadingAnchor.constraint(equalTo: authorLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -20
            ),
            likeButton.leadingAnchor.constraint(equalTo: bodyLabel.leadingAnchor),
            likeButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 3),
            likeButton.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -Self.bottomSpacing
            ),
            likeButton.widthAnchor.constraint(equalToConstant: 18),
            likeButton.heightAnchor.constraint(equalToConstant: 18),
            likeLabel.leadingAnchor.constraint(equalTo: likeButton.trailingAnchor, constant: 3),
            likeLabel.centerYAnchor.constraint(equalTo: likeButton.centerYAnchor),
            reportButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            reportButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            reportButton.widthAnchor.constraint(equalToConstant: 20),
            reportButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    @objc private func likeTapped() {
        onLike?()
    }

    @objc private func avatarTapped() {
        onAvatarTapped?()
    }

    @objc private func reportTapped() {
        onReport?()
    }
}
