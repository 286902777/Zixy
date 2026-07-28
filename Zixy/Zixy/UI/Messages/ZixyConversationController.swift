import PhotosUI
import UIKit

final class ZixyConversationController: UIViewController {

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
    private var messages = [
        Message(
            kind: .timestamp,
            text: "PM 01:20",
            image: nil,
            isOutgoing: false
        ),
        Message(
            kind: .text,
            text: "Hello! Is there anything I can do to assist you?",
            image: nil,
            isOutgoing: false
        ),
        Message(
            kind: .text,
            text: "How should one dress for a trip?",
            image: nil,
            isOutgoing: true
        ),
        Message(
            kind: .image,
            text: nil,
            image: ZixyImageLibrary.profileAvatar,
            isOutgoing: false
        )
    ]

    private var inputBottomConstraint: NSLayoutConstraint?
    private var keyboardObservers: [NSObjectProtocol] = []

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
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Photo"
        configuration.image = UIImage(systemName: "photo.fill")
        configuration.imagePadding = 9
        configuration.baseForegroundColor = UIColor(
            red: 82 / 255,
            green: 126 / 255,
            blue: 1,
            alpha: 1
        )
        configuration.titleTextAttributesTransformer =
            UIConfigurationTextAttributesTransformer { attributes in
                var resolved = attributes
                resolved.font = ZixyFontBook.bold(size: 14, relativeTo: .body)
                return resolved
            }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor(
            red: 246 / 255,
            green: 247 / 255,
            blue: 249 / 255,
            alpha: 1
        )
        button.layer.cornerRadius = 11
        button.contentHorizontalAlignment = .leading
        button.accessibilityLabel = "Choose photo"
        let arrow = UIImageView(image: UIImage(systemName: "arrow.right"))
        arrow.translatesAutoresizingMaskIntoConstraints = false
        arrow.tintColor = configuration.baseForegroundColor
        button.addSubview(arrow)
        NSLayoutConstraint.activate([
            arrow.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -10),
            arrow.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 19),
            arrow.heightAnchor.constraint(equalToConstant: 16)
        ])
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
        field.returnKeyType = .done
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
        isCurrentUser: Bool
    ) {
        self.participantName = participantName
        self.participantImage = participantImage
        self.isCurrentUser = isCurrentUser
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
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
        contentPanel.addSubview(inputContainer)
        inputContainer.addSubview(messageField)
        inputContainer.addSubview(sendButton)

        let inputBottom = inputContainer.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: -22
        )
        inputBottomConstraint = inputBottom

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentPanel.topAnchor.constraint(equalTo: view.topAnchor, constant: 166),
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

            photoButton.centerXAnchor.constraint(equalTo: contentPanel.centerXAnchor),
            photoButton.bottomAnchor.constraint(
                equalTo: inputContainer.topAnchor,
                constant: -10
            ),
            photoButton.widthAnchor.constraint(equalToConstant: 164),
            photoButton.heightAnchor.constraint(equalToConstant: 36),

            inputContainer.leadingAnchor.constraint(
                equalTo: contentPanel.leadingAnchor,
                constant: 17
            ),
            inputContainer.trailingAnchor.constraint(
                equalTo: contentPanel.trailingAnchor,
                constant: -16
            ),
            inputContainer.heightAnchor.constraint(equalToConstant: 52),
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
        sendButton.addTarget(
            self,
            action: #selector(sendMessage),
            for: .touchUpInside
        )
        messageField.delegate = self

        if isCurrentUser {
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
        inputBottomConstraint?.constant = -(overlap + (overlap > 0 ? 12 : 22))

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

    @objc private func navigateBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func showMoreActions() {
        guard !isCurrentUser else {
            return
        }
        showToast("More actions are available for this user.")
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

    @objc private func sendMessage() {
        let text = messageField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            showToast("Enter a message first.")
            return
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
                    ? participantImage
                    : ZixyImageLibrary.profileAvatar,
                isOutgoing: message.isOutgoing
            )
            return cell ?? UICollectionViewCell()
        case .image:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ZixyConversationImageCell.reuseIdentifier,
                for: indexPath
            ) as? ZixyConversationImageCell
            cell?.configure(
                image: message.image,
                avatar: message.isOutgoing
                    ? participantImage
                    : ZixyImageLibrary.profileAvatar,
                isOutgoing: message.isOutgoing
            )
            return cell ?? UICollectionViewCell()
        }
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
}

private final class ZixyConversationImageCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyConversationImageCell"
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
}
