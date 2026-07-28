import UIKit

final class ZixyRoomDetailController: ZixyScreenController {

    enum Mode {
        case conversation
        case store
    }

    private struct Seat {
        let name: String
        let image: UIImage?
        let isEmpty: Bool
    }

    private struct Gift {
        let name: String
        let image: UIImage?
        let price: Int
    }

    private let roomTitle: String
    private let hostName: String
    private let hostIsCurrentUser: Bool
    private var mode: Mode
    private var isMicrophoneMuted = false
    private var keyboardObservers: [NSObjectProtocol] = []
    private var inputBottomConstraint: NSLayoutConstraint?
    private var messages = ["Did you make wood carvings today😉?"]

    private let seats: [Seat] = [
        Seat(
            name: "JojoinS",
            image: ZixyImageLibrary.chatParticipantAvatar,
            isEmpty: false
        ),
        Seat(name: "Sally", image: ZixyImageLibrary.homeRoomPortrait, isEmpty: false),
        Seat(name: "🔥Mamazik🔥", image: ZixyImageLibrary.userAvatar, isEmpty: false),
        Seat(name: "🍷Alice🦄", image: ZixyImageLibrary.profileAvatar, isEmpty: false),
        Seat(name: "Anginsa💅", image: ZixyImageLibrary.userAvatar, isEmpty: false),
        Seat(name: "Hery", image: ZixyImageLibrary.profileAvatar, isEmpty: false),
        Seat(name: "7", image: nil, isEmpty: true),
        Seat(name: "8", image: nil, isEmpty: true)
    ]

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
        field.returnKeyType = .done
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
        roomTitle: String = "Here is the room...",
        hostName: String = "Katrina✨Ray",
        mode: Mode = .conversation,
        hostIsCurrentUser: Bool = false
    ) {
        self.roomTitle = roomTitle
        self.hostName = hostName
        self.mode = mode
        self.hostIsCurrentUser = hostIsCurrentUser
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureRoomNavigation()
        configureLayout()
        configureInteractions()
        observeKeyboard()
        updateMode(animated: false)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isMovingFromParent || navigationController?.isBeingDismissed == true else {
            return
        }
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
        keyboardObservers.removeAll()
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

    private func configureLayout() {
        view.insertSubview(roomBackgroundView, at: 1)
        contentView.addSubview(hostImageView)
        contentView.addSubview(hostNameLabel)
        contentView.addSubview(seatCollectionView)
        contentView.addSubview(messageTableView)
        contentView.addSubview(inputContainer)
        contentView.addSubview(microphoneButton)
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
        moreButton.addTarget(self, action: #selector(showMoreActions), for: .touchUpInside)
        giftButton.addTarget(self, action: #selector(openGiftStore), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        microphoneButton.addTarget(
            self,
            action: #selector(toggleMicrophone),
            for: .touchUpInside
        )
        rechargeButton.addTarget(self, action: #selector(openRecharge), for: .touchUpInside)

        let dismissGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
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

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func openGiftStore() {
        view.endEditing(true)
        mode = .store
        updateMode(animated: true)
    }

    @objc private func closeGiftStore() {
        mode = .conversation
        updateMode(animated: true)
    }

    @objc private func sendMessage() {
        let text = messageField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            showToast("Enter a message first.")
            return
        }
        messages.append(text)
        messageField.text = nil
        messageTableView.reloadData()
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        messageTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
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
            guard let self, !self.hostIsCurrentUser else {
                return
            }
            self.showToast("\(self.hostName) has been blocked.")
        }
        present(controller, animated: false)
    }

    @objc private func openRecharge() {
        push(ZixyRechargeController())
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
            showToast("\(seat.name) is in the room.")
            return
        }

        let gift = gifts[indexPath.item]
        showToast("\(gift.name) selected for \(gift.price) coins.")
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
        cell.configure(
            name: indexPath.row == 0 ? hostName : "You",
            message: messages[indexPath.row],
            avatar: indexPath.row == 0
                ? ZixyImageLibrary.homeRoomPortrait
                : ZixyImageLibrary.userAvatar,
            isCurrentUser: indexPath.row != 0
        )
        return cell
    }

    func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        86
    }
}

extension ZixyRoomDetailController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private final class ZixyRoomSeatCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyRoomSeatCell"

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
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
        accessibilityLabel = isEmpty ? "Seat \(name), available" : name
    }

    private func configureLayout() {
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 25

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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        name: String,
        message: String,
        avatar: UIImage?,
        isCurrentUser: Bool
    ) {
        avatarView.image = avatar
        nameLabel.text = name
        messageLabel.text = message
        bubbleView.backgroundColor = isCurrentUser
            ? UIColor(red: 0.15, green: 0.32, blue: 0.76, alpha: 0.68)
            : UIColor(red: 0.14, green: 0.08, blue: 0.38, alpha: 0.66)
        accessibilityLabel = "\(name): \(message)"
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

        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
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
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10)
        ])
    }
}
