import UIKit

final class ZixyGatewayController: ZixyAuthCanvasController, UITextViewDelegate {

    private static let termsAcceptanceDefaultsKey =
        "zixy_gateway_terms_accepted"

    var onLoginByEmail: (() -> Void)?
    var onGuestAccess: (() -> Void)?
    var onSignUp: (() -> Void)?
    private var hasAcceptedTerms = UserDefaults.standard.bool(
        forKey: ZixyGatewayController.termsAcceptanceDefaultsKey
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        configureBackground()
        configureContent()
    }

    private func configureBackground() {
        let backgroundView = UIImageView(image: ZixyImageLibrary.authEntryBackground)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.contentMode = .scaleAspectFill
        backgroundView.clipsToBounds = true
        backgroundView.isUserInteractionEnabled = false

        view.insertSubview(backgroundView, belowSubview: scrollView)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureContent() {
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Handcraft Community"
        subtitleLabel.font = ZixyFontBook.bold(size: 20, relativeTo: .title3)
        subtitleLabel.textColor = UIColor(
            red: 20 / 255,
            green: 82 / 255,
            blue: 111 / 255,
            alpha: 1
        )
        subtitleLabel.textAlignment = .center

        let loginButton = AuthEntryActionButton(
            title: "Sign in by email",
            titleCenterOffset: 8,
            reversesGradient: false
        )
        loginButton.addTarget(
            self,
            action: #selector(loginByEmail),
            for: .touchUpInside
        )

        let newUserButton = AuthEntryActionButton(
            title: "I'm new",
            titleCenterOffset: -18,
            reversesGradient: true
        )
        newUserButton.addTarget(
            self,
            action: #selector(newUser),
            for: .touchUpInside
        )

        let accountButton = UIButton(type: .custom)
        accountButton.translatesAutoresizingMaskIntoConstraints = false
        accountButton.setAttributedTitle(makeAccountTitle(), for: .normal)
        accountButton.accessibilityLabel = "Sign up"
        accountButton.addTarget(
            self,
            action: #selector(signUp),
            for: .touchUpInside
        )

        let termsButton = TermsSelectionButton()
        termsButton.translatesAutoresizingMaskIntoConstraints = false
        termsButton.accessibilityLabel = "Accept terms"
        termsButton.isSelected = hasAcceptedTerms
        termsButton.accessibilityValue = hasAcceptedTerms
            ? "Selected"
            : "Not selected"
        termsButton.addTarget(
            self,
            action: #selector(toggleTerms),
            for: .touchUpInside
        )

        let termsLabel = UITextView()
        termsLabel.translatesAutoresizingMaskIntoConstraints = false
        termsLabel.attributedText = makeTermsTitle()
        termsLabel.backgroundColor = .clear
        termsLabel.textAlignment = .center
        termsLabel.isEditable = false
        termsLabel.isScrollEnabled = false
        termsLabel.isSelectable = true
        termsLabel.delegate = self
        termsLabel.textContainerInset = .zero
        termsLabel.textContainer.lineFragmentPadding = 0
        termsLabel.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        termsLabel.accessibilityLabel = "User Agreement and Privacy Policy"

        let termsRow = UIStackView(arrangedSubviews: [termsButton, termsLabel])
        termsRow.translatesAutoresizingMaskIntoConstraints = false
        termsRow.axis = .horizontal
        termsRow.alignment = .center
        termsRow.spacing = 8

        [subtitleLabel, loginButton, newUserButton, accountButton, termsRow]
            .forEach(view.addSubview)

        let subtitleCenterY = NSLayoutConstraint(
            item: subtitleLabel,
            attribute: .centerY,
            relatedBy: .equal,
            toItem: view,
            attribute: .bottom,
            multiplier: 0.49,
            constant: 0
        )
        let loginCenterY = NSLayoutConstraint(
            item: loginButton,
            attribute: .centerY,
            relatedBy: .equal,
            toItem: view,
            attribute: .bottom,
            multiplier: 0.615,
            constant: 0
        )
        let newUserCenterY = NSLayoutConstraint(
            item: newUserButton,
            attribute: .centerY,
            relatedBy: .equal,
            toItem: view,
            attribute: .bottom,
            multiplier: 0.735,
            constant: 0
        )
        let accountCenterY = NSLayoutConstraint(
            item: accountButton,
            attribute: .centerY,
            relatedBy: .equal,
            toItem: view,
            attribute: .bottom,
            multiplier: 0.84,
            constant: 0
        )

        NSLayoutConstraint.activate([
            subtitleCenterY,
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            loginCenterY,
            loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -44),
            loginButton.widthAnchor.constraint(equalToConstant: 286),
            loginButton.heightAnchor.constraint(equalToConstant: 72),

            newUserCenterY,
            newUserButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 185),
            newUserButton.widthAnchor.constraint(equalToConstant: 286),
            newUserButton.heightAnchor.constraint(equalToConstant: 72),

            accountCenterY,
            accountButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            accountButton.heightAnchor.constraint(equalToConstant: 44),

            termsRow.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            termsRow.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor,
                constant: 20
            ),
            termsRow.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: -20
            ),
            termsRow.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -20
            ),
            termsButton.widthAnchor.constraint(equalToConstant: 12),
            termsButton.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    private func makeAccountTitle() -> NSAttributedString {
        let text = "Don't have an account? Sign up"
        let title = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: ZixyFontBook.bold(size: 14, relativeTo: .subheadline),
                .foregroundColor: UIColor(
                    red: 20 / 255,
                    green: 82 / 255,
                    blue: 111 / 255,
                    alpha: 1
                )
            ]
        )
        let signUpRange = (text as NSString).range(of: "Sign up")
        title.addAttributes(
            [
                .foregroundColor: UIColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ],
            range: signUpRange
        )
        return title
    }

    private func makeTermsTitle() -> NSAttributedString {
        let text = "By continuing you agree to our User Agreement and\nPrivacy Policy"
        let title = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: ZixyFontBook.bold(size: 9, relativeTo: .caption2),
                .foregroundColor: UIColor(
                    red: 20 / 255,
                    green: 82 / 255,
                    blue: 111 / 255,
                    alpha: 1
                )
            ]
        )
        let agreementRange = (text as NSString).range(of: "User Agreement")
        title.addAttribute(
            .link,
            value: ZixyWebController.H5Page.userAgreement.urlString,
            range: agreementRange
        )
        let privacyRange = (text as NSString).range(of: "Privacy Policy")
        title.addAttribute(
            .link,
            value: ZixyWebController.H5Page.privacyPolicy.urlString,
            range: privacyRange
        )
        return title
    }

    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        let page: ZixyWebController.H5Page
        switch URL.absoluteString {
        case ZixyWebController.H5Page.userAgreement.urlString:
            page = .userAgreement
        case ZixyWebController.H5Page.privacyPolicy.urlString:
            page = .privacyPolicy
        default:
            return false
        }
        navigationController?.pushViewController(
            ZixyWebController(page: page),
            animated: true
        )
        return false
    }

    @objc private func loginByEmail() {
        guard validateTermsAcceptance() else {
            return
        }
        onLoginByEmail?()
    }

    @objc private func newUser() {
        guard validateTermsAcceptance() else {
            return
        }
        onGuestAccess?()
    }

    @objc private func signUp() {
        guard validateTermsAcceptance() else {
            return
        }
        onSignUp?()
    }

    @objc private func toggleTerms(_ sender: UIButton) {
        sender.isSelected.toggle()
        hasAcceptedTerms = sender.isSelected
        UserDefaults.standard.set(
            hasAcceptedTerms,
            forKey: Self.termsAcceptanceDefaultsKey
        )
        sender.accessibilityValue = sender.isSelected ? "Selected" : "Not selected"
    }

    private func validateTermsAcceptance() -> Bool {
        guard hasAcceptedTerms else {
            showToast(
                "Please agree to the User Agreement and Privacy Policy first."
            )
            return false
        }
        return true
    }
}

private final class TermsSelectionButton: UIButton {

    private let centerFillView = UIView()

    override var isSelected: Bool {
        didSet {
            centerFillView.isHidden = !isSelected
        }
    }

    init() {
        super.init(frame: .zero)
        setImage(
            ZixyImageLibrary.termsCheckboxUnselected?.withRenderingMode(
                .alwaysOriginal
            ),
            for: .normal
        )
        imageView?.contentMode = .center

        centerFillView.translatesAutoresizingMaskIntoConstraints = false
        centerFillView.backgroundColor = UIColor(
            red: 18 / 255,
            green: 102 / 255,
            blue: 1,
            alpha: 1
        )
        centerFillView.layer.cornerRadius = 3
        centerFillView.isHidden = true
        centerFillView.isUserInteractionEnabled = false
        insertSubview(centerFillView, at: 0)
        NSLayoutConstraint.activate([
            centerFillView.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerFillView.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerFillView.widthAnchor.constraint(equalToConstant: 6),
            centerFillView.heightAnchor.constraint(equalTo: centerFillView.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class AuthEntryActionButton: UIControl {

    private let gradientLayer = CAGradientLayer()

    init(
        title: String,
        titleCenterOffset: CGFloat,
        reversesGradient: Bool
    ) {
        super.init(frame: .zero)
        configure(
            title: title,
            titleCenterOffset: titleCenterOffset,
            reversesGradient: reversesGradient
        )
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure(title: "", titleCenterOffset: 0, reversesGradient: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = bounds.height / 2
    }

    private func configure(
        title: String,
        titleCenterOffset: CGFloat,
        reversesGradient: Bool
    ) {
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
        layer.insertSublayer(gradientLayer, at: 0)
        gradientLayer.colors = [
            UIColor(
                red: 90 / 255,
                green: 190 / 255,
                blue: 1,
                alpha: 1
            ).cgColor,
            UIColor(
                red: 18 / 255,
                green: 102 / 255,
                blue: 1,
                alpha: 1
            ).cgColor
        ]
        gradientLayer.startPoint = CGPoint(
            x: reversesGradient ? 1 : 0,
            y: 0.5
        )
        gradientLayer.endPoint = CGPoint(
            x: reversesGradient ? 0 : 1,
            y: 0.5
        )

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = ZixyFontBook.bold(size: 24, relativeTo: .title3)
        titleLabel.textColor = .white
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(
                equalTo: centerXAnchor,
                constant: titleCenterOffset
            ),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        accessibilityTraits = .button
        accessibilityLabel = title
    }
}
