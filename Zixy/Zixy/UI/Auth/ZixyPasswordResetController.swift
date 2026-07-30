import UIKit

final class ZixyPasswordResetController: ZixyAuthCanvasController {

    var onCompleted: (() -> Void)?
    private let loadingOverlay = ZixyLoadingOverlay()
    private var isSaving = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureContent()
        registerTextFields(in: view)
        view.addSubview(loadingOverlay)
        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureContent() {
        let backButton = UIButton(type: .system)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setImage(
            ZixyImageLibrary.authBackButton?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        backButton.accessibilityLabel = "Back"
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        view.addSubview(backButton)

        let logoView = UIImageView(image: ZixyImageLibrary.logo)
        logoView.translatesAutoresizingMaskIntoConstraints = false
        logoView.contentMode = .scaleAspectFit
        logoView.layer.cornerRadius = 18
        logoView.clipsToBounds = true

        let welcomeView = UIImageView(image: ZixyImageLibrary.loginWelcome)
        welcomeView.translatesAutoresizingMaskIntoConstraints = false
        welcomeView.contentMode = .scaleAspectFit
        welcomeView.accessibilityLabel = "Welcome to Zixy"

        let email = ZixyAuthFieldView(
            title: "Email",
            placeholder: "Enter email address",
            assetName: "zixy_auth_email_icon"
        )
        let password = ZixyAuthFieldView(
            title: "Password",
            placeholder: "Enter password",
            assetName: "zixy_auth_password_icon",
            isSecure: true
        )
        let confirmation = ZixyAuthFieldView(
            title: "Password",
            placeholder: "Please enter the password again",
            assetName: "zixy_auth_password_icon",
            isSecure: true
        )
        password.textField.tag = 1
        confirmation.textField.tag = 2

        let saveButton = ZixyGradientActionButton(title: "Save")
        saveButton.addAction(
            UIAction { [
                weak self,
                weak email,
                weak password,
                weak confirmation,
                weak saveButton
            ] _ in
                guard let self else {
                    return
                }
                guard !self.isSaving else {
                    return
                }
                let emailText = email?.textField.text ?? ""
                let passwordText = password?.textField.text ?? ""
                let confirmationText = confirmation?.textField.text ?? ""
                guard !emailText.isEmpty, passwordText.count >= 6 else {
                    self.showToast("Complete all fields with a valid password.")
                    return
                }
                guard passwordText == confirmationText else {
                    self.showToast("Passwords do not match.")
                    return
                }
                self.view.endEditing(true)
                self.isSaving = true
                saveButton?.isEnabled = false
                self.loadingOverlay.show(message: "Saving password")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.isSaving = false
                    saveButton?.isEnabled = true
                    self.loadingOverlay.hide()
                    self.showToast("Password updated.")
                    self.onCompleted?()
                }
            },
            for: .touchUpInside
        )

        let cardTitle = UILabel()
        cardTitle.translatesAutoresizingMaskIntoConstraints = false
        cardTitle.text = "Forgot password"
        cardTitle.font = ZixyFontBook.bold(size: 14, relativeTo: .subheadline)
        cardTitle.textAlignment = .center

        let fields = UIStackView(arrangedSubviews: [email, password, confirmation])
        fields.translatesAutoresizingMaskIntoConstraints = false
        fields.axis = .vertical
        fields.spacing = 14

        let cardBackground = UIImageView(
            image: ZixyImageLibrary.loginCardSignIn?.resizableImage(
                withCapInsets: UIEdgeInsets(top: 60, left: 40, bottom: 40, right: 40),
                resizingMode: .stretch
            )
        )
        cardBackground.translatesAutoresizingMaskIntoConstraints = false
        cardBackground.contentMode = .scaleToFill
        cardBackground.isUserInteractionEnabled = false

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardBackground)
        card.addSubview(cardTitle)
        card.addSubview(fields)
        card.addSubview(saveButton)

        scrollContentView.addSubview(logoView)
        scrollContentView.addSubview(welcomeView)
        scrollContentView.addSubview(card)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),
            logoView.topAnchor.constraint(
                equalTo: scrollContentView.safeAreaLayoutGuide.topAnchor,
                constant: 54
            ),
            logoView.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: 20),
            logoView.widthAnchor.constraint(equalToConstant: 62),
            logoView.heightAnchor.constraint(equalToConstant: 62),
            welcomeView.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 13),
            welcomeView.leadingAnchor.constraint(
                equalTo: scrollContentView.leadingAnchor,
                constant: 20
            ),
            welcomeView.widthAnchor.constraint(equalToConstant: 290),
            welcomeView.heightAnchor.constraint(equalToConstant: 58),
            card.topAnchor.constraint(equalTo: welcomeView.bottomAnchor, constant: 22),
            card.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor, constant: -16),
            card.heightAnchor.constraint(equalToConstant: 565),
            card.bottomAnchor.constraint(equalTo: scrollContentView.bottomAnchor),
            cardBackground.topAnchor.constraint(equalTo: card.topAnchor),
            cardBackground.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            cardBackground.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            cardBackground.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            cardTitle.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),
            cardTitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            cardTitle.widthAnchor.constraint(equalToConstant: 145),
            fields.topAnchor.constraint(equalTo: card.topAnchor, constant: 68),
            fields.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            fields.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            saveButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            saveButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            saveButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24)
        ])
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }
}
