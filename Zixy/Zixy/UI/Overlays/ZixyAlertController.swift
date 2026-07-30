import UIKit

final class ZixyAlertController: UIViewController {

    enum Kind {
        case blockUser
        case connectToChat
        case loginRequired
        case insufficientCoins
        case deleteAccount

        fileprivate var title: String {
            switch self {
            case .blockUser, .deleteAccount:
                return "Are You Sure"
            case .connectToChat:
                return "Connect to\nChat"
            case .loginRequired, .insufficientCoins:
                return "Hint"
            }
        }

        fileprivate var message: String {
            switch self {
            case .blockUser:
                return """
                You want to block this user and
                stop receiving all information and
                dynamic content related to them?
                """
            case .connectToChat:
                return """
                Follow each other to unlock
                messages.
                """
            case .loginRequired:
                return """
                To ensure the normal operation of
                the function, please log in to your
                account first.
                """
            case .insufficientCoins:
                return """
                You don’t have enough Coins to
                continue. Would you like to
                recharge now?
                """
            case .deleteAccount:
                return """
                You want to delete this account?
                All data will be permanently
                cleared and cannot be recovered.
                Please choose carefully.
                """
            }
        }

        fileprivate var primaryTitle: String {
            switch self {
            case .connectToChat:
                return "OK"
            case .loginRequired:
                return "Log in"
            case .insufficientCoins:
                return "Agree"
            case .blockUser, .deleteAccount:
                return "Sure"
            }
        }

        fileprivate var cancelTitle: String? {
            self == .connectToChat ? nil : "Cancel"
        }

        fileprivate var panelHeight: CGFloat {
            switch self {
            case .connectToChat:
                return 272
            case .deleteAccount:
                return 314
            case .blockUser, .loginRequired, .insufficientCoins:
                return 292
            }
        }
    }

    var onPrimaryAction: (() -> Void)?
    var onCancel: (() -> Void)?

    private let kind: Kind
    private let dimmingView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        return view
    }()
    private let panelView: UIImageView = {
        let image = ZixyImageLibrary.alertPanelBackground?.resizableImage(
            withCapInsets: UIEdgeInsets(
                top: 125,
                left: 80,
                bottom: 90,
                right: 80
            ),
            resizingMode: .stretch
        )
        let view = UIImageView(image: image)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.contentMode = .scaleToFill
        return view
    }()
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ZixyFontBook.bold(size: 29, relativeTo: .title1)
        label.textColor = .black
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ZixyFontBook.bold(size: 17, relativeTo: .body)
        label.textColor = UIColor.black.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.84
        return label
    }()
    private let cancelButton = ZixyAlertActionButton(style: .cancel)
    private let primaryButton = ZixyAlertActionButton(style: .primary)
    private let buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 8
        return stack
    }()

    init(kind: Kind) {
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureContent()
        configureLayout()
        configureInteractions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        panelView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        panelView.alpha = 0
        UIView.animate(
            withDuration: 0.22,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: {
                self.panelView.transform = .identity
                self.panelView.alpha = 1
            }
        )
    }

    private func configureContent() {
        titleLabel.text = kind.title
        messageLabel.text = kind.message
        primaryButton.setTitle(kind.primaryTitle)
        if let cancelTitle = kind.cancelTitle {
            cancelButton.setTitle(cancelTitle)
            buttonStack.addArrangedSubview(cancelButton)
        }
        buttonStack.addArrangedSubview(primaryButton)
    }

    private func configureLayout() {
        view.backgroundColor = .clear
        view.addSubview(dimmingView)
        view.addSubview(panelView)
        panelView.addSubview(titleLabel)
        panelView.addSubview(messageLabel)
        panelView.addSubview(buttonStack)

        let stackWidthConstraint: NSLayoutConstraint
        if kind.cancelTitle == nil {
            stackWidthConstraint = buttonStack.widthAnchor.constraint(
                equalToConstant: 196
            )
        } else {
            stackWidthConstraint = buttonStack.leadingAnchor.constraint(
                equalTo: panelView.leadingAnchor,
                constant: 15
            )
        }

        var constraints = [
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            panelView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            panelView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            panelView.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor,
                constant: 17
            ),
            panelView.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: -17
            ),
            panelView.widthAnchor.constraint(equalToConstant: 340),
            panelView.heightAnchor.constraint(equalToConstant: kind.panelHeight),

            titleLabel.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 39),
            titleLabel.leadingAnchor.constraint(
                equalTo: panelView.leadingAnchor,
                constant: 26
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: panelView.trailingAnchor,
                constant: -26
            ),

            messageLabel.leadingAnchor.constraint(
                equalTo: panelView.leadingAnchor,
                constant: 27
            ),
            messageLabel.trailingAnchor.constraint(
                equalTo: panelView.trailingAnchor,
                constant: -27
            ),
            messageLabel.bottomAnchor.constraint(
                equalTo: buttonStack.topAnchor,
                constant: -25
            ),

            buttonStack.centerXAnchor.constraint(equalTo: panelView.centerXAnchor),
            buttonStack.bottomAnchor.constraint(
                equalTo: panelView.bottomAnchor,
                constant: -20
            ),
            buttonStack.heightAnchor.constraint(equalToConstant: 39),
            stackWidthConstraint
        ]
        if kind.cancelTitle != nil {
            constraints.append(
                buttonStack.trailingAnchor.constraint(
                    equalTo: panelView.trailingAnchor,
                    constant: -15
                )
            )
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func configureInteractions() {
        cancelButton.addTarget(
            self,
            action: #selector(cancel),
            for: .touchUpInside
        )
        primaryButton.addTarget(
            self,
            action: #selector(performPrimaryAction),
            for: .touchUpInside
        )
    }

    @objc private func cancel() {
        let action = onCancel
        dismiss(animated: true, completion: action)
    }

    @objc private func performPrimaryAction() {
        let action = onPrimaryAction
        dismiss(animated: true, completion: action)
    }
}

private final class ZixyAlertActionButton: UIControl {

    enum Style {
        case cancel
        case primary
    }

    private let gradientLayer = CAGradientLayer()
    private let titleLabel = UILabel()
    private let arrowBackgroundView = UIView()
    private let arrowImageView = UIImageView()

    init(style: Style) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        configure(style: style)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.72 : 1
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = bounds.height / 2
    }

    func setTitle(_ title: String) {
        titleLabel.text = title
        accessibilityLabel = title
    }

    private func configure(style: Style) {
        layer.insertSublayer(gradientLayer, at: 0)
        layer.cornerRadius = 19.5
        clipsToBounds = true
        accessibilityTraits = .button

        switch style {
        case .cancel:
            gradientLayer.colors = [
                UIColor(red: 112 / 255, green: 196 / 255, blue: 1, alpha: 1).cgColor,
                UIColor(red: 27 / 255, green: 111 / 255, blue: 1, alpha: 1).cgColor
            ]
            arrowImageView.tintColor = UIColor(
                red: 17 / 255,
                green: 91 / 255,
                blue: 220 / 255,
                alpha: 1
            )
        case .primary:
            gradientLayer.colors = [
                UIColor(red: 1, green: 102 / 255, blue: 201 / 255, alpha: 1).cgColor,
                UIColor(red: 241 / 255, green: 0, blue: 124 / 255, alpha: 1).cgColor
            ]
            arrowImageView.tintColor = UIColor(
                red: 210 / 255,
                green: 0,
                blue: 91 / 255,
                alpha: 1
            )
        }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = ZixyFontBook.bold(size: 16, relativeTo: .headline)
        titleLabel.textColor = .white
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.isUserInteractionEnabled = false

        arrowBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        arrowBackgroundView.backgroundColor = UIColor.white.withAlphaComponent(0.93)
        arrowBackgroundView.layer.cornerRadius = 15
        arrowBackgroundView.isUserInteractionEnabled = false

        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.image = UIImage(
            systemName: "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: 14,
                weight: .black
            )
        )
        arrowImageView.contentMode = .scaleAspectFit

        addSubview(titleLabel)
        addSubview(arrowBackgroundView)
        arrowBackgroundView.addSubview(arrowImageView)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: arrowBackgroundView.leadingAnchor,
                constant: -6
            ),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            arrowBackgroundView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -4
            ),
            arrowBackgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),
            arrowBackgroundView.widthAnchor.constraint(equalToConstant: 30),
            arrowBackgroundView.heightAnchor.constraint(equalToConstant: 30),

            arrowImageView.centerXAnchor.constraint(
                equalTo: arrowBackgroundView.centerXAnchor
            ),
            arrowImageView.centerYAnchor.constraint(
                equalTo: arrowBackgroundView.centerYAnchor
            ),
            arrowImageView.widthAnchor.constraint(equalToConstant: 12),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
}
