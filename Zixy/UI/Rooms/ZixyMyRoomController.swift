import PhotosUI
import UIKit

final class ZixyMyRoomController: ZixyScreenController {

    enum Mode {
        case create
        case edit
    }

    private enum Layout {
        static let horizontalInset: CGFloat = 19
        static let coverWidth: CGFloat = 208
        static let coverHeight: CGFloat = 270
        static let saveButtonWidth: CGFloat = 286
        static let saveButtonHeight: CGFloat = 74
    }

    private var mode: Mode
    private var room: ZixyRoomRecord?
    private var selectedCover: UIImage?
    private var selectedCoverReference: String?
    private var selectedCoverIsNew = false
    private var keyboardObservers: [NSObjectProtocol] = []
    private var isProcessing = false

    private let scrollView = UIScrollView()
    private let formView = UIView()
    private let coverButton = UIButton(type: .custom)
    private let placeholderView = UIView()
    private let removeCoverButton = UIButton(type: .custom)
    private let roomNameField = UITextField()
    private let deleteButton = UIButton(type: .custom)
    private let saveButton = ZixyGradientActionButton(
        title: "Save Changes",
        height: Layout.saveButtonHeight,
        titleSize: 20
    )
    private let loadingView = ZixyMyRoomLoadingView()

    init() {
        let ownedRoom = ZixyDataStore.shared.ownedRoom(
            for: ZixySessionStore.currentUserIdentifier
        )
        room = ownedRoom
        mode = ownedRoom == nil ? .create : .edit
        selectedCoverReference = ownedRoom?.coverAssetName
        selectedCover = ownedRoom.flatMap {
            ZixyRoomCoverStore.image(reference: $0.coverAssetName)
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureDeleteButton()
        configureNavigation(
            title: "My Room",
            rightView: mode == .edit ? deleteButton : nil
        )
        configureLayout()
        configureCoverPlaceholder()
        configureInputs()
        configureInteractions()
        observeKeyboard()
        applyMode()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isMovingFromParent || navigationController?.isBeingDismissed == true else {
            return
        }
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
        keyboardObservers.removeAll()
    }

    private func configureDeleteButton() {
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.setImage(
            ZixyImageLibrary.myRoomDelete?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        deleteButton.accessibilityLabel = "Delete room"
        NSLayoutConstraint.activate([
            deleteButton.widthAnchor.constraint(equalToConstant: 40),
            deleteButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive

        formView.translatesAutoresizingMaskIntoConstraints = false
        coverButton.translatesAutoresizingMaskIntoConstraints = false
        coverButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        coverButton.imageView?.contentMode = .scaleAspectFill
        coverButton.layer.cornerRadius = 22
        coverButton.layer.masksToBounds = true
        coverButton.accessibilityLabel = "Choose room cover"

        removeCoverButton.translatesAutoresizingMaskIntoConstraints = false
        removeCoverButton.setImage(
            ZixyImageLibrary.myRoomRemoveCover?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        removeCoverButton.accessibilityLabel = "Remove room cover"

        let roomNameLabel = UILabel()
        roomNameLabel.translatesAutoresizingMaskIntoConstraints = false
        roomNameLabel.text = "Room Name"
        roomNameLabel.font = ZixyFontBook.bold(size: 16, relativeTo: .headline)
        roomNameLabel.textColor = UIColor.black.withAlphaComponent(0.34)

        roomNameField.translatesAutoresizingMaskIntoConstraints = false
        roomNameField.backgroundColor = .white
        roomNameField.layer.cornerRadius = 14
        roomNameField.font = ZixyFontBook.bold(size: 16, relativeTo: .body)
        roomNameField.textColor = UIColor.black.withAlphaComponent(0.78)
        roomNameField.attributedPlaceholder = NSAttributedString(
            string: "Enter a pleasant room name",
            attributes: [
                .foregroundColor: UIColor.black.withAlphaComponent(0.24),
                .font: ZixyFontBook.bold(size: 16, relativeTo: .body)
            ]
        )
        roomNameField.leftView = UIView(
            frame: CGRect(x: 0, y: 0, width: 19, height: 1)
        )
        roomNameField.leftViewMode = .always
        roomNameField.clearButtonMode = .whileEditing
        roomNameField.returnKeyType = .done

        [scrollView, saveButton].forEach(contentView.addSubview)
        scrollView.addSubview(formView)
        [coverButton, removeCoverButton, roomNameLabel, roomNameField]
            .forEach(formView.addSubview)
        view.addSubview(loadingView)

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

            coverButton.topAnchor.constraint(equalTo: formView.topAnchor, constant: 21),
            coverButton.centerXAnchor.constraint(equalTo: formView.centerXAnchor),
            coverButton.widthAnchor.constraint(equalToConstant: Layout.coverWidth),
            coverButton.heightAnchor.constraint(equalToConstant: Layout.coverHeight),

            removeCoverButton.trailingAnchor.constraint(
                equalTo: coverButton.trailingAnchor
            ),
            removeCoverButton.bottomAnchor.constraint(
                equalTo: coverButton.bottomAnchor
            ),
            removeCoverButton.widthAnchor.constraint(equalToConstant: 35),
            removeCoverButton.heightAnchor.constraint(equalToConstant: 35),

            roomNameLabel.topAnchor.constraint(
                equalTo: coverButton.bottomAnchor,
                constant: 33
            ),
            roomNameLabel.leadingAnchor.constraint(
                equalTo: formView.leadingAnchor,
                constant: 23
            ),
            roomNameField.topAnchor.constraint(
                equalTo: roomNameLabel.bottomAnchor,
                constant: 11
            ),
            roomNameField.leadingAnchor.constraint(
                equalTo: formView.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            roomNameField.trailingAnchor.constraint(
                equalTo: formView.trailingAnchor,
                constant: -18
            ),
            roomNameField.heightAnchor.constraint(equalToConstant: 60),
            formView.bottomAnchor.constraint(
                greaterThanOrEqualTo: roomNameField.bottomAnchor,
                constant: 150
            ),

            saveButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            saveButton.widthAnchor.constraint(
                equalToConstant: Layout.saveButtonWidth
            ),
            saveButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -7
            ),

            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureCoverPlaceholder() {
        placeholderView.translatesAutoresizingMaskIntoConstraints = false
        placeholderView.isUserInteractionEnabled = false

        let photoIcon = UIImageView(
            image: UIImage(
                systemName: "photo",
                withConfiguration: UIImage.SymbolConfiguration(
                    pointSize: 48,
                    weight: .bold
                )
            )
        )
        photoIcon.translatesAutoresizingMaskIntoConstraints = false
        photoIcon.tintColor = .black
        photoIcon.contentMode = .scaleAspectFit

        let plusIcon = UIImageView(
            image: UIImage(
                systemName: "plus.circle.fill",
                withConfiguration: UIImage.SymbolConfiguration(
                    pointSize: 36,
                    weight: .bold
                )
            )
        )
        plusIcon.translatesAutoresizingMaskIntoConstraints = false
        plusIcon.tintColor = UIColor.black.withAlphaComponent(0.92)
        plusIcon.backgroundColor = .white
        plusIcon.layer.cornerRadius = 18

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Choose a nice\nphoto as the cover"
        titleLabel.font = ZixyFontBook.bold(size: 18, relativeTo: .headline)
        titleLabel.textColor = UIColor.black.withAlphaComponent(0.9)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "A good cover can attract more\npeople"
        subtitleLabel.font = ZixyFontBook.bold(size: 12, relativeTo: .caption1)
        subtitleLabel.textColor = UIColor.black.withAlphaComponent(0.34)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2

        coverButton.addSubview(placeholderView)
        [photoIcon, plusIcon, titleLabel, subtitleLabel]
            .forEach(placeholderView.addSubview)
        NSLayoutConstraint.activate([
            placeholderView.topAnchor.constraint(equalTo: coverButton.topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: coverButton.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: coverButton.trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: coverButton.bottomAnchor),
            photoIcon.topAnchor.constraint(
                equalTo: placeholderView.topAnchor,
                constant: 58
            ),
            photoIcon.centerXAnchor.constraint(equalTo: placeholderView.centerXAnchor),
            photoIcon.widthAnchor.constraint(equalToConstant: 64),
            photoIcon.heightAnchor.constraint(equalToConstant: 64),
            plusIcon.centerXAnchor.constraint(
                equalTo: photoIcon.trailingAnchor,
                constant: -5
            ),
            plusIcon.centerYAnchor.constraint(
                equalTo: photoIcon.topAnchor,
                constant: 8
            ),
            plusIcon.widthAnchor.constraint(equalToConstant: 36),
            plusIcon.heightAnchor.constraint(equalToConstant: 36),
            titleLabel.topAnchor.constraint(equalTo: photoIcon.bottomAnchor, constant: 27),
            titleLabel.leadingAnchor.constraint(
                equalTo: placeholderView.leadingAnchor,
                constant: 12
            ),
            titleLabel.trailingAnchor.constraint(
                equalTo: placeholderView.trailingAnchor,
                constant: -12
            ),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 9),
            subtitleLabel.leadingAnchor.constraint(
                equalTo: placeholderView.leadingAnchor,
                constant: 8
            ),
            subtitleLabel.trailingAnchor.constraint(
                equalTo: placeholderView.trailingAnchor,
                constant: -8
            )
        ])
    }

    private func configureInputs() {
        roomNameField.delegate = self
    }

    private func configureInteractions() {
        coverButton.addTarget(
            self,
            action: #selector(openPhotoLibrary),
            for: .touchUpInside
        )
        removeCoverButton.addTarget(
            self,
            action: #selector(removeCover),
            for: .touchUpInside
        )
        deleteButton.addTarget(
            self,
            action: #selector(deleteRoom),
            for: .touchUpInside
        )
        saveButton.addTarget(
            self,
            action: #selector(saveChanges),
            for: .touchUpInside
        )
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        tap.cancelsTouchesInView = false
        contentView.addGestureRecognizer(tap)
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
            let info = notification.userInfo,
            let endFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
            let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey]
                as? TimeInterval,
            let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else {
            return
        }
        let keyboardFrame = view.convert(endFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
        let inset = max(0, overlap - view.safeAreaInsets.bottom)
        let options = UIView.AnimationOptions(rawValue: curve << 16)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [options, .beginFromCurrentState]
        ) {
            self.scrollView.contentInset.bottom = inset + 90
            self.scrollView.verticalScrollIndicatorInsets.bottom = inset + 90
            self.view.layoutIfNeeded()
        }
        guard overlap > 0, roomNameField.isFirstResponder else {
            return
        }
        let rect = roomNameField.convert(roomNameField.bounds, to: scrollView)
        scrollView.scrollRectToVisible(
            rect.insetBy(dx: 0, dy: -22),
            animated: true
        )
    }

    private func applyMode() {
        let hasCover = selectedCover != nil
        coverButton.setImage(selectedCover, for: .normal)
        placeholderView.isHidden = hasCover
        removeCoverButton.isHidden = !hasCover
        coverButton.layer.borderWidth = hasCover ? 0 : 3
        coverButton.layer.borderColor = UIColor(
            red: 210 / 255,
            green: 215 / 255,
            blue: 216 / 255,
            alpha: 1
        ).cgColor
        if mode == .edit, roomNameField.text?.isEmpty != false {
            roomNameField.text = room?.title
        }
        configureNavigation(
            title: "My Room",
            rightView: mode == .edit ? deleteButton : nil
        )
    }

    private func finishProcessing(message: String) {
        isProcessing = false
        saveButton.isEnabled = true
        deleteButton.isEnabled = true
        loadingView.hide()
        showToast(message)
    }

    @objc private func openPhotoLibrary() {
        guard !isProcessing else {
            return
        }
        view.endEditing(true)
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func removeCover() {
        guard !isProcessing else {
            return
        }
        selectedCover = nil
        selectedCoverReference = nil
        selectedCoverIsNew = false
        applyMode()
    }

    @objc private func saveChanges() {
        guard !isProcessing else {
            return
        }
        view.endEditing(true)
        guard let selectedCover else {
            showToast("Choose a room cover.")
            return
        }
        let roomName = roomNameField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard (2...30).contains(roomName.count) else {
            showToast("Room name must contain 2 to 30 characters.")
            return
        }

        isProcessing = true
        saveButton.isEnabled = false
        deleteButton.isEnabled = false
        loadingView.show(message: mode == .create ? "Creating room" : "Saving room")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else {
                return
            }
            let wasCreating = mode == .create
            let previousCoverReference = room?.coverAssetName
            var newlySavedReference: String?
            do {
                let coverReference: String
                if selectedCoverIsNew || selectedCoverReference == nil {
                    let reference = try ZixyRoomCoverStore.save(selectedCover)
                    newlySavedReference = reference
                    coverReference = reference
                } else if let selectedCoverReference {
                    coverReference = selectedCoverReference
                } else {
                    throw ZixyDataStoreError.unavailable
                }

                let savedRoom = try ZixyDataStore.shared.saveOwnedRoom(
                    id: room?.id,
                    title: roomName,
                    coverAssetName: coverReference,
                    ownerEmail: ZixySessionStore.currentUserIdentifier
                )
                if let previousCoverReference,
                   previousCoverReference != coverReference {
                    ZixyRoomCoverStore.remove(reference: previousCoverReference)
                }
                room = savedRoom
                mode = .edit
                selectedCoverReference = savedRoom.coverAssetName
                selectedCoverIsNew = false
                applyMode()
                finishProcessing(
                    message: wasCreating ? "Room created." : "Room saved."
                )
            } catch {
                if let newlySavedReference {
                    ZixyRoomCoverStore.remove(reference: newlySavedReference)
                }
                finishProcessing(message: "Unable to save the room.")
            }
        }
    }

    @objc private func deleteRoom() {
        guard mode == .edit, let room, !isProcessing else {
            return
        }
        view.endEditing(true)
        isProcessing = true
        saveButton.isEnabled = false
        deleteButton.isEnabled = false
        loadingView.show(message: "Deleting room")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else {
                return
            }
            do {
                try ZixyDataStore.shared.deleteOwnedRoom(
                    id: room.id,
                    ownerEmail: ZixySessionStore.currentUserIdentifier
                )
                ZixyRoomCoverStore.remove(reference: room.coverAssetName)
                self.room = nil
                mode = .create
                selectedCover = nil
                selectedCoverReference = nil
                selectedCoverIsNew = false
                roomNameField.text = nil
                applyMode()
                finishProcessing(message: "Room deleted.")
            } catch {
                finishProcessing(message: "Unable to delete the room.")
            }
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

extension ZixyMyRoomController:
    PHPickerViewControllerDelegate,
    UITextFieldDelegate {

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
                    self.showToast("Unable to load the selected cover.")
                    return
                }
                self.selectedCover = image
                self.selectedCoverReference = nil
                self.selectedCoverIsNew = true
                self.applyMode()
            }
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private final class ZixyMyRoomLoadingView: UIView {

    private let spinner = UIActivityIndicatorView(style: .large)
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black.withAlphaComponent(0.22)
        isHidden = true

        let panel = UIView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = UIColor.white.withAlphaComponent(0.97)
        panel.layer.cornerRadius = 18
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .systemBlue
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = ZixyFontBook.bold(size: 13, relativeTo: .footnote)
        messageLabel.textColor = UIColor.black.withAlphaComponent(0.72)
        messageLabel.textAlignment = .center

        addSubview(panel)
        panel.addSubview(spinner)
        panel.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 132),
            panel.heightAnchor.constraint(equalToConstant: 104),
            spinner.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18),
            messageLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 6),
            messageLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 8),
            messageLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(message: String) {
        messageLabel.text = message
        accessibilityLabel = message
        isHidden = false
        spinner.startAnimating()
    }

    func hide() {
        spinner.stopAnimating()
        isHidden = true
    }
}
