import AVFoundation
import UIKit

final class ZixyVideoDetailController: ZixyScreenController {

    enum Media {
        case image(UIImage?)
        case video(url: URL, poster: UIImage?)
    }

    private struct Comment {
        let avatar: UIImage?
        let author: String
        let date: String
        let text: String
        let isCurrentUser: Bool
        var isLiked: Bool
        var likeCount: Int
    }

    private enum Layout {
        static let floatingButtonSize: CGFloat = 42
        static let composerHeight: CGFloat = 72
        static let panelTop: CGFloat = 165
        static let commentCellHeight: CGFloat = 154
    }

    private let media: Media
    private let isCurrentUserContent: Bool
    private var comments = [
        Comment(
            avatar: ZixyImageLibrary.userAvatar,
            author: "Elena",
            date: "04-13",
            text: "This is amazing. The details make the whole piece feel alive.",
            isCurrentUser: false,
            isLiked: false,
            likeCount: 88
        ),
        Comment(
            avatar: ZixyImageLibrary.chatParticipantAvatar,
            author: "Mia",
            date: "04-13",
            text: "I would love to see more of the carving process.",
            isCurrentUser: false,
            isLiked: false,
            likeCount: 32
        )
    ]

    private let mediaView = UIView()
    private let posterImageView = UIImageView()
    private let shadeView = ZixyVideoGradientView()
    private let playButton = UIButton(type: .system)
    private let backButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)
    private let detailView = UIView()
    private let compactAuthorView = UIView()
    private let commentPanel = UIView()
    private let composerView = UIView()
    private let commentField = UITextField()
    private let commentCountLabel = UILabel()
    private let likeCountLabel = UILabel()
    private let likeButton = UIButton(type: .custom)
    private var composerBottomConstraint: NSLayoutConstraint?
    private var panelTopConstraint: NSLayoutConstraint?
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var isPlaying = false
    private var isLiked = false
    private var likeCount = 1_100

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

    init(media: Media, isCurrentUserContent: Bool = false) {
        self.media = media
        self.isCurrentUserContent = isCurrentUserContent
        super.init(nibName: nil, bundle: nil)
    }

    convenience init(image: UIImage?) {
        self.init(media: .image(image))
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.isHidden = true
        view.backgroundColor = .black
        configureMedia()
        configureFloatingButtons()
        configureComposer()
        configureDetail()
        configureCommentPanel()
        configureKeyboard()
        updateLikeAppearance()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = mediaView.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pauseVideo()
        view.endEditing(true)
    }

    private func configureMedia() {
        [mediaView, posterImageView, shadeView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        mediaView.backgroundColor = .black
        posterImageView.contentMode = .scaleAspectFill
        posterImageView.clipsToBounds = true
        view.addSubview(mediaView)
        mediaView.addSubview(posterImageView)
        mediaView.addSubview(shadeView)

        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.tintColor = .white
        playButton.setImage(
            UIImage(systemName: "play.fill")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 34)),
            for: .normal
        )
        playButton.backgroundColor = UIColor.black.withAlphaComponent(0.24)
        playButton.layer.cornerRadius = 34
        playButton.accessibilityLabel = "Play video"
        playButton.addTarget(self, action: #selector(toggleVideo), for: .touchUpInside)
        mediaView.addSubview(playButton)

        switch media {
        case let .image(image):
            posterImageView.image = image
            playButton.isHidden = true
        case let .video(_, poster):
            posterImageView.image = poster
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
            shadeView.topAnchor.constraint(equalTo: mediaView.topAnchor),
            shadeView.leadingAnchor.constraint(equalTo: mediaView.leadingAnchor),
            shadeView.trailingAnchor.constraint(equalTo: mediaView.trailingAnchor),
            shadeView.bottomAnchor.constraint(equalTo: mediaView.bottomAnchor),
            playButton.centerXAnchor.constraint(equalTo: mediaView.centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: mediaView.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 68),
            playButton.heightAnchor.constraint(equalToConstant: 68)
        ])
    }

    private func configureFloatingButtons() {
        configureFloatingButton(
            backButton,
            imageName: "chevron.left",
            accessibilityLabel: "Back"
        )
        configureFloatingButton(
            moreButton,
            imageName: "ellipsis",
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
                constant: 8
            ),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            backButton.widthAnchor.constraint(equalToConstant: Layout.floatingButtonSize),
            backButton.heightAnchor.constraint(equalToConstant: Layout.floatingButtonSize),
            moreButton.topAnchor.constraint(equalTo: backButton.topAnchor),
            moreButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
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
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.layer.cornerRadius = 13
        button.accessibilityLabel = accessibilityLabel
    }

    private func configureDetail() {
        detailView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(detailView)

        let authorRow = makeAuthorRow(compact: false)
        let titleLabel = makeLabel(
            text: "'News?' asked the taller of the two.",
            size: 20,
            color: .white,
            lines: 2
        )
        let descriptionLabel = makeLabel(
            text: "A quiet moment in the studio, shaping every line by hand.",
            size: 13,
            color: UIColor.white.withAlphaComponent(0.76),
            lines: 2
        )
        [authorRow, titleLabel, descriptionLabel].forEach(detailView.addSubview)
        NSLayoutConstraint.activate([
            detailView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            detailView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            detailView.bottomAnchor.constraint(
                equalTo: composerView.topAnchor,
                constant: -16
            ),
            authorRow.topAnchor.constraint(equalTo: detailView.topAnchor),
            authorRow.leadingAnchor.constraint(equalTo: detailView.leadingAnchor),
            authorRow.trailingAnchor.constraint(equalTo: detailView.trailingAnchor),
            authorRow.heightAnchor.constraint(equalToConstant: 46),
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
            text: "'News?' asked the taller of the two.",
            size: 18,
            color: UIColor.black.withAlphaComponent(0.82),
            lines: 2
        )
        let descriptionLabel = makeLabel(
            text: "A quiet moment in the studio, shaping every line by hand.",
            size: 12,
            color: UIColor.black.withAlphaComponent(0.56),
            lines: 2
        )
        let dateLabel = makeLabel(
            text: "04-13",
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
                constant: 68
            ),
            compactAuthorView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 18
            ),
            compactAuthorView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -18
            ),
            compactAuthorView.heightAnchor.constraint(equalToConstant: 44),
            titleLabel.topAnchor.constraint(equalTo: commentPanel.topAnchor, constant: 25),
            titleLabel.leadingAnchor.constraint(equalTo: commentPanel.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: commentPanel.trailingAnchor, constant: -20),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            dateLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 7),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            sectionIcon.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 18),
            sectionIcon.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            sectionIcon.widthAnchor.constraint(equalToConstant: 20),
            sectionIcon.heightAnchor.constraint(equalToConstant: 20),
            sectionLabel.centerYAnchor.constraint(equalTo: sectionIcon.centerYAnchor),
            sectionLabel.leadingAnchor.constraint(equalTo: sectionIcon.trailingAnchor, constant: 7),
            commentsCollectionView.topAnchor.constraint(equalTo: sectionIcon.bottomAnchor, constant: 7),
            commentsCollectionView.leadingAnchor.constraint(equalTo: commentPanel.leadingAnchor),
            commentsCollectionView.trailingAnchor.constraint(equalTo: commentPanel.trailingAnchor),
            commentsCollectionView.bottomAnchor.constraint(equalTo: commentPanel.bottomAnchor)
        ])
    }

    private func configureComposer() {
        composerView.translatesAutoresizingMaskIntoConstraints = false
        composerView.backgroundColor = UIColor.black.withAlphaComponent(0.88)
        view.addSubview(composerView)

        let editIcon = UIImageView(image: ZixyImageLibrary.videoEdit)
        editIcon.translatesAutoresizingMaskIntoConstraints = false
        editIcon.contentMode = .scaleAspectFit

        commentField.translatesAutoresizingMaskIntoConstraints = false
        commentField.borderStyle = .none
        commentField.textColor = .white
        commentField.tintColor = .white
        commentField.font = ZixyFontBook.bold(size: 14, relativeTo: .body)
        commentField.attributedPlaceholder = NSAttributedString(
            string: "Say something...",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.62)]
        )
        commentField.returnKeyType = .done
        commentField.delegate = self
        commentField.accessibilityLabel = "Comment"

        let commentButton = makeMetricButton(
            image: ZixyImageLibrary.videoComment,
            action: #selector(showComments)
        )
        commentCountLabel.translatesAutoresizingMaskIntoConstraints = false
        styleMetricLabel(commentCountLabel, text: "999")
        likeButton.translatesAutoresizingMaskIntoConstraints = false
        likeButton.addTarget(self, action: #selector(toggleLike), for: .touchUpInside)
        likeCountLabel.translatesAutoresizingMaskIntoConstraints = false
        styleMetricLabel(likeCountLabel, text: "1.1K")

        [editIcon, commentField, commentButton, commentCountLabel,
         likeButton, likeCountLabel].forEach(composerView.addSubview)
        composerBottomConstraint = composerView.bottomAnchor.constraint(
            equalTo: view.bottomAnchor
        )
        NSLayoutConstraint.activate([
            composerBottomConstraint!,
            composerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composerView.heightAnchor.constraint(equalToConstant: Layout.composerHeight),
            editIcon.leadingAnchor.constraint(equalTo: composerView.leadingAnchor, constant: 18),
            editIcon.centerYAnchor.constraint(equalTo: composerView.centerYAnchor, constant: -7),
            editIcon.widthAnchor.constraint(equalToConstant: 22),
            editIcon.heightAnchor.constraint(equalToConstant: 22),
            commentField.leadingAnchor.constraint(equalTo: editIcon.trailingAnchor, constant: 8),
            commentField.centerYAnchor.constraint(equalTo: editIcon.centerYAnchor),
            commentField.heightAnchor.constraint(equalToConstant: 40),
            commentButton.leadingAnchor.constraint(equalTo: commentField.trailingAnchor, constant: 8),
            commentButton.centerYAnchor.constraint(equalTo: editIcon.centerYAnchor),
            commentButton.widthAnchor.constraint(equalToConstant: 28),
            commentButton.heightAnchor.constraint(equalToConstant: 28),
            commentCountLabel.centerXAnchor.constraint(equalTo: commentButton.centerXAnchor),
            commentCountLabel.topAnchor.constraint(equalTo: commentButton.bottomAnchor, constant: -3),
            likeButton.leadingAnchor.constraint(equalTo: commentButton.trailingAnchor, constant: 17),
            likeButton.centerYAnchor.constraint(equalTo: commentButton.centerYAnchor),
            likeButton.widthAnchor.constraint(equalToConstant: 28),
            likeButton.heightAnchor.constraint(equalToConstant: 28),
            likeButton.trailingAnchor.constraint(equalTo: composerView.trailingAnchor, constant: -19),
            likeCountLabel.centerXAnchor.constraint(equalTo: likeButton.centerXAnchor),
            likeCountLabel.topAnchor.constraint(equalTo: likeButton.bottomAnchor, constant: -3)
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
        let avatar = UIImageView(image: ZixyImageLibrary.profileAvatar)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = compact ? 18 : 21
        let label = makeLabel(
            text: "Katrina✨Ray",
            size: compact ? 15 : 17,
            color: .white,
            lines: 1
        )
        row.addSubview(avatar)
        row.addSubview(label)
        let diameter: CGFloat = compact ? 36 : 42
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
        let tap = UITapGestureRecognizer(target: self, action: #selector(endEditing))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    private func configurePlayerIfNeeded() {
        guard player == nil, case let .video(url, _) = media else {
            return
        }
        let player = AVPlayer(url: url)
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = mediaView.bounds
        mediaView.layer.insertSublayer(layer, above: posterImageView.layer)
        self.player = player
        playerLayer = layer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(videoDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
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
        detailView.isHidden = visible
        composerView.backgroundColor = visible ? .white : UIColor.black.withAlphaComponent(0.88)
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
            : ZixyImageLibrary.videoLikeOutline
        likeButton.setImage(image, for: .normal)
        likeButton.tintColor = isLiked ? .systemPink : .white
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
        player?.seek(to: .zero)
        pauseVideo()
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
        let controller = ZixyMoreActionsController(targetName: "Katrina✨Ray")
        controller.onReport = { [weak self] in
            guard let self, !self.isCurrentUserContent else {
                return
            }
            self.showToast("Post reported.")
        }
        controller.onBlock = { [weak self] in
            guard let self, !self.isCurrentUserContent else {
                return
            }
            self.showToast("Katrina✨Ray was blocked.")
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
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        updateLikeAppearance()
    }

    @objc private func endEditing() {
        view.endEditing(true)
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
        cell.onReport = { [weak self] in
            guard
                let self,
                ZixySessionStore.allowsSocialInteraction,
                !comment.isCurrentUser
            else {
                return
            }
            showToast("Report options are available for this comment.")
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
            height: Layout.commentCellHeight
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
        comments.insert(
            Comment(
                avatar: ZixyImageLibrary.profileAvatar,
                author: "Katrina✨Ray",
                date: "Just now",
                text: text,
                isCurrentUser: true,
                isLiked: false,
                likeCount: 0
            ),
            at: 0
        )
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

    var onLike: (() -> Void)?
    var onReport: (() -> Void)?

    private let avatarView = UIImageView()
    private let authorLabel = UILabel()
    private let dateLabel = UILabel()
    private let bodyLabel = UILabel()
    private let likeButton = UIButton(type: .custom)
    private let likeLabel = UILabel()
    private let reportButton = UIButton(type: .custom)

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
            isLiked ? UIImage(systemName: "heart.fill")
                : ZixyImageLibrary.videoLikeOutline,
            for: .normal
        )
        likeButton.tintColor = isLiked ? .systemPink : UIColor.black.withAlphaComponent(0.62)
        likeLabel.text = "\(likeCount)"
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
        avatarView.layer.cornerRadius = 21
        authorLabel.font = ZixyFontBook.bold(size: 15)
        authorLabel.textColor = UIColor.black.withAlphaComponent(0.78)
        dateLabel.font = ZixyFontBook.bold(size: 10)
        dateLabel.textColor = UIColor.black.withAlphaComponent(0.34)
        bodyLabel.font = ZixyFontBook.bold(size: 13)
        bodyLabel.textColor = UIColor.black.withAlphaComponent(0.62)
        bodyLabel.numberOfLines = 3
        likeLabel.font = ZixyFontBook.bold(size: 10)
        likeLabel.textColor = UIColor.black.withAlphaComponent(0.42)
        likeLabel.textAlignment = .center
        likeButton.addTarget(self, action: #selector(likeTapped), for: .touchUpInside)
        reportButton.setImage(ZixyImageLibrary.videoReport, for: .normal)
        reportButton.accessibilityLabel = "Report comment"
        reportButton.addTarget(self, action: #selector(reportTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 13),
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            avatarView.widthAnchor.constraint(equalToConstant: 42),
            avatarView.heightAnchor.constraint(equalToConstant: 42),
            authorLabel.topAnchor.constraint(equalTo: avatarView.topAnchor, constant: 1),
            authorLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            dateLabel.leadingAnchor.constraint(equalTo: authorLabel.leadingAnchor),
            dateLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 1),
            bodyLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 8),
            bodyLabel.leadingAnchor.constraint(equalTo: avatarView.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: likeButton.leadingAnchor, constant: -16),
            likeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            likeButton.centerYAnchor.constraint(equalTo: bodyLabel.centerYAnchor, constant: -5),
            likeButton.widthAnchor.constraint(equalToConstant: 24),
            likeButton.heightAnchor.constraint(equalToConstant: 24),
            likeLabel.centerXAnchor.constraint(equalTo: likeButton.centerXAnchor),
            likeLabel.topAnchor.constraint(equalTo: likeButton.bottomAnchor, constant: -1),
            reportButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            reportButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            reportButton.widthAnchor.constraint(equalToConstant: 24),
            reportButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    @objc private func likeTapped() {
        onLike?()
    }

    @objc private func reportTapped() {
        onReport?()
    }
}
