import UIKit

final class ZixySignInController: ZixyAuthCanvasController {

    enum Mode {
        case signIn
        case signUp
    }

    var onSignedIn: ((String) -> Void)?
    var onRegistrationReady: ((String, String) -> Void)?
    var onForgotPassword: (() -> Void)?

    private let emailField = ZixyAuthFieldView(
        title: "Email",
        placeholder: "Enter email address",
        assetName: "zixy_auth_email_icon",
        titleSize: 15,
        textSize: 14,
        fieldHeight: 51,
        titleHeight: 32,
        labelSpacing: 0,
        placesIconBesideTitle: true,
        fieldHorizontalInset: 15
    )
    private let passwordField = ZixyAuthFieldView(
        title: "Password",
        placeholder: "Enter password",
        assetName: "zixy_auth_password_icon",
        isSecure: true,
        titleSize: 15,
        textSize: 14,
        fieldHeight: 51,
        titleHeight: 32,
        labelSpacing: 0,
        placesIconBesideTitle: true,
        fieldHorizontalInset: 15
    )
    private let confirmationField = ZixyAuthFieldView(
        title: "Password",
        placeholder: "Please enter the password again",
        assetName: "zixy_auth_password_icon",
        isSecure: true,
        titleSize: 15,
        textSize: 14,
        fieldHeight: 51,
        titleHeight: 32,
        labelSpacing: 0,
        placesIconBesideTitle: true,
        fieldHorizontalInset: 15
    )
    private let fieldsStack = UIStackView()
    private let primaryButton = ZixyGradientActionButton(
        title: "Sign in",
        height: 74,
        titleSize: 24
    )
    private let signInTab = UIButton(type: .system)
    private let signUpTab = UIButton(type: .system)
    private let forgotButton = UIButton(type: .system)
    private let inactiveTabBackgroundView = UIView()
    private let cardBackgroundView = UIImageView()
    private let loadingOverlay = ZixyLoadingOverlay()

    private var mode: Mode
    private var isProcessing = false

    init(mode: Mode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        mode = .signIn
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.alwaysBounceVertical = false
        scrollView.bounces = false
        scrollView.showsVerticalScrollIndicator = false
        configureContent()
        applyMode()
        registerTextFields(in: view)
        view.addSubview(loadingOverlay)
        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let coveredHeight = max(
            0,
            view.bounds.maxY - primaryButton.frame.minY
        )
        if abs(minimumScrollBottomInset - coveredHeight) > 0.5 {
            minimumScrollBottomInset = coveredHeight
        }
    }

    private func configureContent() {
        let backButton = makeBackButton()
        view.addSubview(backButton)

        let logoView = UIImageView(image: ZixyImageLibrary.loginLogo)
        logoView.translatesAutoresizingMaskIntoConstraints = false
        logoView.contentMode = .scaleAspectFit

        let welcomeView = UIImageView(image: ZixyImageLibrary.loginWelcome)
        welcomeView.translatesAutoresizingMaskIntoConstraints = false
        welcomeView.contentMode = .scaleAspectFit
        welcomeView.accessibilityLabel = "Welcome to Zixy"

        [signInTab, signUpTab].forEach {
            $0.titleLabel?.font = ZixyFontBook.bold(size: 17, relativeTo: .headline)
            $0.setTitleColor(ZixyColorPalette.ink, for: .normal)
        }
        signInTab.setTitle("Sign in", for: .normal)
        signUpTab.setTitle("Sign up", for: .normal)
        signInTab.addTarget(self, action: #selector(selectSignIn), for: .touchUpInside)
        signUpTab.addTarget(self, action: #selector(selectSignUp), for: .touchUpInside)

        let tabs = UIStackView(arrangedSubviews: [signInTab, signUpTab])
        tabs.translatesAutoresizingMaskIntoConstraints = false
        tabs.axis = .horizontal
        tabs.distribution = .fillEqually

        fieldsStack.axis = .vertical
        fieldsStack.spacing = 18
        fieldsStack.translatesAutoresizingMaskIntoConstraints = false

        forgotButton.setTitle("Forgot password?", for: .normal)
        forgotButton.translatesAutoresizingMaskIntoConstraints = false
        forgotButton.titleLabel?.font = ZixyFontBook.bold(size: 12, relativeTo: .caption1)
        forgotButton.contentHorizontalAlignment = .leading
        forgotButton.addTarget(
            self,
            action: #selector(forgotPassword),
            for: .touchUpInside
        )

        primaryButton.addTarget(
            self,
            action: #selector(submit),
            for: .touchUpInside
        )

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        inactiveTabBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        inactiveTabBackgroundView.backgroundColor = UIColor(
            red: 239 / 255,
            green: 240 / 255,
            blue: 244 / 255,
            alpha: 1
        )
        inactiveTabBackgroundView.layer.cornerRadius = 28
        inactiveTabBackgroundView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner
        ]
        cardBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        cardBackgroundView.contentMode = .scaleToFill
        cardBackgroundView.isUserInteractionEnabled = false
        card.addSubview(inactiveTabBackgroundView)
        card.addSubview(cardBackgroundView)
        card.addSubview(tabs)
        card.addSubview(fieldsStack)
        card.addSubview(forgotButton)

        scrollContentView.addSubview(logoView)
        scrollContentView.addSubview(welcomeView)
        scrollContentView.addSubview(card)
        view.addSubview(primaryButton)

        let contentBottomConstraint = scrollContentView.bottomAnchor.constraint(
            equalTo: forgotButton.bottomAnchor,
            constant: 24
        )
        contentBottomConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 19
            ),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),
            logoView.topAnchor.constraint(
                equalTo: backButton.bottomAnchor,
                constant: 16
            ),
            logoView.leadingAnchor.constraint(
                equalTo: scrollContentView.leadingAnchor,
                constant: 20
            ),
            logoView.widthAnchor.constraint(equalToConstant: 90),
            logoView.heightAnchor.constraint(equalTo: logoView.widthAnchor),
            welcomeView.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 16),
            welcomeView.leadingAnchor.constraint(
                equalTo: scrollContentView.leadingAnchor,
                constant: 20
            ),
            welcomeView.widthAnchor.constraint(equalToConstant: 290),
            welcomeView.heightAnchor.constraint(equalToConstant: 58),
            card.topAnchor.constraint(equalTo: welcomeView.bottomAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: 17),
            card.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor, constant: -16),
            card.heightAnchor.constraint(equalToConstant: 360),
            contentBottomConstraint,
            inactiveTabBackgroundView.topAnchor.constraint(equalTo: card.topAnchor),
            inactiveTabBackgroundView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            inactiveTabBackgroundView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            inactiveTabBackgroundView.heightAnchor.constraint(equalToConstant: 46),
            cardBackgroundView.topAnchor.constraint(equalTo: card.topAnchor),
            cardBackgroundView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            cardBackgroundView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            cardBackgroundView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            tabs.topAnchor.constraint(equalTo: card.topAnchor, constant: 7),
            tabs.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            tabs.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            tabs.heightAnchor.constraint(equalToConstant: 42),
            fieldsStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 72),
            fieldsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            fieldsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            forgotButton.topAnchor.constraint(equalTo: fieldsStack.bottomAnchor, constant: 18),
            forgotButton.leadingAnchor.constraint(equalTo: fieldsStack.leadingAnchor),
            forgotButton.trailingAnchor.constraint(equalTo: fieldsStack.trailingAnchor),
            forgotButton.heightAnchor.constraint(equalToConstant: 24),
            primaryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            primaryButton.widthAnchor.constraint(equalToConstant: 286),
            primaryButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -10
            )
        ])
    }

    private func applyMode() {
        fieldsStack.arrangedSubviews.forEach {
            fieldsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        fieldsStack.addArrangedSubview(emailField)
        fieldsStack.addArrangedSubview(passwordField)

        let isSignUp = mode == .signUp
        if isSignUp {
            fieldsStack.addArrangedSubview(confirmationField)
        }
        confirmationField.isHidden = !isSignUp
        forgotButton.isHidden = isSignUp
        primaryButton.setTitle(isSignUp ? "Sign up" : "Sign in")
        signInTab.alpha = isSignUp ? 0.4 : 1
        signUpTab.alpha = isSignUp ? 1 : 0.4
        let image = isSignUp ? ZixyImageLibrary.loginCardSignUp : ZixyImageLibrary.loginCardSignIn
        cardBackgroundView.image = image?.resizableImage(
            withCapInsets: UIEdgeInsets(top: 60, left: 40, bottom: 40, right: 40),
            resizingMode: .stretch
        )
    }

    private func makeBackButton() -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(
            ZixyImageLibrary.authBackButton?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        button.accessibilityLabel = "Back"
        button.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        return button
    }

    @objc private func selectSignIn() {
        mode = .signIn
        applyMode()
    }

    @objc private func selectSignUp() {
        mode = .signUp
        applyMode()
    }

    @objc private func forgotPassword() {
        onForgotPassword?()
    }

    @objc private func submit() {
        guard !isProcessing else {
            return
        }
        view.endEditing(true)
        guard
            let email = emailField.textField.text?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            !email.isEmpty,
            let password = passwordField.textField.text,
            password.count >= 6
        else {
            showToast("Enter a valid email and a password with at least 6 characters.")
            return
        }

        if mode == .signUp {
            guard confirmationField.textField.text == password else {
                showToast("Passwords do not match.")
                return
            }
            guard ZixyDataStore.shared.isEmailAvailable(email) else {
                showToast("An account already exists for this email.")
                return
            }
        }

        isProcessing = true
        primaryButton.isEnabled = false
        loadingOverlay.show(
            message: mode == .signUp ? "Creating account" : "Signing in"
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else {
                return
            }
            defer {
                self.isProcessing = false
                self.primaryButton.isEnabled = true
                self.loadingOverlay.hide()
            }
            if self.mode == .signUp {
                self.onRegistrationReady?(email, password)
            } else if ZixyDataStore.shared.authenticate(
                email: email,
                password: password
            ) != nil {
                self.onSignedIn?(email)
            } else {
                self.showToast("Incorrect email or password.")
            }
        }
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }
}
