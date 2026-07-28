import UIKit

final class ZixyAIChatController: UIViewController {

    private enum Layout {
        static let horizontalInset: CGFloat = 17
        static let controlHeight: CGFloat = 52
        static let controlBottomSpacing: CGFloat = 12
        static let initialMessageInset: CGFloat = 400
    }

    private enum MessageKind {
        case assistant
        case user
        case loading
    }

    private struct Message {
        let kind: MessageKind
        let text: String
    }

    private let responder = ZixyCraftKnowledgeResponder()
    private var messages = [
        Message(kind: .assistant, text: "Hey! What's up😊?")
    ]
    private var isReplying = false
    private var inputBottomConstraint: NSLayoutConstraint?

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView(image: ZixyImageLibrary.aiChatBackground)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private let backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(ZixyImageLibrary.aiChatBackButton, for: .normal)
        button.accessibilityLabel = "Back"
        return button
    }()

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.keyboardDismissMode = .interactive
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.contentInset = UIEdgeInsets(
            top: Layout.initialMessageInset,
            left: 0,
            bottom: 12,
            right: 0
        )
        return tableView
    }()

    private let inputContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.cornerRadius = Layout.controlHeight / 2
        return view
    }()

    private let messageField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "Enter..."
        field.font = ZixyFontBook.bold(size: 14, relativeTo: .body)
        field.textColor = UIColor.black.withAlphaComponent(0.82)
        field.tintColor = UIColor(
            red: 36 / 255,
            green: 82 / 255,
            blue: 1,
            alpha: 1
        )
        field.returnKeyType = .done
        field.clearButtonMode = .whileEditing
        field.accessibilityLabel = "Craft question"
        return field
    }()

    private let sendButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(ZixyImageLibrary.aiChatSendIcon, for: .normal)
        button.accessibilityLabel = "Send message"
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLayout()
        configureTableView()
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
        NotificationCenter.default.removeObserver(self)
    }

    private func configureLayout() {
        view.backgroundColor = UIColor(
            red: 45 / 255,
            green: 43 / 255,
            blue: 132 / 255,
            alpha: 1
        )
        view.addSubview(backgroundImageView)
        view.addSubview(tableView)
        view.addSubview(backButton)
        view.addSubview(inputContainer)
        inputContainer.addSubview(messageField)
        inputContainer.addSubview(sendButton)

        let bottomConstraint = inputContainer.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: -Layout.controlBottomSpacing
        )
        inputBottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 16
            ),
            backButton.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 20
            ),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),

            inputContainer.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            inputContainer.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            inputContainer.heightAnchor.constraint(
                equalToConstant: Layout.controlHeight
            ),
            bottomConstraint,

            sendButton.trailingAnchor.constraint(
                equalTo: inputContainer.trailingAnchor,
                constant: -14
            ),
            sendButton.centerYAnchor.constraint(
                equalTo: inputContainer.centerYAnchor
            ),
            sendButton.widthAnchor.constraint(equalToConstant: 34),
            sendButton.heightAnchor.constraint(equalToConstant: 34),

            messageField.leadingAnchor.constraint(
                equalTo: inputContainer.leadingAnchor,
                constant: 26
            ),
            messageField.trailingAnchor.constraint(
                equalTo: sendButton.leadingAnchor,
                constant: -10
            ),
            messageField.topAnchor.constraint(equalTo: inputContainer.topAnchor),
            messageField.bottomAnchor.constraint(
                equalTo: inputContainer.bottomAnchor
            ),

            tableView.topAnchor.constraint(equalTo: backButton.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(
                equalTo: inputContainer.topAnchor,
                constant: -8
            )
        ])
    }

    private func configureTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(
            ZixyChatMessageCell.self,
            forCellReuseIdentifier: ZixyChatMessageCell.reuseIdentifier
        )
        tableView.register(
            ZixyChatLoadingCell.self,
            forCellReuseIdentifier: ZixyChatLoadingCell.reuseIdentifier
        )
    }

    private func configureInteractions() {
        backButton.addTarget(
            self,
            action: #selector(navigateBack),
            for: .touchUpInside
        )
        sendButton.addTarget(
            self,
            action: #selector(sendMessage),
            for: .touchUpInside
        )
        messageField.delegate = self

        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
    }

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardChange(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private func scrollToLatestMessage(animated: Bool) {
        guard !messages.isEmpty else {
            return
        }
        tableView.scrollToRow(
            at: IndexPath(row: messages.count - 1, section: 0),
            at: .bottom,
            animated: animated
        )
    }

    private func finishReply(with text: String) {
        guard isReplying else {
            return
        }
        if messages.last?.kind == .loading {
            messages.removeLast()
        }
        messages.append(Message(kind: .assistant, text: text))
        isReplying = false
        sendButton.isEnabled = true
        sendButton.alpha = 1
        tableView.reloadData()
        scrollToLatestMessage(animated: true)
    }

    @objc private func sendMessage() {
        let text = messageField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            showToast("Enter a craft question first.")
            return
        }
        guard !isReplying else {
            return
        }

        isReplying = true
        sendButton.isEnabled = false
        sendButton.alpha = 0.45
        messages.append(Message(kind: .user, text: text))
        messages.append(Message(kind: .loading, text: "Thinking..."))
        messageField.text = nil
        tableView.reloadData()
        scrollToLatestMessage(animated: true)

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard let self else {
                return
            }
            let reply = responder.reply(to: text)
            finishReply(with: reply)
        }
    }

    @objc private func navigateBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func handleKeyboardChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrameValue = userInfo[
                  UIResponder.keyboardFrameEndUserInfoKey
              ] as? NSValue else {
            return
        }

        let keyboardFrame = view.convert(endFrameValue.cgRectValue, from: nil)
        let safeBottom = view.safeAreaLayoutGuide.layoutFrame.maxY
        let overlap = max(0, safeBottom - keyboardFrame.minY)
        inputBottomConstraint?.constant = -(
            overlap + Layout.controlBottomSpacing
        )

        let duration = userInfo[
            UIResponder.keyboardAnimationDurationUserInfoKey
        ] as? Double ?? 0.25
        let curveValue = userInfo[
            UIResponder.keyboardAnimationCurveUserInfoKey
        ] as? UInt ?? 7
        let options = UIView.AnimationOptions(
            rawValue: curveValue << 16
        )

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
}

extension ZixyAIChatController:
    UITableViewDataSource,
    UITableViewDelegate {

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
        let message = messages[indexPath.row]
        if message.kind == .loading {
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: ZixyChatLoadingCell.reuseIdentifier,
                for: indexPath
            ) as? ZixyChatLoadingCell else {
                return UITableViewCell()
            }
            cell.startAnimating()
            return cell
        }

        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ZixyChatMessageCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyChatMessageCell else {
            return UITableViewCell()
        }
        cell.configure(
            text: message.text,
            isUser: message.kind == .user
        )
        return cell
    }
}

extension ZixyAIChatController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        sendMessage()
        return true
    }
}

extension ZixyAIChatController: UIGestureRecognizerDelegate {

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard let touchedView = touch.view else {
            return true
        }
        return !touchedView.isDescendant(of: inputContainer)
    }
}

private final class ZixyChatMessageCell: UITableViewCell {

    static let reuseIdentifier = "ZixyChatMessageCell"

    private let bubbleView = UIView()
    private let dotView = UIView()
    private let messageLabel = UILabel()
    private var assistantConstraints: [NSLayoutConstraint] = []
    private var userConstraints: [NSLayoutConstraint] = []

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(text: String, isUser: Bool) {
        messageLabel.text = text
        dotView.isHidden = isUser
        bubbleView.backgroundColor = isUser
            ? UIColor(
                red: 46 / 255,
                green: 98 / 255,
                blue: 1,
                alpha: 0.92
            )
            : .clear
        NSLayoutConstraint.deactivate(
            isUser ? assistantConstraints : userConstraints
        )
        NSLayoutConstraint.activate(
            isUser ? userConstraints : assistantConstraints
        )
        accessibilityLabel = isUser
            ? "You: \(text)"
            : "Zixy AI: \(text)"
    }

    private func configureLayout() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.layer.cornerRadius = 18
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = ZixyFontBook.bold(size: 16, relativeTo: .body)
        messageLabel.textColor = .white
        messageLabel.numberOfLines = 0
        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.backgroundColor = UIColor(
            red: 32 / 255,
            green: 232 / 255,
            blue: 239 / 255,
            alpha: 1
        )
        dotView.layer.cornerRadius = 3

        contentView.addSubview(dotView)
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)

        assistantConstraints = [
            bubbleView.leadingAnchor.constraint(
                equalTo: dotView.trailingAnchor,
                constant: 6
            )
        ]
        userConstraints = [
            bubbleView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -17
            ),
            bubbleView.leadingAnchor.constraint(
                greaterThanOrEqualTo: contentView.leadingAnchor,
                constant: 74
            )
        ]

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 6
            ),
            bubbleView.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -6
            ),
            bubbleView.widthAnchor.constraint(
                lessThanOrEqualTo: contentView.widthAnchor,
                multiplier: 0.82
            ),

            messageLabel.topAnchor.constraint(
                equalTo: bubbleView.topAnchor,
                constant: 9
            ),
            messageLabel.leadingAnchor.constraint(
                equalTo: bubbleView.leadingAnchor,
                constant: 10
            ),
            messageLabel.trailingAnchor.constraint(
                equalTo: bubbleView.trailingAnchor,
                constant: -10
            ),
            messageLabel.bottomAnchor.constraint(
                equalTo: bubbleView.bottomAnchor,
                constant: -9
            ),

            dotView.widthAnchor.constraint(equalToConstant: 6),
            dotView.heightAnchor.constraint(equalToConstant: 6),
            dotView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 13
            ),
            dotView.topAnchor.constraint(
                equalTo: bubbleView.topAnchor,
                constant: 18
            )
        ])
        NSLayoutConstraint.activate(assistantConstraints)
    }
}

private final class ZixyChatLoadingCell: UITableViewCell {

    static let reuseIdentifier = "ZixyChatLoadingCell"

    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Thinking..."
        label.font = ZixyFontBook.bold(size: 14)
        label.textColor = .white
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = UIColor(
            red: 32 / 255,
            green: 232 / 255,
            blue: 239 / 255,
            alpha: 1
        )
        contentView.addSubview(activityIndicator)
        contentView.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            activityIndicator.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 16
            ),
            activityIndicator.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor
            ),
            statusLabel.leadingAnchor.constraint(
                equalTo: activityIndicator.trailingAnchor,
                constant: 8
            ),
            statusLabel.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 12
            ),
            statusLabel.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -12
            )
        ])
        accessibilityLabel = "Zixy AI is preparing a reply"
    }

    required init?(coder: NSCoder) {
        nil
    }

    func startAnimating() {
        activityIndicator.startAnimating()
    }
}
