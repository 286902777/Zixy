import PhotosUI
import UIKit

final class ZixyConversationController: UIViewController {

    private enum Layout {
        static let contentTop: CGFloat = 166
        static let horizontalInset: CGFloat = 17
        static let actionSpacing: CGFloat = 14
        static let actionHeight: CGFloat = 34
        static let composerHeight: CGFloat = 50
        static let keyboardSpacing: CGFloat = 12
    }

    private enum MessageKind {
        case timestamp
        case text
        case image
    }

    private struct Message {
        let kind: MessageKind
        let text: String?
        let image: UIImage?
        let isOutgoing: Bool
    }

    private let participantName: String
    private let participantImage: UIImage?
    private let isCurrentUser: Bool
    private let participantEmail: String?
    private var messages: [Message] = []

    private var inputBottomConstraint: NSLayoutConstraint?
    private var keyboardObservers: [NSObjectProtocol] = []

    private var currentUserAvatar: UIImage? {
        guard let user = ZixyDataStore.shared.currentUser() else {
            return ZixyImageLibrary.homeRoomPortrait
        }
        return ZixyUserAvatarStore.image(for: user)
            ?? ZixyImageLibrary.homeRoomPortrait
    }

    private let backgroundView = ZixyImageLibrary.makePageBackgroundView()
    private let contentPanel: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.cornerRadius = 24
        view.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner
        ]
        view.clipsToBounds = true
        return view
    }()
    private let avatarView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 30
        return view
    }()
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ZixyFontBook.bold(size: 20, relativeTo: .headline)
        label.textColor = UIColor.black.withAlphaComponent(0.78)
        label.textAlignment = .center
        return label
    }()
    private let backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(ZixyImageLibrary.authBackButton, for: .normal)
        button.accessibilityLabel = "Back"
        return button
    }()
    private let moreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .black
        button.layer.cornerRadius = 11
        button.setImage(ZixyImageLibrary.chatMoreIcon, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.accessibilityLabel = "More"
        return button
    }()
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 12, left: 0, bottom: 8, right: 0)
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.delegate = self
        view.register(
            ZixyConversationTimeCell.self,
            forCellWithReuseIdentifier: ZixyConversationTimeCell.reuseIdentifier
        )
        view.register(
            ZixyConversationTextCell.self,
            forCellWithReuseIdentifier: ZixyConversationTextCell.reuseIdentifier
        )
        view.register(
            ZixyConversationImageCell.self,
            forCellWithReuseIdentifier: ZixyConversationImageCell.reuseIdentifier
        )
        return view
    }()
    private let photoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(
            ZixyImageLibrary.chatPhotoAction?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        button.imageView?.contentMode = .scaleAspectFit
        button.accessibilityLabel = "Choose photo"
        return button
    }()
    private let videoCallButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(
            ZixyImageLibrary.chatVideoCallAction?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        button.imageView?.contentMode = .scaleAspectFit
        button.accessibilityLabel = "Start video call"
        return button
    }()
    private let inputContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(
            red: 247 / 255,
            green: 250 / 255,
            blue: 251 / 255,
            alpha: 1
        )
        view.layer.cornerRadius = 26
        return view
    }()
    private let messageField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "Enter..."
        field.font = ZixyFontBook.bold(size: 14, relativeTo: .body)
        field.textColor = UIColor.black.withAlphaComponent(0.8)
        field.returnKeyType = .send
        return field
    }()
    private let sendButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(ZixyImageLibrary.chatSendIcon, for: .normal)
        button.accessibilityLabel = "Send message"
        return button
    }()

    init(
        participantName: String,
        participantImage: UIImage?,
        isCurrentUser: Bool,
        participantEmail: String? = nil
    ) {
        self.participantName = participantName
        self.participantImage = participantImage
        self.isCurrentUser = isCurrentUser
        self.participantEmail = participantEmail
            ?? ZixyDataStore.shared.user(username: participantName)?.email
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPersistedMessages()
        configureLayout()
        configureInteractions()
        observeKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        collectionView.layoutIfNeeded()
        scrollToLatestMessage(animated: false)
    }

    deinit {
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
    }

    private func configureLayout() {
        view.backgroundColor = ZixyColorPalette.pageBackground
        avatarView.image = participantImage
        nameLabel.text = participantName

        view.addSubview(backgroundView)
        view.addSubview(contentPanel)
        view.addSubview(backButton)
        view.addSubview(avatarView)
        view.addSubview(nameLabel)
        view.addSubview(moreButton)
        contentPanel.addSubview(collectionView)
        contentPanel.addSubview(photoButton)
        contentPanel.addSubview(videoCallButton)
        contentPanel.addSubview(inputContainer)
        inputContainer.addSubview(messageField)
        inputContainer.addSubview(sendButton)

        let inputBottom = inputContainer.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: 0
        )
        inputBottomConstraint = inputBottom

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentPanel.topAnchor.constraint(
                equalTo: view.topAnchor,
                constant: Layout.contentTop
            ),
            contentPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 16
            ),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),

            avatarView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 7
            ),
            avatarView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 60),
            avatarView.heightAnchor.constraint(equalToConstant: 60),

            nameLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 8),
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nameLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: backButton.trailingAnchor,
                constant: 10
            ),
            nameLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: moreButton.leadingAnchor,
                constant: -10
            ),

            moreButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -19
            ),
            moreButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 16
            ),
            moreButton.widthAnchor.constraint(equalToConstant: 40),
            moreButton.heightAnchor.constraint(equalToConstant: 40),

            collectionView.topAnchor.constraint(
                equalTo: contentPanel.topAnchor,
                constant: 10
            ),
            collectionView.leadingAnchor.constraint(equalTo: contentPanel.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentPanel.trailingAnchor),
            collectionView.bottomAnchor.constraint(
                equalTo: photoButton.topAnchor,
                constant: -8
            ),

            photoButton.leadingAnchor.constraint(
                equalTo: contentPanel.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            photoButton.bottomAnchor.constraint(
                equalTo: inputContainer.topAnchor,
                constant: -10
            ),
            photoButton.heightAnchor.constraint(equalToConstant: Layout.actionHeight),

            videoCallButton.leadingAnchor.constraint(
                equalTo: photoButton.trailingAnchor,
                constant: Layout.actionSpacing
            ),
            videoCallButton.trailingAnchor.constraint(
                equalTo: contentPanel.trailingAnchor,
                constant: -16
            ),
            videoCallButton.centerYAnchor.constraint(equalTo: photoButton.centerYAnchor),
            videoCallButton.widthAnchor.constraint(equalTo: photoButton.widthAnchor),
            videoCallButton.heightAnchor.constraint(equalTo: photoButton.heightAnchor),

            inputContainer.leadingAnchor.constraint(
                equalTo: contentPanel.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            inputContainer.trailingAnchor.constraint(
                equalTo: contentPanel.trailingAnchor,
                constant: -16
            ),
            inputContainer.heightAnchor.constraint(
                equalToConstant: Layout.composerHeight
            ),
            inputBottom,

            messageField.leadingAnchor.constraint(
                equalTo: inputContainer.leadingAnchor,
                constant: 26
            ),
            messageField.trailingAnchor.constraint(
                equalTo: sendButton.leadingAnchor,
                constant: -10
            ),
            messageField.topAnchor.constraint(equalTo: inputContainer.topAnchor),
            messageField.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor),

            sendButton.trailingAnchor.constraint(
                equalTo: inputContainer.trailingAnchor,
                constant: -15
            ),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 34),
            sendButton.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func configureInteractions() {
        backButton.addTarget(
            self,
            action: #selector(navigateBack),
            for: .touchUpInside
        )
        photoButton.addTarget(
            self,
            action: #selector(selectPhoto),
            for: .touchUpInside
        )
        videoCallButton.addTarget(
            self,
            action: #selector(startVideoCall),
            for: .touchUpInside
        )
        sendButton.addTarget(
            self,
            action: #selector(sendMessage),
            for: .touchUpInside
        )
        messageField.delegate = self
        avatarView.isUserInteractionEnabled = true
        avatarView.accessibilityTraits = .button
        avatarView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(openParticipantProfile)
            )
        )

        if isCurrentUser || !ZixySessionStore.allowsSocialInteraction {
            moreButton.isHidden = true
        } else {
            moreButton.addTarget(
                self,
                action: #selector(showMoreActions),
                for: .touchUpInside
            )
        }

        let gesture = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        gesture.cancelsTouchesInView = false
        view.addGestureRecognizer(gesture)
    }

    private func observeKeyboard() {
        let center = NotificationCenter.default
        keyboardObservers = [
            center.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.updateForKeyboard(notification)
            },
            center.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.updateForKeyboard(notification)
            }
        ]
    }

    private func updateForKeyboard(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let frame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return
        }

        let keyboardFrame = view.convert(frame, from: nil)
        let safeBottom = view.safeAreaLayoutGuide.layoutFrame.maxY
        let overlap = max(0, safeBottom - keyboardFrame.minY)
        inputBottomConstraint?.constant = overlap > 0
            ? -(overlap + Layout.keyboardSpacing)
            : 0

        let duration = userInfo[
            UIResponder.keyboardAnimationDurationUserInfoKey
        ] as? TimeInterval ?? 0.25
        let curve = userInfo[
            UIResponder.keyboardAnimationCurveUserInfoKey
        ] as? UInt ?? 7
        let options = UIView.AnimationOptions(rawValue: curve << 16)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [options, .beginFromCurrentState],
            animations: {
                self.view.layoutIfNeeded()
                self.scrollToLatestMessage(animated: false)
            }
        )
    }

    private func scrollToLatestMessage(animated: Bool) {
        guard !messages.isEmpty else {
            return
        }
        collectionView.scrollToItem(
            at: IndexPath(item: messages.count - 1, section: 0),
            at: .bottom,
            animated: animated
        )
    }

    private func loadPersistedMessages() {
        guard let participantEmail else {
            return
        }
        let currentEmail = ZixySessionStore.currentUserIdentifier
        let records = ZixyDataStore.shared.messages(
            between: currentEmail,
            and: participantEmail
        )
        guard !records.isEmpty else {
            return
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        messages = [
            Message(
                kind: .timestamp,
                text: formatter.string(from: records[0].createdAt),
                image: nil,
                isOutgoing: false
            )
        ]
        messages.append(
            contentsOf: records.map {
                Message(
                    kind: .text,
                    text: $0.body,
                    image: nil,
                    isOutgoing: $0.senderEmail == currentEmail
                )
            }
        )
    }

    @objc private func navigateBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func showMoreActions() {
        guard
            ZixySessionStore.allowsSocialInteraction,
            !isCurrentUser
        else {
            return
        }

        let isFollowing = participantEmail.map {
            ZixyDataStore.shared.isFollowing(
                $0,
                from: ZixySessionStore.currentUserIdentifier
            )
        } ?? false
        let controller = ZixyMoreActionsController(
            targetName: participantName,
            isFollowing: isFollowing
        )
        controller.onFollowed = { [weak self] in
            guard let self else {
                return
            }
            guard
                ZixySessionStore.allowsSocialInteraction,
                !self.isCurrentUser,
                let participantEmail = self.participantEmail
            else {
                self.showToast("Unable to follow \(self.participantName).")
                return
            }
            do {
                try ZixyDataStore.shared.setFollowing(
                    true,
                    followedEmail: participantEmail,
                    followerEmail: ZixySessionStore.currentUserIdentifier
                )
                self.showToast("Followed \(self.participantName).")
            } catch {
                self.showToast("Unable to follow \(self.participantName).")
            }
        }
        controller.onReport = { [weak self] in
            guard let self, !self.isCurrentUser else {
                return
            }
            let reportController = ZixyReportController(
                reportedUserName: self.participantName,
                isCurrentUser: self.isCurrentUser
            )
            reportController.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(
                reportController,
                animated: true
            )
        }
        controller.onBlock = { [weak self] in
            guard
                let self,
                ZixySessionStore.allowsSocialInteraction,
                !self.isCurrentUser
            else {
                return
            }
            do {
                if let participantEmail = self.participantEmail {
                    try ZixyDataStore.shared.setBlocked(
                        true,
                        blockedEmail: participantEmail,
                        blockerEmail: ZixySessionStore.currentUserIdentifier
                    )
                } else {
                    try ZixyDataStore.shared.setBlocked(
                        true,
                        blockedUsername: self.participantName,
                        blockerEmail: ZixySessionStore.currentUserIdentifier
                    )
                }
                self.showToast("\(self.participantName) has been blocked.")
            } catch {
                self.showToast("Unable to update the blacklist.")
            }
        }
        present(controller, animated: false)
    }

    @objc private func openParticipantProfile() {
        guard let participantEmail else {
            return
        }
        pushZixyOtherProfile(userEmail: participantEmail)
    }

    @objc private func selectPhoto() {
        view.endEditing(true)
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func startVideoCall() {
        view.endEditing(true)
        let controller = ZixyVideoCallController(
            participantName: participantName,
            participantEmail: participantEmail,
            participantImage: participantImage
        )
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc private func sendMessage() {
        let text = messageField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            showToast("Enter a message first.")
            return
        }
        if let participantEmail {
            do {
                try ZixyDataStore.shared.addMessage(
                    body: text,
                    senderEmail: ZixySessionStore.currentUserIdentifier,
                    recipientEmail: participantEmail
                )
            } catch {
                showToast("Unable to send the message.")
                return
            }
        }
        messages.append(
            Message(kind: .text, text: text, image: nil, isOutgoing: true)
        )
        messageField.text = nil
        collectionView.reloadData()
        scrollToLatestMessage(animated: true)
    }
}

extension ZixyConversationController:
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        messages.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let message = messages[indexPath.item]
        switch message.kind {
        case .timestamp:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ZixyConversationTimeCell.reuseIdentifier,
                for: indexPath
            ) as? ZixyConversationTimeCell
            cell?.configure(text: message.text ?? "")
            return cell ?? UICollectionViewCell()
        case .text:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ZixyConversationTextCell.reuseIdentifier,
                for: indexPath
            ) as? ZixyConversationTextCell
            cell?.configure(
                text: message.text ?? "",
                avatar: message.isOutgoing
                    ? currentUserAvatar
                    : participantImage,
                isOutgoing: message.isOutgoing
            )
            cell?.onAvatarTapped = { [weak self] in
                self?.openProfileForMessage(isOutgoing: message.isOutgoing)
            }
            return cell ?? UICollectionViewCell()
        case .image:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ZixyConversationImageCell.reuseIdentifier,
                for: indexPath
            ) as? ZixyConversationImageCell
            cell?.configure(
                image: message.image,
                avatar: message.isOutgoing
                    ? currentUserAvatar
                    : participantImage,
                isOutgoing: message.isOutgoing
            )
            cell?.onAvatarTapped = { [weak self] in
                self?.openProfileForMessage(isOutgoing: message.isOutgoing)
            }
            return cell ?? UICollectionViewCell()
        }
    }

    private func openProfileForMessage(isOutgoing: Bool) {
        guard !isOutgoing else {
            return
        }
        openParticipantProfile()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let message = messages[indexPath.item]
        switch message.kind {
        case .timestamp:
            return CGSize(width: collectionView.bounds.width, height: 34)
        case .text:
            let text = message.text ?? ""
            let bounds = (text as NSString).boundingRect(
                with: CGSize(
                    width: 180,
                    height: CGFloat.greatestFiniteMagnitude
                ),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [
                    .font: ZixyFontBook.bold(size: 16, relativeTo: .body)
                ],
                context: nil
            )
            return CGSize(
                width: collectionView.bounds.width,
                height: max(56, ceil(bounds.height) + 28) + 8
            )
        case .image:
            return CGSize(width: collectionView.bounds.width, height: 188)
        }
    }
}

extension ZixyConversationController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        sendMessage()
        return true
    }
}

extension ZixyConversationController: PHPickerViewControllerDelegate {

    func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        picker.dismiss(animated: true)
        guard
            let provider = results.first?.itemProvider,
            provider.canLoadObject(ofClass: UIImage.self)
        else {
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                guard let image = object as? UIImage else {
                    self.showToast("Unable to load the selected photo.")
                    return
                }
                self.messages.append(
                    Message(
                        kind: .image,
                        text: nil,
                        image: image,
                        isOutgoing: true
                    )
                )
                self.collectionView.reloadData()
                self.scrollToLatestMessage(animated: true)
            }
        }
    }
}

private final class ZixyConversationTimeCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyConversationTimeCell"
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ZixyFontBook.bold(size: 16, relativeTo: .subheadline)
        label.textColor = .systemGray3
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(text: String) {
        label.text = text
    }
}

private final class ZixyConversationTextCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyConversationTextCell"
    var onAvatarTapped: (() -> Void)?
    private let avatarView = UIImageView()
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private var directionalConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        [avatarView, bubbleView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 22
        avatarView.isUserInteractionEnabled = true
        avatarView.accessibilityTraits = .button
        avatarView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        )
        bubbleView.backgroundColor = UIColor(
            red: 244 / 255,
            green: 246 / 255,
            blue: 247 / 255,
            alpha: 1
        )
        bubbleView.layer.cornerRadius = 13
        messageLabel.font = ZixyFontBook.bold(size: 16, relativeTo: .body)
        messageLabel.textColor = UIColor.black.withAlphaComponent(0.78)
        messageLabel.numberOfLines = 0

        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            avatarView.widthAnchor.constraint(equalToConstant: 44),
            avatarView.heightAnchor.constraint(equalToConstant: 44),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(
                lessThanOrEqualTo: contentView.bottomAnchor,
                constant: -4
            ),
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: 14
            ),
            messageLabel.trailingAnchor.constraint(
                equalTo: bubbleView.trailingAnchor,
                constant: -14
            ),
            messageLabel.bottomAnchor.constraint(
                equalTo: bubbleView.bottomAnchor,
                constant: -10
            ),
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 180)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        NSLayoutConstraint.deactivate(directionalConstraints)
        directionalConstraints.removeAll()
        onAvatarTapped = nil
    }

    func configure(text: String, avatar: UIImage?, isOutgoing: Bool) {
        messageLabel.text = text
        avatarView.image = avatar
        NSLayoutConstraint.deactivate(directionalConstraints)
        directionalConstraints = isOutgoing
            ? [
                avatarView.trailingAnchor.constraint(
                    equalTo: contentView.trailingAnchor,
                    constant: -16
                ),
                bubbleView.trailingAnchor.constraint(
                    equalTo: avatarView.leadingAnchor,
                    constant: -10
                )
            ]
            : [
                avatarView.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: 16
                ),
                bubbleView.leadingAnchor.constraint(
                    equalTo: avatarView.trailingAnchor,
                    constant: 10
                )
            ]
        NSLayoutConstraint.activate(directionalConstraints)
    }

    @objc private func avatarTapped() {
        onAvatarTapped?()
    }
}

private final class ZixyConversationImageCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyConversationImageCell"
    var onAvatarTapped: (() -> Void)?
    private let avatarView = UIImageView()
    private let messageImageView = UIImageView()
    private var directionalConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        [avatarView, messageImageView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.contentMode = .scaleAspectFill
            $0.clipsToBounds = true
            contentView.addSubview($0)
        }
        avatarView.layer.cornerRadius = 22
        avatarView.isUserInteractionEnabled = true
        avatarView.accessibilityTraits = .button
        avatarView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        )
        messageImageView.layer.cornerRadius = 8
        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            avatarView.widthAnchor.constraint(equalToConstant: 44),
            avatarView.heightAnchor.constraint(equalToConstant: 44),
            messageImageView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 4
            ),
            messageImageView.widthAnchor.constraint(equalToConstant: 118),
            messageImageView.heightAnchor.constraint(equalToConstant: 178)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        NSLayoutConstraint.deactivate(directionalConstraints)
        directionalConstraints.removeAll()
        onAvatarTapped = nil
    }

    func configure(image: UIImage?, avatar: UIImage?, isOutgoing: Bool) {
        messageImageView.image = image
        avatarView.image = avatar
        NSLayoutConstraint.deactivate(directionalConstraints)
        directionalConstraints = isOutgoing
            ? [
                avatarView.trailingAnchor.constraint(
                    equalTo: contentView.trailingAnchor,
                    constant: -16
                ),
                messageImageView.trailingAnchor.constraint(
                    equalTo: avatarView.leadingAnchor,
                    constant: -10
                )
            ]
            : [
                avatarView.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: 16
                ),
                messageImageView.leadingAnchor.constraint(
                    equalTo: avatarView.trailingAnchor,
                    constant: 10
                )
            ]
        NSLayoutConstraint.activate(directionalConstraints)
    }

    @objc private func avatarTapped() {
        onAvatarTapped?()
    }
}
