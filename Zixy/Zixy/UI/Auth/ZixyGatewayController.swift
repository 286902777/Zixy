import UIKit

final class ZixyGatewayController: ZixyAuthCanvasController {

    var onLoginByEmail: (() -> Void)?
    var onNewUser: (() -> Void)?

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
            title: "Login by email",
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
            action: #selector(newUser),
            for: .touchUpInside
        )

        let termsButton = UIButton(type: .custom)
        termsButton.translatesAutoresizingMaskIntoConstraints = false
        termsButton.setImage(
            ZixyImageLibrary.termsCheckboxUnselected?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        termsButton.setImage(
            UIImage(systemName: "checkmark.circle.fill")?.withTintColor(
                .white,
                renderingMode: .alwaysOriginal
            ),
            for: .selected
        )
        termsButton.imageView?.contentMode = .center
        termsButton.accessibilityLabel = "Accept terms"
        termsButton.addTarget(
            self,
            action: #selector(toggleTerms),
            for: .touchUpInside
        )

        let termsLabel = UILabel()
        termsLabel.attributedText = makeTermsTitle()
        termsLabel.numberOfLines = 2
        termsLabel.textAlignment = .center
        termsLabel.adjustsFontSizeToFitWidth = true
        termsLabel.minimumScaleFactor = 0.8

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
        let text = "By continuing you agree to our Terms of Service and\nPrivacy Policy"
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
        ["Terms of Service", "Privacy Policy"].forEach { linkText in
            let range = (text as NSString).range(of: linkText)
            title.addAttributes(
                [
                    .foregroundColor: UIColor.systemBlue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ],
                range: range
            )
        }
        return title
    }

    @objc private func loginByEmail() {
        onLoginByEmail?()
    }

    @objc private func newUser() {
        onNewUser?()
    }

    @objc private func toggleTerms(_ sender: UIButton) {
        sender.isSelected.toggle()
        sender.accessibilityValue = sender.isSelected ? "Selected" : "Not selected"
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
