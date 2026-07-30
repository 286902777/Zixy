import AVFoundation
import UIKit

final class ZixyRoomDetailController: ZixyScreenController {

    enum Mode {
        case conversation
        case store
    }

    private struct Seat {
        let email: String?
        let name: String
        let image: UIImage?
        let isEmpty: Bool
    }

    private struct Gift {
        let name: String
        let image: UIImage?
        let price: Int
    }

    private struct Message {
        enum Content {
            case text(String)
            case voice(url: URL, duration: TimeInterval)
            case gift(name: String)
        }

        let id = UUID()
        let content: Content
        let isCurrentUser: Bool
    }

    private let roomID: String
    private let roomTitle: String
    private var hostName: String
    private let hostEmail: String?
    private let hostIsCurrentUser: Bool
    private var mode: Mode
    private var isMicrophoneMuted = false
    private var keyboardObservers: [NSObjectProtocol] = []
    private var inputBottomConstraint: NSLayoutConstraint?
    private var messages: [Message] = []
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var recordingURL: URL?
    private var playingMessageID: UUID?
    private var isLongPressHeld = false

    private var seats: [Seat]
    private var profileObserver: NSObjectProtocol?

    private let gifts: [Gift] = [
        Gift(name: "GRAVER", image: ZixyImageLibrary.roomGiftGraver, price: 800),
        Gift(name: "INK PAD", image: ZixyImageLibrary.roomGiftInkPad, price: 800),
        Gift(name: "CARVING", image: ZixyImageLibrary.roomGiftCarving, price: 800),
        Gift(name: "TOOLKIT", image: ZixyImageLibrary.roomGiftToolkit, price: 800),
        Gift(name: "BRUSH", image: ZixyImageLibrary.roomGiftBrush, price: 800),
        Gift(name: "WORKBENCH", image: ZixyImageLibrary.roomGiftWorkbench, price: 800),
        Gift(name: "HANDSAW", image: ZixyImageLibrary.roomGiftHandsaw, price: 800),
        Gift(name: "RULER", image: ZixyImageLibrary.roomGiftRuler, price: 800)
    ]

    private let roomBackgroundView: UIImageView = {
        let imageView = UIImageView(image: ZixyImageLibrary.roomBackground)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private let moreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(ZixyImageLibrary.roomMoreButton, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.accessibilityLabel = "More"
        return button
    }()

    private let hostImageView: UIImageView = {
        let imageView = UIImageView(image: ZixyImageLibrary.homeRoomPortrait)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 43
        return imageView
    }()

    private let hostNameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ZixyFontBook.bold(size: 21, relativeTo: .title3)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private lazy var seatCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 12
        layout.sectionInset = .zero

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            ZixyRoomSeatCell.self,
            forCellWithReuseIdentifier: ZixyRoomSeatCell.reuseIdentifier
        )
        return collectionView
    }()

    private lazy var messageTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.keyboardDismissMode = .interactive
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 10, right: 0)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 86
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            ZixyRoomMessageCell.self,
            forCellReuseIdentifier: ZixyRoomMessageCell.reuseIdentifier
        )
        return tableView
    }()

    private let inputContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.cornerRadius = 29
        return view
    }()

    private let giftButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(ZixyImageLibrary.roomGift, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.accessibilityLabel = "Open gift store"
        return button
    }()

    private let messageField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "Enter..."
        field.font = ZixyFontBook.bold(size: 18, relativeTo: .body)
        field.textColor = ZixyColorPalette.ink
        field.returnKeyType = .send
        field.clearButtonMode = .whileEditing
        return field
    }()

    private let sendButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(ZixyImageLibrary.roomSend, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.accessibilityLabel = "Send message"
        return button
    }()

    private let microphoneButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(ZixyImageLibrary.roomMicrophoneActive, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.accessibilityLabel = "Mute microphone"
        return button
    }()

    private let recordingStatusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Release to send"
        label.font = ZixyFontBook.bold(size: 13, relativeTo: .footnote)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.56)
        label.layer.cornerRadius = 14
        label.clipsToBounds = true
        label.alpha = 0
        label.isHidden = true
        label.accessibilityLabel = "Recording voice message. Release to send."
        return label
    }()

    private let storePanel: UIImageView = {
        let imageView = UIImageView(image: ZixyImageLibrary.roomStorePanel)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleToFill
        imageView.isUserInteractionEnabled = true
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 30
        imageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return imageView
    }()

    private let storeEyebrowLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Homage to the"
        label.font = ZixyFontBook.bold(size: 22, relativeTo: .title3)
        label.textColor = UIColor(red: 0.75, green: 0.76, blue: 1, alpha: 1)
        label.transform = CGAffineTransform(rotationAngle: -0.035)
        return label
    }()

    private let storeTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Master"
        label.font = ZixyFontBook.bold(size: 24, relativeTo: .title2)
        label.textColor = UIColor(red: 0.75, green: 0.76, blue: 1, alpha: 1)
        label.transform = CGAffineTransform(rotationAngle: -0.035)
        return label
    }()

    private lazy var giftCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 8
        layout.sectionInset = .zero

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            ZixyRoomGiftCell.self,
            forCellWithReuseIdentifier: ZixyRoomGiftCell.reuseIdentifier
        )
        return collectionView
    }()

    private let balanceImageView: UIImageView = {
        let imageView = UIImageView(image: ZixyImageLibrary.roomCoinStack)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let balanceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "8000"
        label.font = ZixyFontBook.bold(size: 28, relativeTo: .title2)
        label.textColor = UIColor(red: 1, green: 0.72, blue: 0.53, alpha: 1)
        return label
    }()

    private let rechargeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor(red: 1, green: 0.72, blue: 0.53, alpha: 1)
        button.layer.cornerRadius = 18
        button.setTitle("Recharge", for: .normal)
        button.setTitleColor(
            UIColor(red: 0.2, green: 0.17, blue: 0.18, alpha: 1),
            for: .normal
        )
        button.titleLabel?.font = ZixyFontBook.bold(size: 16, relativeTo: .headline)
        return button
    }()

    init(
        roomID: String? = nil,
        roomTitle: String = "Here is the room...",
        hostName: String = "Katrina✨Ray",
        hostEmail: String? = nil,
        mode: Mode = .conversation,
        hostIsCurrentUser: Bool = false,
        members: [ZixyUserRecord] = [],
        hostImage: UIImage? = nil
    ) {
        self.roomID = roomID
            ?? "room|\(hostEmail ?? hostName)|\(roomTitle)"
        self.roomTitle = roomTitle
        self.hostName = hostName
        self.hostEmail = hostEmail
        self.mode = mode
        self.hostIsCurrentUser = hostIsCurrentUser
        self.seats = Self.makeSeats(members: members)
        super.init(nibName: nil, bundle: nil)
        if let hostImage {
            hostImageView.image = hostImage
        }
    }

    convenience init(room: ZixyRoomRecord) {
        self.init(
            roomID: room.id,
            roomTitle: room.title,
            hostName: room.owner.username,
            hostEmail: room.owner.email,
            mode: .conversation,
            hostIsCurrentUser:
                room.owner.email == ZixySessionStore.currentUserIdentifier,
            members: room.members,
            hostImage: ZixyUserAvatarStore.image(for: room.owner)
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    private static func makeSeats(members: [ZixyUserRecord]) -> [Seat] {
        if members.isEmpty {
            return [
                Seat(
                    email: nil,
                    name: "JojoinS",
                    image: ZixyImageLibrary.chatParticipantAvatar,
                    isEmpty: false
                ),
                Seat(
                    email: nil,
                    name: "Sally",
                    image: ZixyImageLibrary.homeRoomPortrait,
                    isEmpty: false
                ),
                Seat(
                    email: nil,
                    name: "Mamazik",
                    image: ZixyImageLibrary.userAvatar,
                    isEmpty: false
                ),
                Seat(
                    email: nil,
                    name: "Alice",
                    image: ZixyImageLibrary.profileAvatar,
                    isEmpty: false
                ),
                Seat(
                    email: nil,
                    name: "Anginsa",
                    image: ZixyImageLibrary.userAvatar,
                    isEmpty: false
                ),
                Seat(
                    email: nil,
                    name: "Hery",
                    image: ZixyImageLibrary.profileAvatar,
                    isEmpty: false
                ),
                Seat(email: nil, name: "7", image: nil, isEmpty: true),
                Seat(email: nil, name: "8", image: nil, isEmpty: true)
            ]
        }

        var seats = members.map {
            Seat(
                email: $0.email,
                name: $0.username,
                image: ZixyUserAvatarStore.image(for: $0),
                isEmpty: false
            )
        }
        while seats.count < 8 {
            seats.append(
                Seat(
                    email: nil,
                    name: "\(seats.count + 1)",
                    image: nil,
                    isEmpty: true
                )
            )
        }
        return Array(seats.prefix(8))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureRoomNavigation()
        configureLayout()
        configureInteractions()
        loadMessages()
        observeKeyboard()
        observeProfileChanges()
        updateMode(animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateBalance()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageTableView.layoutIfNeeded()
        scrollToLatestMessage(animated: false)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cancelVoiceRecording()
        stopVoicePlayback()
        guard isMovingFromParent || navigationController?.isBeingDismissed == true else {
            return
        }
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
        keyboardObservers.removeAll()
        if let profileObserver {
            NotificationCenter.default.removeObserver(profileObserver)
            self.profileObserver = nil
        }
    }

    private func configureRoomNavigation() {
        configureNavigation(
            title: roomTitle,
            showsBackButton: true,
            rightView: hostIsCurrentUser
                || !ZixySessionStore.allowsSocialInteraction
                ? nil
                : moreButton
        )
        navigationBar.titleLabel.font = ZixyFontBook.bold(
            size: 20,
            relativeTo: .headline
        )
        navigationBar.titleLabel.textColor = .white
        navigationBar.backButton.backgroundColor = .white
        navigationBar.backButton.tintColor = .black
        hostNameLabel.text = hostName
    }

    private func observeProfileChanges() {
        profileObserver = NotificationCenter.default.addObserver(
            forName: .zixyUserProfileDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let user = notification.object as? ZixyUserRecord
            else {
                return
            }

            if hostIsCurrentUser,
               user.email == ZixySessionStore.currentUserIdentifier {
                hostName = user.username
                hostNameLabel.text = user.username
                hostImageView.image = ZixyUserAvatarStore.image(for: user)
                    ?? ZixyImageLibrary.homeRoomPortrait
            }

            var didUpdateSeat = false
            seats = seats.map { seat in
                guard seat.email == user.email else {
                    return seat
                }
                didUpdateSeat = true
                return Seat(
                    email: user.email,
                    name: user.username,
                    image: ZixyUserAvatarStore.image(for: user),
                    isEmpty: false
                )
            }
            if didUpdateSeat {
                seatCollectionView.reloadData()
            }
            if user.email.lowercased()
                == ZixySessionStore.currentUserIdentifier.lowercased() {
                messageTableView.reloadData()
            }
        }
    }

    private func configureLayout() {
        view.insertSubview(roomBackgroundView, at: 1)
        contentView.addSubview(hostImageView)
        contentView.addSubview(hostNameLabel)
        contentView.addSubview(seatCollectionView)
        contentView.addSubview(messageTableView)
        contentView.addSubview(inputContainer)
        contentView.addSubview(microphoneButton)
        view.addSubview(recordingStatusLabel)
        inputContainer.addSubview(giftButton)
        inputContainer.addSubview(messageField)
        inputContainer.addSubview(sendButton)
        contentView.addSubview(storePanel)
        storePanel.addSubview(storeEyebrowLabel)
        storePanel.addSubview(storeTitleLabel)
        storePanel.addSubview(giftCollectionView)
        storePanel.addSubview(balanceImageView)
        storePanel.addSubview(balanceLabel)
        storePanel.addSubview(rechargeButton)

        let inputBottom = inputContainer.bottomAnchor.constraint(
            equalTo: contentView.safeAreaLayoutGuide.bottomAnchor,
            constant: -16
        )
        inputBottomConstraint = inputBottom

        NSLayoutConstraint.activate([
            roomBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            roomBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roomBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roomBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            hostImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            hostImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            hostImageView.widthAnchor.constraint(equalToConstant: 86),
            hostImageView.heightAnchor.constraint(equalTo: hostImageView.widthAnchor),

            hostNameLabel.topAnchor.constraint(
                equalTo: hostImageView.bottomAnchor,
                constant: 8
            ),
            hostNameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            hostNameLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: contentView.leadingAnchor,
                constant: 20
            ),
            hostNameLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: contentView.trailingAnchor,
                constant: -20
            ),

            seatCollectionView.topAnchor.constraint(
                equalTo: hostNameLabel.bottomAnchor,
                constant: 8
            ),
            seatCollectionView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 14
            ),
            seatCollectionView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -14
            ),
            seatCollectionView.heightAnchor.constraint(equalToConstant: 176),

            messageTableView.topAnchor.constraint(
                equalTo: seatCollectionView.bottomAnchor,
                constant: 12
            ),
            messageTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            messageTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            messageTableView.bottomAnchor.constraint(
                equalTo: inputContainer.topAnchor,
                constant: -8
            ),

            inputContainer.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 16
            ),
            inputContainer.trailingAnchor.constraint(
                equalTo: microphoneButton.leadingAnchor,
                constant: -12
            ),
            inputContainer.heightAnchor.constraint(equalToConstant: 58),
            inputBottom,

            microphoneButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -16
            ),
            microphoneButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            microphoneButton.widthAnchor.constraint(equalToConstant: 58),
            microphoneButton.heightAnchor.constraint(equalTo: microphoneButton.widthAnchor),

            recordingStatusLabel.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            recordingStatusLabel.centerYAnchor.constraint(
                equalTo: view.centerYAnchor
            ),
            recordingStatusLabel.widthAnchor.constraint(equalToConstant: 126),
            recordingStatusLabel.heightAnchor.constraint(equalToConstant: 28),

            giftButton.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 14),
            giftButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            giftButton.widthAnchor.constraint(equalToConstant: 38),
            giftButton.heightAnchor.constraint(equalTo: giftButton.widthAnchor),

            sendButton.trailingAnchor.constraint(
                equalTo: inputContainer.trailingAnchor,
                constant: -14
            ),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 34),
            sendButton.heightAnchor.constraint(equalTo: sendButton.widthAnchor),

            messageField.leadingAnchor.constraint(
                equalTo: giftButton.trailingAnchor,
                constant: 8
            ),
            messageField.trailingAnchor.constraint(
                equalTo: sendButton.leadingAnchor,
                constant: -8
            ),
            messageField.topAnchor.constraint(equalTo: inputContainer.topAnchor),
            messageField.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor),

            storePanel.topAnchor.constraint(
                equalTo: seatCollectionView.bottomAnchor,
                constant: 28
            ),
            storePanel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            storePanel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            storePanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            storeEyebrowLabel.topAnchor.constraint(
                equalTo: storePanel.topAnchor,
                constant: 16
            ),
            storeEyebrowLabel.leadingAnchor.constraint(
                equalTo: storePanel.leadingAnchor,
                constant: 24
            ),

            storeTitleLabel.topAnchor.constraint(
                equalTo: storeEyebrowLabel.bottomAnchor,
                constant: -2
            ),
            storeTitleLabel.leadingAnchor.constraint(
                equalTo: storeEyebrowLabel.leadingAnchor,
                constant: 8
            ),

            giftCollectionView.topAnchor.constraint(
                equalTo: storeTitleLabel.bottomAnchor,
                constant: 6
            ),
            giftCollectionView.leadingAnchor.constraint(
                equalTo: storePanel.leadingAnchor,
                constant: 18
            ),
            giftCollectionView.trailingAnchor.constraint(
                equalTo: storePanel.trailingAnchor,
                constant: -18
            ),
            giftCollectionView.heightAnchor.constraint(equalToConstant: 170),

            balanceImageView.leadingAnchor.constraint(
                equalTo: storePanel.leadingAnchor,
                constant: 20
            ),
            balanceImageView.bottomAnchor.constraint(
                equalTo: storePanel.safeAreaLayoutGuide.bottomAnchor,
                constant: -12
            ),
            balanceImageView.widthAnchor.constraint(equalToConstant: 32),
            balanceImageView.heightAnchor.constraint(equalToConstant: 28),

            balanceLabel.leadingAnchor.constraint(
                equalTo: balanceImageView.trailingAnchor,
                constant: 4
            ),
            balanceLabel.centerYAnchor.constraint(equalTo: balanceImageView.centerYAnchor),

            rechargeButton.trailingAnchor.constraint(
                equalTo: storePanel.trailingAnchor,
                constant: -18
            ),
            rechargeButton.centerYAnchor.constraint(equalTo: balanceImageView.centerYAnchor),
            rechargeButton.widthAnchor.constraint(equalToConstant: 108),
            rechargeButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func configureInteractions() {
        messageField.delegate = self
        hostImageView.isUserInteractionEnabled = true
        hostImageView.accessibilityTraits = .button
        hostImageView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(openHostProfile)
            )
        )
        moreButton.addTarget(self, action: #selector(showMoreActions), for: .touchUpInside)
        giftButton.addTarget(self, action: #selector(openGiftStore), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        microphoneButton.addTarget(
            self,
            action: #selector(toggleMicrophone),
            for: .touchUpInside
        )
        let voiceGesture = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleVoiceLongPress(_:))
        )
        voiceGesture.minimumPressDuration = 0.45
        microphoneButton.addGestureRecognizer(voiceGesture)
        rechargeButton.addTarget(self, action: #selector(openRecharge), for: .touchUpInside)

        let dismissGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleBackgroundTap(_:))
        )
        dismissGesture.cancelsTouchesInView = false
        contentView.addGestureRecognizer(dismissGesture)

        let closeStoreGesture = UISwipeGestureRecognizer(
            target: self,
            action: #selector(closeGiftStore)
        )
        closeStoreGesture.direction = .down
        storePanel.addGestureRecognizer(closeStoreGesture)
    }

    @objc private func openHostProfile() {
        guard let hostEmail else {
            return
        }
        pushZixyOtherProfile(userEmail: hostEmail)
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
        inputBottomConstraint?.constant = -(overlap + (overlap > 0 ? 10 : 16))

        let duration = userInfo[
            UIResponder.keyboardAnimationDurationUserInfoKey
        ] as? TimeInterval ?? 0.25
        let curve = userInfo[
            UIResponder.keyboardAnimationCurveUserInfoKey
        ] as? UInt ?? 7
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [
                UIView.AnimationOptions(rawValue: curve << 16),
                .beginFromCurrentState
            ],
            animations: {
                self.view.layoutIfNeeded()
            }
        )
    }

    private func updateMode(animated: Bool) {
        let showsStore = mode == .store
        let changes = {
            self.storePanel.alpha = showsStore ? 1 : 0
            self.storePanel.transform = showsStore
                ? .identity
                : CGAffineTransform(translationX: 0, y: 80)
            self.storePanel.isHidden = false
            self.messageTableView.alpha = showsStore ? 0 : 1
            self.inputContainer.alpha = showsStore ? 0 : 1
            self.microphoneButton.alpha = showsStore ? 0 : 1
        }
        let completion: (Bool) -> Void = { _ in
            self.storePanel.isHidden = !showsStore
            self.messageTableView.isHidden = showsStore
            self.inputContainer.isHidden = showsStore
            self.microphoneButton.isHidden = showsStore
        }

        storePanel.isHidden = false
        if animated {
            UIView.animate(
                withDuration: 0.26,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState],
                animations: changes,
                completion: completion
            )
        } else {
            changes()
            completion(true)
        }
    }

    @objc private func handleBackgroundTap(
        _ gesture: UITapGestureRecognizer
    ) {
        view.endEditing(true)
        guard mode == .store else {
            return
        }
        let location = gesture.location(in: storePanel)
        guard !storePanel.bounds.contains(location) else {
            return
        }
        closeGiftStore()
    }

    @objc private func openGiftStore() {
        view.endEditing(true)
        cancelVoiceRecording()
        updateBalance()
        mode = .store
        updateMode(animated: true)
    }

    @objc private func closeGiftStore() {
        mode = .conversation
        updateMode(animated: true)
    }

    private func loadMessages() {
        let accountEmail = ZixySessionStore.currentUserIdentifier
        messages = ZixySessionStore.roomMessages(
            roomID: roomID
        ).compactMap { record in
            let content: Message.Content
            switch record.kind {
            case .text:
                content = .text(record.body)
            case .gift:
                content = .gift(name: record.body)
            case .voice:
                guard
                    let url = ZixyRoomVoiceStore.url(
                        reference: record.mediaReference
                    )
                else {
                    return nil
                }
                content = .voice(url: url, duration: record.duration)
            }
            return Message(
                content: content,
                isCurrentUser: record.senderEmail.caseInsensitiveCompare(
                    accountEmail
                ) == .orderedSame
            )
        }
        messageTableView.reloadData()
        guard !messages.isEmpty else {
            return
        }
        view.layoutIfNeeded()
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        messageTableView.scrollToRow(
            at: indexPath,
            at: .bottom,
            animated: false
        )
    }

    @discardableResult
    private func persistMessage(
        kind: ZixyRoomMessageKind,
        body: String,
        mediaReference: String = "",
        duration: TimeInterval = 0
    ) -> Bool {
        let accountEmail = ZixySessionStore.currentUserIdentifier
        do {
            try ZixyDataStore.shared.addRoomMessage(
                roomID: roomID,
                accountEmail: accountEmail,
                senderEmail: accountEmail,
                kind: kind,
                body: body,
                mediaReference: mediaReference,
                duration: duration
            )
            return true
        } catch {
            showToast("Unable to save the message.")
            return false
        }
    }

    @objc private func sendMessage() {
        guard ZixySessionStore.allowsSocialInteraction else {
            showToast("Sign in to send messages.")
            return
        }
        let text = messageField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            showToast("Enter a message first.")
            return
        }
        guard persistMessage(kind: .text, body: text) else {
            return
        }
        messages.append(Message(content: .text(text), isCurrentUser: true))
        messageField.text = nil
        reloadMessagesAndScrollToLatest()
    }

    private func reloadMessagesAndScrollToLatest() {
        messageTableView.reloadData()
        scrollToLatestMessage(animated: true)
    }

    private func scrollToLatestMessage(animated: Bool) {
        guard !messages.isEmpty else {
            return
        }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        messageTableView.scrollToRow(
            at: indexPath,
            at: .bottom,
            animated: animated
        )
    }

    @objc private func handleVoiceLongPress(
        _ gesture: UILongPressGestureRecognizer
    ) {
        switch gesture.state {
        case .began:
            isLongPressHeld = true
            beginVoiceRecording()
        case .ended:
            isLongPressHeld = false
            finishVoiceRecording(shouldSend: true)
        case .cancelled, .failed:
            isLongPressHeld = false
            finishVoiceRecording(shouldSend: false)
        default:
            break
        }
    }

    private func beginVoiceRecording() {
        guard ZixySessionStore.allowsSocialInteraction else {
            isLongPressHeld = false
            showToast("Sign in to send voice messages.")
            return
        }
        view.endEditing(true)
        stopVoicePlayback()

        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            startVoiceRecorder()
        case .denied:
            isLongPressHeld = false
            showToast("Microphone access is required to record voice messages.")
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    guard granted else {
                        self.isLongPressHeld = false
                        self.showToast(
                            "Microphone access is required to record voice messages."
                        )
                        return
                    }
                    guard self.isLongPressHeld else {
                        return
                    }
                    self.startVoiceRecorder()
                }
            }
        @unknown default:
            isLongPressHeld = false
            showToast("Unable to check microphone permission.")
        }
    }

    private func startVoiceRecorder() {
        guard audioRecorder == nil else {
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("zixy_room_voice_\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try session.setActive(true)
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.prepareToRecord(), recorder.record() else {
                try? FileManager.default.removeItem(at: url)
                showToast("Unable to start voice recording.")
                return
            }
            audioRecorder = recorder
            recordingURL = url
            showRecordingState(true)
        } catch {
            try? FileManager.default.removeItem(at: url)
            showToast("Unable to start voice recording.")
        }
    }

    private func finishVoiceRecording(shouldSend: Bool) {
        guard let recorder = audioRecorder else {
            showRecordingState(false)
            return
        }
        let measuredDuration = recorder.currentTime
        recorder.stop()
        audioRecorder = nil
        let url = recordingURL
        recordingURL = nil
        showRecordingState(false)
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )

        guard shouldSend, measuredDuration >= 0.15, let url else {
            if let url {
                try? FileManager.default.removeItem(at: url)
            }
            if shouldSend {
                showToast("Hold the microphone a little longer.")
            }
            return
        }
        let mediaReference: String
        do {
            mediaReference = try ZixyRoomVoiceStore.save(from: url)
        } catch {
            try? FileManager.default.removeItem(at: url)
            showToast("Unable to save the voice message.")
            return
        }
        guard
            persistMessage(
                kind: .voice,
                body: "",
                mediaReference: mediaReference,
                duration: measuredDuration
            )
        else {
            ZixyRoomVoiceStore.remove(reference: mediaReference)
            return
        }
        guard
            let persistedURL = ZixyRoomVoiceStore.url(
                reference: mediaReference
            )
        else {
            showToast("Unable to load the voice message.")
            return
        }
        messages.append(
            Message(
                content: .voice(
                    url: persistedURL,
                    duration: measuredDuration
                ),
                isCurrentUser: true
            )
        )
        reloadMessagesAndScrollToLatest()
    }

    private func cancelVoiceRecording() {
        guard audioRecorder != nil || recordingURL != nil else {
            showRecordingState(false)
            return
        }
        finishVoiceRecording(shouldSend: false)
    }

    private func showRecordingState(_ isRecording: Bool) {
        recordingStatusLabel.isHidden = false
        microphoneButton.accessibilityLabel = isRecording
            ? "Recording voice message. Release to send."
            : (isMicrophoneMuted ? "Unmute microphone" : "Mute microphone")
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.beginFromCurrentState]
        ) {
            self.recordingStatusLabel.alpha = isRecording ? 1 : 0
            self.microphoneButton.transform = isRecording
                ? CGAffineTransform(scaleX: 1.12, y: 1.12)
                : .identity
        } completion: { _ in
            if !isRecording {
                self.recordingStatusLabel.isHidden = true
            }
        }
    }

    private func playVoiceMessage(at indexPath: IndexPath) {
        guard messages.indices.contains(indexPath.row) else {
            return
        }
        let message = messages[indexPath.row]
        guard case let .voice(url, _) = message.content else {
            return
        }
        if playingMessageID == message.id {
            stopVoicePlayback()
            return
        }

        stopVoicePlayback()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            guard player.prepareToPlay(), player.play() else {
                stopVoicePlayback()
                showToast("Unable to play this voice message.")
                return
            }
            audioPlayer = player
            playingMessageID = message.id
            messageTableView.reloadRows(at: [indexPath], with: .none)
            playbackTimer = Timer.scheduledTimer(
                withTimeInterval: player.duration + 0.05,
                repeats: false
            ) { [weak self] _ in
                self?.stopVoicePlayback()
            }
        } catch {
            stopVoicePlayback()
            showToast("Unable to play this voice message.")
        }
    }

    private func stopVoicePlayback() {
        let previousID = playingMessageID
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        playingMessageID = nil
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
        guard
            let previousID,
            let row = messages.firstIndex(where: { $0.id == previousID }),
            messageTableView.window != nil
        else {
            return
        }
        messageTableView.reloadRows(
            at: [IndexPath(row: row, section: 0)],
            with: .none
        )
    }

    @objc private func toggleMicrophone() {
        isMicrophoneMuted.toggle()
        microphoneButton.setImage(
            isMicrophoneMuted
                ? ZixyImageLibrary.roomMicrophoneMuted
                : ZixyImageLibrary.roomMicrophoneActive,
            for: .normal
        )
        microphoneButton.accessibilityLabel = isMicrophoneMuted
            ? "Unmute microphone"
            : "Mute microphone"
        showToast(isMicrophoneMuted ? "Microphone muted." : "Microphone active.")
    }

    @objc private func showMoreActions() {
        guard
            ZixySessionStore.allowsSocialInteraction,
            !hostIsCurrentUser
        else {
            return
        }
        let controller = ZixyMoreActionsController(targetName: hostName)
        controller.onFollowed = { [weak self] in
            guard let self else {
                return
            }
            guard
                ZixySessionStore.allowsSocialInteraction,
                !self.hostIsCurrentUser,
                let hostEmail = self.hostEmail
            else {
                self.showToast("Unable to follow \(self.hostName).")
                return
            }
            do {
                try ZixyDataStore.shared.setFollowing(
                    true,
                    followedEmail: hostEmail,
                    followerEmail: ZixySessionStore.currentUserIdentifier
                )
                self.showToast("Followed \(self.hostName).")
            } catch {
                self.showToast("Unable to follow \(self.hostName).")
            }
        }
        controller.onReport = { [weak self] in
            guard let self, !self.hostIsCurrentUser else {
                return
            }
            let reportController = ZixyReportController(
                reportedUserName: self.hostName,
                isCurrentUser: self.hostIsCurrentUser
            )
            self.push(reportController)
        }
        controller.onBlock = { [weak self] in
            guard
                let self,
                ZixySessionStore.allowsSocialInteraction,
                !self.hostIsCurrentUser
            else {
                return
            }
            do {
                if let hostEmail = self.hostEmail {
                    try ZixyDataStore.shared.setBlocked(
                        true,
                        blockedEmail: hostEmail,
                        blockerEmail: ZixySessionStore.currentUserIdentifier
                    )
                } else {
                    try ZixyDataStore.shared.setBlocked(
                        true,
                        blockedUsername: self.hostName,
                        blockerEmail: ZixySessionStore.currentUserIdentifier
                    )
                }
                if let navigationController = self.navigationController,
                   navigationController.viewControllers.count > 1 {
                    let previousController = navigationController.viewControllers[
                        navigationController.viewControllers.count - 2
                    ]
                    navigationController.popViewController(animated: true)
                    previousController.showToast(
                        "\(self.hostName) has been blocked."
                    )
                } else {
                    self.dismiss(animated: true)
                }
            } catch {
                self.showToast("Unable to update the blacklist.")
            }
        }
        present(controller, animated: false)
    }

    @objc private func openRecharge() {
        push(ZixyRechargeController())
    }

    private func updateBalance() {
        balanceLabel.text = NumberFormatter.localizedString(
            from: NSNumber(value: ZixyRechargeController.currentUserBalance),
            number: .decimal
        )
    }

    private func sendGift(_ gift: Gift) {
        guard ZixySessionStore.allowsSocialInteraction else {
            showToast("Sign in to send gifts.")
            return
        }
        let balanceBeforeSending = ZixyRechargeController.currentUserBalance
        guard balanceBeforeSending >= gift.price else {
            let alert = ZixyAlertController(kind: .insufficientCoins)
            alert.onPrimaryAction = { [weak self] in
                self?.openRecharge()
            }
            present(alert, animated: true)
            return
        }
        guard ZixyRechargeController.spendCoins(gift.price) else {
            showToast("Unable to send the gift.")
            updateBalance()
            return
        }
        guard persistMessage(kind: .gift, body: gift.name) else {
            try? ZixyCoinBalanceStore.setBalance(
                balanceBeforeSending,
                for: ZixySessionStore.currentUserIdentifier
            )
            updateBalance()
            return
        }

        messages.append(
            Message(
                content: .gift(name: gift.name),
                isCurrentUser: true
            )
        )
        updateBalance()
        closeGiftStore()
        reloadMessagesAndScrollToLatest()
        animateGift(gift)
    }

    private func animateGift(_ gift: Gift) {
        guard let image = gift.image else {
            return
        }
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.alpha = 0
        imageView.transform = CGAffineTransform(scaleX: 0.25, y: 0.25)
        imageView.accessibilityLabel = "\(gift.name) gift sent"
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 150),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor)
        ])
        view.layoutIfNeeded()

        UIView.animate(
            withDuration: 0.48,
            delay: 0,
            usingSpringWithDamping: 0.58,
            initialSpringVelocity: 0.7,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: {
                imageView.alpha = 1
                imageView.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
            },
            completion: { _ in
                UIView.animate(
                    withDuration: 0.38,
                    delay: 0.5,
                    options: [.curveEaseIn, .beginFromCurrentState],
                    animations: {
                        imageView.alpha = 0
                        imageView.transform = CGAffineTransform(
                            translationX: 0,
                            y: -36
                        ).scaledBy(x: 1.45, y: 1.45)
                    },
                    completion: { _ in
                        imageView.removeFromSuperview()
                    }
                )
            }
        )
    }
}

extension ZixyRoomDetailController:
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        collectionView === seatCollectionView ? seats.count : gifts.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if collectionView === seatCollectionView {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ZixyRoomSeatCell.reuseIdentifier,
                for: indexPath
            ) as? ZixyRoomSeatCell else {
                return UICollectionViewCell()
            }
            let seat = seats[indexPath.item]
            cell.configure(name: seat.name, image: seat.image, isEmpty: seat.isEmpty)
            cell.onAvatarTapped = { [weak self] in
                self?.openProfile(for: seat)
            }
            return cell
        }

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ZixyRoomGiftCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyRoomGiftCell else {
            return UICollectionViewCell()
        }
        let gift = gifts[indexPath.item]
        cell.configure(name: gift.name, image: gift.image, price: gift.price)
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let spacing: CGFloat = collectionView === seatCollectionView ? 8 : 4
        let width = floor((collectionView.bounds.width - spacing * 3) / 4)
        return CGSize(
            width: width,
            height: collectionView === seatCollectionView ? 82 : 81
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        if collectionView === seatCollectionView {
            let seat = seats[indexPath.item]
            guard !seat.isEmpty else {
                showToast("This seat is available.")
                return
            }
            return
        }

        guard gifts.indices.contains(indexPath.item) else {
            return
        }
        sendGift(gifts[indexPath.item])
    }

    private func openProfile(for seat: Seat) {
        guard !seat.isEmpty else {
            return
        }
        guard let email = seat.email else {
            return
        }
        pushZixyOtherProfile(userEmail: email)
    }
}

extension ZixyRoomDetailController: UITableViewDataSource, UITableViewDelegate {

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        messages.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ZixyRoomMessageCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyRoomMessageCell else {
            return UITableViewCell()
        }
        let message = messages[indexPath.row]
        let currentUser = ZixyDataStore.shared.currentUser()
        let senderName = message.isCurrentUser
            ? (currentUser?.username ?? "User")
            : hostName
        let senderAvatar = message.isCurrentUser
            ? currentUser.flatMap { ZixyUserAvatarStore.image(for: $0) }
                ?? ZixyImageLibrary.userAvatar
            : hostEmail
                .flatMap { ZixyDataStore.shared.user(email: $0) }
                .flatMap { ZixyUserAvatarStore.image(for: $0) }
                ?? ZixyImageLibrary.homeRoomPortrait
        let text: String?
        let voiceDuration: TimeInterval?
        switch message.content {
        case let .text(value):
            text = value
            voiceDuration = nil
        case let .voice(_, duration):
            text = nil
            voiceDuration = duration
        case let .gift(name):
            text = "\(senderName) sent a \(name) gift."
            voiceDuration = nil
        }
        cell.configure(
            name: senderName,
            text: text,
            voiceDuration: voiceDuration,
            avatar: senderAvatar,
            isCurrentUser: message.isCurrentUser,
            isPlaying: playingMessageID == message.id
        )
        let messageID = message.id
        cell.onVoiceTapped = { [weak self] in
            guard
                let self,
                let row = self.messages.firstIndex(where: { $0.id == messageID })
            else {
                return
            }
            self.playVoiceMessage(at: IndexPath(row: row, section: 0))
        }
        return cell
    }

}

extension ZixyRoomDetailController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        sendMessage()
        return true
    }
}

private final class ZixyRoomSeatCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyRoomSeatCell"

    var onAvatarTapped: (() -> Void)?

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()

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

    func configure(name: String, image: UIImage?, isEmpty: Bool) {
        nameLabel.text = name
        if isEmpty {
            avatarView.image = UIImage(
                systemName: "sofa.fill",
                withConfiguration: UIImage.SymbolConfiguration(
                    pointSize: 22,
                    weight: .bold
                )
            )
            avatarView.tintColor = UIColor.white.withAlphaComponent(0.55)
            avatarView.contentMode = .center
            avatarView.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        } else {
            avatarView.image = image
            avatarView.contentMode = .scaleAspectFill
            avatarView.backgroundColor = .clear
        }
        avatarView.isUserInteractionEnabled = !isEmpty
        avatarView.accessibilityTraits = isEmpty ? [] : .button
        accessibilityLabel = isEmpty ? "Seat \(name), available" : name
    }

    private func configureLayout() {
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 25
        avatarView.accessibilityTraits = .button
        avatarView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(avatarTapped)
            )
        )

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = ZixyFontBook.bold(size: 11, relativeTo: .caption2)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.65

        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor),
            avatarView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 50),
            avatarView.heightAnchor.constraint(equalTo: avatarView.widthAnchor),

            nameLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 5),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])
    }

    @objc private func avatarTapped() {
        onAvatarTapped?()
    }
}

private final class ZixyRoomGiftCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyRoomGiftCell"

    private let imageView = UIImageView()
    private let nameLabel = UILabel()
    private let priceLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(name: String, image: UIImage?, price: Int) {
        imageView.image = image
        nameLabel.text = name
        priceLabel.text = "🪙 \(price)"
        accessibilityLabel = "\(name), \(price) coins"
    }

    private func configureLayout() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = ZixyFontBook.bold(size: 7, relativeTo: .caption2)
        nameLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        nameLabel.textAlignment = .center
        nameLabel.adjustsFontSizeToFitWidth = true

        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.font = ZixyFontBook.bold(size: 8, relativeTo: .caption2)
        priceLabel.textColor = UIColor(red: 1, green: 0.72, blue: 0.53, alpha: 1)
        priceLabel.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        priceLabel.layer.cornerRadius = 7
        priceLabel.clipsToBounds = true
        priceLabel.textAlignment = .center

        contentView.addSubview(imageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(priceLabel)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 58),
            imageView.heightAnchor.constraint(equalToConstant: 51),

            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -2),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            priceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            priceLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            priceLabel.widthAnchor.constraint(equalToConstant: 42),
            priceLabel.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
}

private final class ZixyRoomMessageCell: UITableViewCell {

    static let reuseIdentifier = "ZixyRoomMessageCell"

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private let voiceButton = UIButton(type: .system)
    private var messageConstraints: [NSLayoutConstraint] = []
    private var voiceConstraints: [NSLayoutConstraint] = []

    var onVoiceTapped: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopVoiceAnimation()
        onVoiceTapped = nil
    }

    func configure(
        name: String,
        text: String?,
        voiceDuration: TimeInterval?,
        avatar: UIImage?,
        isCurrentUser: Bool,
        isPlaying: Bool
    ) {
        avatarView.image = avatar
        nameLabel.text = name
        messageLabel.text = text
        messageLabel.isHidden = text == nil
        voiceButton.isHidden = voiceDuration == nil
        NSLayoutConstraint.deactivate(messageConstraints + voiceConstraints)
        NSLayoutConstraint.activate(
            voiceDuration == nil ? messageConstraints : voiceConstraints
        )
        isAccessibilityElement = text != nil
        if let voiceDuration {
            let seconds = max(1, Int(ceil(voiceDuration)))
            voiceButton.setTitle("\(seconds)s", for: .normal)
            voiceButton.setImage(
                UIImage(systemName: "waveform"),
                for: .normal
            )
            voiceButton.accessibilityLabel = isPlaying
                ? "Stop voice message"
                : "Play voice message, \(seconds) seconds"
            updateVoiceAnimation(isPlaying: isPlaying)
        } else {
            stopVoiceAnimation()
            voiceButton.setTitle(nil, for: .normal)
            voiceButton.setImage(nil, for: .normal)
            voiceButton.accessibilityLabel = nil
        }
        bubbleView.backgroundColor = isCurrentUser
            ? UIColor(red: 0.15, green: 0.32, blue: 0.76, alpha: 0.68)
            : UIColor(red: 0.14, green: 0.08, blue: 0.38, alpha: 0.66)
        if let text {
            accessibilityLabel = "\(name): \(text)"
        } else {
            accessibilityLabel = "\(name), voice message"
        }
    }

    private func configureLayout() {
        backgroundColor = .clear
        selectionStyle = .none

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 17

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = ZixyFontBook.bold(size: 15, relativeTo: .subheadline)
        nameLabel.textColor = .white

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.layer.cornerRadius = 13

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = ZixyFontBook.bold(size: 16, relativeTo: .body)
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 2
        messageLabel.setContentHuggingPriority(.required, for: .horizontal)
        messageLabel.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        voiceButton.translatesAutoresizingMaskIntoConstraints = false
        voiceButton.tintColor = .white
        voiceButton.setTitleColor(.white, for: .normal)
        voiceButton.titleLabel?.font = ZixyFontBook.bold(
            size: 15,
            relativeTo: .body
        )
        voiceButton.contentHorizontalAlignment = .leading
        voiceButton.semanticContentAttribute = .forceLeftToRight
        voiceButton.setContentHuggingPriority(.required, for: .horizontal)
        voiceButton.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
        voiceButton.addTarget(
            self,
            action: #selector(voiceTapped),
            for: .touchUpInside
        )

        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        bubbleView.addSubview(voiceButton)
        messageConstraints = [
            messageLabel.topAnchor.constraint(
                equalTo: bubbleView.topAnchor,
                constant: 10
            ),
            messageLabel.leadingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: 12
            ),
            messageLabel.trailingAnchor.constraint(
                equalTo: bubbleView.trailingAnchor,
                constant: -12
            ),
            messageLabel.bottomAnchor.constraint(
                equalTo: bubbleView.bottomAnchor,
                constant: -10
            )
        ]
        voiceConstraints = [
            voiceButton.topAnchor.constraint(
                equalTo: bubbleView.topAnchor,
                constant: 8
            ),
            voiceButton.leadingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: 12
            ),
            voiceButton.trailingAnchor.constraint(
                equalTo: bubbleView.trailingAnchor,
                constant: -12
            ),
            voiceButton.bottomAnchor.constraint(
                equalTo: bubbleView.bottomAnchor,
                constant: -8
            )
        ]
        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            avatarView.widthAnchor.constraint(equalToConstant: 34),
            avatarView.heightAnchor.constraint(equalTo: avatarView.widthAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: contentView.trailingAnchor,
                constant: -20
            ),

            bubbleView.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 3),
            bubbleView.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            bubbleView.trailingAnchor.constraint(
                lessThanOrEqualTo: contentView.trailingAnchor,
                constant: -28
            ),
            bubbleView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -4
            )
        ])
        NSLayoutConstraint.activate(messageConstraints)
    }

    @objc private func voiceTapped() {
        onVoiceTapped?()
    }

    private func updateVoiceAnimation(isPlaying: Bool) {
        guard isPlaying, let imageLayer = voiceButton.imageView?.layer else {
            stopVoiceAnimation()
            return
        }
        guard imageLayer.animation(forKey: "zixy_voice_playback") == nil else {
            return
        }
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [0.82, 1.16, 0.92, 1.08, 0.82]
        animation.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        animation.duration = 0.9
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = true
        imageLayer.add(animation, forKey: "zixy_voice_playback")
    }

    private func stopVoiceAnimation() {
        voiceButton.imageView?.layer.removeAnimation(
            forKey: "zixy_voice_playback"
        )
    }
}
