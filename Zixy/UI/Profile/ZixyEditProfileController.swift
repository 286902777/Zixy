import PhotosUI
import UIKit

final class ZixyEditProfileController: ZixyScreenController,
    PHPickerViewControllerDelegate,
    UITextFieldDelegate,
    UITextViewDelegate {

    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let avatarSize: CGFloat = 100
    }

    private let scrollView = UIScrollView()
    private let formView = UIView()
    private let avatarButton = UIButton(type: .custom)
    private let cameraButton = UIButton(type: .system)
    private let usernameField = UITextField()
    private let bioTextView = UITextView()
    private let bioPlaceholder = UILabel()
    private let saveButton = ZixyProfileSaveButton()
    private let loadingOverlay = ZixyProfileSaveLoadingView()

    private var keyboardObservers: [NSObjectProtocol] = []
    private var currentUser: ZixyUserRecord?
    private var selectedImage: UIImage?
    private var isSaving = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation(title: "Edit Profile")
        configureLayout()
        configureInputs()
        configureInteractions()
        observeKeyboard()
        loadCurrentUser()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isMovingFromParent || navigationController?.isBeingDismissed == true else {
            return
        }
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
        keyboardObservers.removeAll()
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive

        formView.translatesAutoresizingMaskIntoConstraints = false
        avatarButton.translatesAutoresizingMaskIntoConstraints = false
        avatarButton.setImage(ZixyImageLibrary.profileAvatar, for: .normal)
        avatarButton.imageView?.contentMode = .scaleAspectFill
        avatarButton.layer.cornerRadius = Layout.avatarSize / 2
        avatarButton.layer.masksToBounds = true
        avatarButton.accessibilityLabel = "Change profile photo"

        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        cameraButton.setImage(
            ZixyImageLibrary.profileCamera?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        cameraButton.accessibilityLabel = "Open photo library"

        let headingLabel = UILabel()
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        headingLabel.text = "IMPROVE YOUR PROFILE 📷"
        headingLabel.font = ZixyFontBook.bold(size: 19, relativeTo: .headline)
        headingLabel.textColor = UIColor.black.withAlphaComponent(0.9)

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "so that everyone can better understand you"
        subtitleLabel.font = ZixyFontBook.bold(size: 12, relativeTo: .caption1)
        subtitleLabel.textColor = UIColor.black.withAlphaComponent(0.85)

        let usernameLabel = makeFieldLabel("Username")
        let bioLabel = makeFieldLabel("Bio")

        usernameField.translatesAutoresizingMaskIntoConstraints = false
        usernameField.placeholder = "Enter username"
        usernameField.font = ZixyFontBook.bold(size: 16, relativeTo: .body)
        usernameField.textColor = UIColor.black.withAlphaComponent(0.82)
        usernameField.backgroundColor = .white
        usernameField.layer.cornerRadius = 13
        usernameField.leftView = UIView(
            frame: CGRect(x: 0, y: 0, width: 18, height: 1)
        )
        usernameField.leftViewMode = .always

        bioTextView.translatesAutoresizingMaskIntoConstraints = false
        bioTextView.font = ZixyFontBook.bold(size: 16, relativeTo: .body)
        bioTextView.textColor = UIColor.black.withAlphaComponent(0.82)
        bioTextView.backgroundColor = .white
        bioTextView.layer.cornerRadius = 13
        bioTextView.textContainerInset = UIEdgeInsets(
            top: 14,
            left: 13,
            bottom: 14,
            right: 13
        )

        bioPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        bioPlaceholder.text = "Tell us about yourself"
        bioPlaceholder.font = ZixyFontBook.bold(size: 16, relativeTo: .body)
        bioPlaceholder.textColor = .systemGray3

        [scrollView, saveButton].forEach(contentView.addSubview)
        scrollView.addSubview(formView)
        [
            headingLabel,
            subtitleLabel,
            avatarButton,
            cameraButton,
            usernameLabel,
            usernameField,
            bioLabel,
            bioTextView,
            bioPlaceholder
        ].forEach(formView.addSubview)
        view.addSubview(loadingOverlay)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            formView.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor
            ),
            formView.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor
            ),
            formView.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor
            ),
            formView.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor
            ),
            formView.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor
            ),

            headingLabel.topAnchor.constraint(equalTo: formView.topAnchor, constant: 10),
            headingLabel.leadingAnchor.constraint(
                equalTo: formView.leadingAnchor,
                constant: 23
            ),
            subtitleLabel.topAnchor.constraint(
                equalTo: headingLabel.bottomAnchor,
                constant: -1
            ),
            subtitleLabel.leadingAnchor.constraint(equalTo: headingLabel.leadingAnchor),

            avatarButton.topAnchor.constraint(
                equalTo: subtitleLabel.bottomAnchor,
                constant: 14
            ),
            avatarButton.leadingAnchor.constraint(
                equalTo: formView.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            avatarButton.widthAnchor.constraint(equalToConstant: Layout.avatarSize),
            avatarButton.heightAnchor.constraint(equalTo: avatarButton.widthAnchor),

            cameraButton.trailingAnchor.constraint(
                equalTo: avatarButton.trailingAnchor,
                constant: 5
            ),
            cameraButton.bottomAnchor.constraint(
                equalTo: avatarButton.bottomAnchor,
                constant: 2
            ),
            cameraButton.widthAnchor.constraint(equalToConstant: 36),
            cameraButton.heightAnchor.constraint(equalToConstant: 36),

            usernameLabel.topAnchor.constraint(
                equalTo: avatarButton.bottomAnchor,
                constant: 17
            ),
            usernameLabel.leadingAnchor.constraint(
                equalTo: formView.leadingAnchor,
                constant: 23
            ),
            usernameField.topAnchor.constraint(
                equalTo: usernameLabel.bottomAnchor,
                constant: 10
            ),
            usernameField.leadingAnchor.constraint(
                equalTo: formView.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            usernameField.trailingAnchor.constraint(
                equalTo: formView.trailingAnchor,
                constant: -18
            ),
            usernameField.heightAnchor.constraint(equalToConstant: 60),

            bioLabel.topAnchor.constraint(
                equalTo: usernameField.bottomAnchor,
                constant: 12
            ),
            bioLabel.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
            bioTextView.topAnchor.constraint(
                equalTo: bioLabel.bottomAnchor,
                constant: 10
            ),
            bioTextView.leadingAnchor.constraint(equalTo: usernameField.leadingAnchor),
            bioTextView.trailingAnchor.constraint(equalTo: usernameField.trailingAnchor),
            bioTextView.heightAnchor.constraint(equalToConstant: 182),

            bioPlaceholder.topAnchor.constraint(
                equalTo: bioTextView.topAnchor,
                constant: 15
            ),
            bioPlaceholder.leadingAnchor.constraint(
                equalTo: bioTextView.leadingAnchor,
                constant: 18
            ),

            formView.bottomAnchor.constraint(
                greaterThanOrEqualTo: bioTextView.bottomAnchor,
                constant: 112
            ),

            saveButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            saveButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -26
            ),
            saveButton.widthAnchor.constraint(equalToConstant: 286),
            saveButton.heightAnchor.constraint(equalToConstant: 74),

            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureInputs() {
        usernameField.delegate = self
        usernameField.returnKeyType = .done
        bioTextView.delegate = self
        bioTextView.inputAccessoryView = makeDoneToolbar()
    }

    private func loadCurrentUser() {
        guard let user = ZixyDataStore.shared.currentUser() else {
            currentUser = nil
            saveButton.isEnabled = false
            saveButton.alpha = 0.45
            showToast("Unable to load your profile.")
            return
        }

        currentUser = user
        usernameField.text = user.username
        bioTextView.text = user.bio
        bioPlaceholder.isHidden = !user.bio.isEmpty
        avatarButton.setImage(
            ZixyUserAvatarStore.image(for: user)
                ?? ZixyImageLibrary.profileAvatar,
            for: .normal
        )
        saveButton.isEnabled = true
        saveButton.alpha = 1
    }

    private func configureInteractions() {
        avatarButton.addTarget(
            self,
            action: #selector(presentPhotoPicker),
            for: .touchUpInside
        )
        cameraButton.addTarget(
            self,
            action: #selector(presentPhotoPicker),
            for: .touchUpInside
        )
        saveButton.addTarget(
            self,
            action: #selector(saveChanges),
            for: .touchUpInside
        )

        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        tapGesture.cancelsTouchesInView = false
        contentView.addGestureRecognizer(tapGesture)
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
            let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect,
            let duration = userInfo[
                UIResponder.keyboardAnimationDurationUserInfoKey
            ] as? TimeInterval,
            let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey]
                as? UInt
        else {
            return
        }

        let keyboardFrame = view.convert(endFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
        let bottomInset = max(0, overlap - view.safeAreaInsets.bottom)
        let options = UIView.AnimationOptions(rawValue: curve << 16)

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [options, .beginFromCurrentState],
            animations: {
                self.scrollView.contentInset.bottom = bottomInset + 90
                self.scrollView.verticalScrollIndicatorInsets.bottom =
                    bottomInset + 90
                self.view.layoutIfNeeded()
            }
        )

        guard overlap > 0 else {
            return
        }
        let responder: UIView? = usernameField.isFirstResponder
            ? usernameField
            : (bioTextView.isFirstResponder ? bioTextView : nil)
        if let responder {
            let rect = responder.convert(responder.bounds, to: scrollView)
            scrollView.scrollRectToVisible(
                rect.insetBy(dx: 0, dy: -20),
                animated: true
            )
        }
    }

    private func makeFieldLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = ZixyFontBook.bold(size: 16, relativeTo: .headline)
        label.textColor = .systemGray
        return label
    }

    private func makeDoneToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(
                barButtonSystemItem: .flexibleSpace,
                target: nil,
                action: nil
            ),
            UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(dismissKeyboard)
            )
        ]
        return toolbar
    }

    @objc private func presentPhotoPicker() {
        view.endEditing(true)
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

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
                guard let image = object as? UIImage else {
                    self?.showToast("Unable to load the selected photo.")
                    return
                }
                self?.selectedImage = image
                self?.avatarButton.setImage(image, for: .normal)
            }
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        bioPlaceholder.isHidden = !textView.text.isEmpty
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func saveChanges() {
        guard !isSaving else {
            return
        }
        view.endEditing(true)

        let username = usernameField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard (2...20).contains(username.count) else {
            showToast("Username must contain 2 to 20 characters.")
            return
        }
        let bio = bioTextView.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bio.isEmpty else {
            showToast("Enter a short bio.")
            return
        }
        guard let currentUser else {
            showToast("Unable to load your profile.")
            return
        }

        isSaving = true
        saveButton.isEnabled = false
        loadingOverlay.show()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else {
                return
            }

            var newAvatarReference: String?
            do {
                if let selectedImage {
                    newAvatarReference = try ZixyUserAvatarStore.save(
                        selectedImage
                    )
                }
                let avatarReference = newAvatarReference
                    ?? currentUser.avatarAssetName
                let updatedUser = try ZixyDataStore.shared
                    .updateCurrentUserProfile(
                        username: username,
                        bio: bio,
                        avatarAssetName: avatarReference
                    )

                if newAvatarReference != nil {
                    ZixyUserAvatarStore.remove(
                        reference: currentUser.avatarAssetName
                    )
                }
                self.currentUser = updatedUser
                self.selectedImage = nil
                NotificationCenter.default.post(
                    name: .zixyUserProfileDidChange,
                    object: updatedUser
                )
                self.finishSaving()
                self.showToast("Profile saved.")
            } catch {
                if let newAvatarReference {
                    ZixyUserAvatarStore.remove(reference: newAvatarReference)
                }
                self.finishSaving()
                self.showToast("Unable to save your profile.")
            }
        }
    }

    private func finishSaving() {
        isSaving = false
        saveButton.isEnabled = currentUser != nil
        saveButton.alpha = currentUser == nil ? 0.45 : 1
        loadingOverlay.hide()
    }
}

private final class ZixyProfileSaveButton: UIControl {

    private let gradientLayer = CAGradientLayer()
    private let titleLabel = UILabel()
    private let arrowView = UIImageView(
        image: UIImage(systemName: "chevron.right")
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 37
        layer.masksToBounds = true
        gradientLayer.colors = [
            UIColor(red: 103 / 255, green: 194 / 255, blue: 1, alpha: 1).cgColor,
            UIColor(red: 0, green: 91 / 255, blue: 1, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradientLayer, at: 0)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Save Changes"
        titleLabel.font = ZixyFontBook.bold(size: 21, relativeTo: .title3)
        titleLabel.textColor = .white

        let circle = UIView()
        circle.translatesAutoresizingMaskIntoConstraints = false
        circle.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        circle.layer.cornerRadius = 27

        arrowView.translatesAutoresizingMaskIntoConstraints = false
        arrowView.tintColor = UIColor(
            red: 15 / 255,
            green: 69 / 255,
            blue: 151 / 255,
            alpha: 1
        )
        arrowView.contentMode = .scaleAspectFit

        addSubview(titleLabel)
        addSubview(circle)
        circle.addSubview(arrowView)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 31),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            circle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            circle.centerYAnchor.constraint(equalTo: centerYAnchor),
            circle.widthAnchor.constraint(equalToConstant: 54),
            circle.heightAnchor.constraint(equalTo: circle.widthAnchor),

            arrowView.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            arrowView.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            arrowView.widthAnchor.constraint(equalToConstant: 19),
            arrowView.heightAnchor.constraint(equalToConstant: 27)
        ])
        accessibilityLabel = "Save Changes"
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

private final class ZixyProfileSaveLoadingView: UIView {

    private let spinner = UIActivityIndicatorView(style: .large)

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black.withAlphaComponent(0.22)
        isHidden = true

        let panel = UIView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = UIColor.white.withAlphaComponent(0.96)
        panel.layer.cornerRadius = 18

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .systemBlue

        addSubview(panel)
        panel.addSubview(spinner)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 82),
            panel.heightAnchor.constraint(equalToConstant: 82),
            spinner.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: panel.centerYAnchor)
        ])
        accessibilityLabel = "Saving profile"
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        isHidden = false
        spinner.startAnimating()
    }

    func hide() {
        spinner.stopAnimating()
        isHidden = true
    }
}
