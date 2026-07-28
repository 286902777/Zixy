import PhotosUI
import UIKit

final class ZixyReleaseController: ZixyScreenController,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout,
    PHPickerViewControllerDelegate,
    UITextFieldDelegate,
    UITextViewDelegate {

    private enum Layout {
        static let photoWidth: CGFloat = 122
        static let photoHeight: CGFloat = 163
        static let maximumPhotoCount = 3
        static let maximumTitleCount = 80
        static let maximumContentCount = 500
    }

    private var selectedImages: [UIImage] = []
    private var keyboardObservers: [NSObjectProtocol] = []
    private var isPublishing = false

    private let scrollView = UIScrollView()
    private let formView = UIView()
    private let titleField = UITextField()
    private let titleUnderline = UIView()
    private let contentTextView = UITextView()
    private let contentPlaceholderLabel = UILabel()
    private let characterCountLabel = UILabel()
    private let releaseButton = ZixyReleaseActionButton()
    private let loadingView = ZixyReleaseLoadingView()

    private let closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .black
        button.layer.cornerRadius = 11
        button.setImage(ZixyImageLibrary.releaseClose, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.accessibilityLabel = "Close release editor"
        return button
    }()

    private lazy var photoCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.sectionInset = UIEdgeInsets(
            top: 0,
            left: 18,
            bottom: 0,
            right: 18
        )

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            ZixyReleaseAddPhotoCell.self,
            forCellWithReuseIdentifier:
                ZixyReleaseAddPhotoCell.reuseIdentifier
        )
        collectionView.register(
            ZixyReleasePhotoCell.self,
            forCellWithReuseIdentifier:
                ZixyReleasePhotoCell.reuseIdentifier
        )
        return collectionView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.isHidden = true
        configureLayout()
        configureInputs()
        configureInteractions()
        observeKeyboard()
        updateCharacterCount()
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
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive

        formView.translatesAutoresizingMaskIntoConstraints = false
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleUnderline.translatesAutoresizingMaskIntoConstraints = false
        contentTextView.translatesAutoresizingMaskIntoConstraints = false
        contentPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
        characterCountLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(formView)
        formView.addSubview(photoCollectionView)
        formView.addSubview(titleField)
        formView.addSubview(titleUnderline)
        formView.addSubview(contentTextView)
        contentTextView.addSubview(contentPlaceholderLabel)
        formView.addSubview(characterCountLabel)
        formView.addSubview(releaseButton)
        view.addSubview(closeButton)
        view.addSubview(loadingView)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 19
            ),
            closeButton.leadingAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: 20
            ),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalTo: closeButton.widthAnchor),

            scrollView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 88
            ),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

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

            photoCollectionView.topAnchor.constraint(equalTo: formView.topAnchor),
            photoCollectionView.leadingAnchor.constraint(
                equalTo: formView.leadingAnchor
            ),
            photoCollectionView.trailingAnchor.constraint(
                equalTo: formView.trailingAnchor
            ),
            photoCollectionView.heightAnchor.constraint(
                equalToConstant: Layout.photoHeight
            ),

            titleField.topAnchor.constraint(
                equalTo: photoCollectionView.bottomAnchor,
                constant: 27
            ),
            titleField.leadingAnchor.constraint(
                equalTo: formView.leadingAnchor,
                constant: 23
            ),
            titleField.trailingAnchor.constraint(
                equalTo: formView.trailingAnchor,
                constant: -21
            ),
            titleField.heightAnchor.constraint(equalToConstant: 44),

            titleUnderline.topAnchor.constraint(
                equalTo: titleField.bottomAnchor
            ),
            titleUnderline.leadingAnchor.constraint(
                equalTo: titleField.leadingAnchor
            ),
            titleUnderline.trailingAnchor.constraint(
                equalTo: titleField.trailingAnchor
            ),
            titleUnderline.heightAnchor.constraint(equalToConstant: 1),

            contentTextView.topAnchor.constraint(
                equalTo: titleUnderline.bottomAnchor,
                constant: 7
            ),
            contentTextView.leadingAnchor.constraint(
                equalTo: formView.leadingAnchor,
                constant: 18
            ),
            contentTextView.trailingAnchor.constraint(
                equalTo: formView.trailingAnchor,
                constant: -18
            ),
            contentTextView.heightAnchor.constraint(equalToConstant: 193),

            contentPlaceholderLabel.topAnchor.constraint(
                equalTo: contentTextView.topAnchor,
                constant: 7
            ),
            contentPlaceholderLabel.leadingAnchor.constraint(
                equalTo: contentTextView.leadingAnchor,
                constant: 5
            ),
            contentPlaceholderLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: contentTextView.trailingAnchor,
                constant: -5
            ),

            characterCountLabel.trailingAnchor.constraint(
                equalTo: formView.trailingAnchor,
                constant: -22
            ),
            characterCountLabel.bottomAnchor.constraint(
                equalTo: contentTextView.bottomAnchor,
                constant: -3
            ),

            releaseButton.topAnchor.constraint(
                equalTo: formView.topAnchor,
                constant: 567
            ),
            releaseButton.centerXAnchor.constraint(
                equalTo: formView.centerXAnchor
            ),
            releaseButton.widthAnchor.constraint(equalToConstant: 285),
            releaseButton.heightAnchor.constraint(equalToConstant: 74),
            releaseButton.bottomAnchor.constraint(
                equalTo: formView.bottomAnchor,
                constant: -20
            ),

            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureInputs() {
        titleField.attributedPlaceholder = NSAttributedString(
            string: "Title: Enter theme",
            attributes: [
                .font: ZixyFontBook.bold(size: 18, relativeTo: .headline),
                .foregroundColor: UIColor.systemGray
            ]
        )
        titleField.font = ZixyFontBook.bold(size: 18, relativeTo: .headline)
        titleField.textColor = UIColor.black.withAlphaComponent(0.8)
        titleField.returnKeyType = .done
        titleField.delegate = self
        titleField.inputAccessoryView = makeDoneToolbar()

        titleUnderline.backgroundColor = UIColor.systemGray4

        contentTextView.backgroundColor = .clear
        contentTextView.font = ZixyFontBook.bold(
            size: 16,
            relativeTo: .body
        )
        contentTextView.textColor = UIColor.black.withAlphaComponent(0.8)
        contentTextView.textContainerInset = UIEdgeInsets(
            top: 7,
            left: 0,
            bottom: 30,
            right: 0
        )
        contentTextView.delegate = self
        contentTextView.inputAccessoryView = makeDoneToolbar()

        contentPlaceholderLabel.text = "Content:Please enter..."
        contentPlaceholderLabel.font = ZixyFontBook.bold(
            size: 16,
            relativeTo: .body
        )
        contentPlaceholderLabel.textColor = .systemGray

        characterCountLabel.font = ZixyFontBook.bold(
            size: 14,
            relativeTo: .footnote
        )
        characterCountLabel.textColor = .systemGray3
        characterCountLabel.textAlignment = .right
    }

    private func configureInteractions() {
        closeButton.addTarget(
            self,
            action: #selector(closeEditor),
            for: .touchUpInside
        )
        releaseButton.addTarget(
            self,
            action: #selector(releasePost),
            for: .touchUpInside
        )

        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)
    }

    private func observeKeyboard() {
        let center = NotificationCenter.default
        keyboardObservers = [
            center.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleKeyboardChange(notification)
            },
            center.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleKeyboardChange(notification)
            }
        ]
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

    private func updateCharacterCount() {
        let count = contentTextView.text.count
        characterCountLabel.text = "\(count)/\(Layout.maximumContentCount)"
        contentPlaceholderLabel.isHidden = !contentTextView.text.isEmpty
    }

    private var showsAddPhotoCell: Bool {
        selectedImages.count < Layout.maximumPhotoCount
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        selectedImages.count + (showsAddPhotoCell ? 1 : 0)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if showsAddPhotoCell && indexPath.item == 0 {
            return collectionView.dequeueReusableCell(
                withReuseIdentifier: ZixyReleaseAddPhotoCell.reuseIdentifier,
                for: indexPath
            )
        }

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ZixyReleasePhotoCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyReleasePhotoCell else {
            return UICollectionViewCell()
        }
        let imageIndex = showsAddPhotoCell
            ? indexPath.item - 1
            : indexPath.item
        guard selectedImages.indices.contains(imageIndex) else {
            return cell
        }
        cell.configure(image: selectedImages[imageIndex])
        cell.onRemove = { [weak self, weak cell] in
            guard
                let self,
                let cell,
                let currentPath = collectionView.indexPath(for: cell)
            else {
                return
            }
            removeImage(atCollectionIndex: currentPath.item)
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard showsAddPhotoCell && indexPath.item == 0 else {
            return
        }
        selectPhotos()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: Layout.photoWidth, height: Layout.photoHeight)
    }

    private func selectPhotos() {
        let remainingCount = Layout.maximumPhotoCount - selectedImages.count
        guard remainingCount > 0 else {
            showToast("You can select up to three photos.")
            return
        }
        view.endEditing(true)

        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = remainingCount
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else {
            return
        }

        for result in results {
            let provider = result.itemProvider
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                continue
            }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                DispatchQueue.main.async {
                    guard
                        let self,
                        let image = object as? UIImage,
                        self.selectedImages.count < Layout.maximumPhotoCount
                    else {
                        return
                    }
                    self.selectedImages.append(image)
                    self.photoCollectionView.reloadData()
                }
            }
        }
    }

    private func removeImage(atCollectionIndex index: Int) {
        let imageIndex = showsAddPhotoCell ? index - 1 : index
        guard selectedImages.indices.contains(imageIndex) else {
            return
        }
        selectedImages.remove(at: imageIndex)
        photoCollectionView.reloadData()
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let currentText = textField.text,
              let swiftRange = Range(range, in: currentText) else {
            return false
        }
        return currentText.replacingCharacters(
            in: swiftRange,
            with: string
        ).count <= Layout.maximumTitleCount
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard let swiftRange = Range(range, in: textView.text) else {
            return false
        }
        return textView.text.replacingCharacters(
            in: swiftRange,
            with: text
        ).count <= Layout.maximumContentCount
    }

    func textViewDidChange(_ textView: UITextView) {
        updateCharacterCount()
    }

    @objc private func closeEditor() {
        view.endEditing(true)
        if navigationController?.viewControllers.count ?? 0 > 1 {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func releasePost() {
        guard !isPublishing else {
            return
        }
        view.endEditing(true)

        let title = titleField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let content = contentTextView.text
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !selectedImages.isEmpty else {
            showToast("Select at least one photo.")
            return
        }
        guard !title.isEmpty else {
            showToast("Enter a title.")
            return
        }
        guard !content.isEmpty else {
            showToast("Enter post content.")
            return
        }

        isPublishing = true
        releaseButton.isEnabled = false
        loadingView.show()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self else {
                return
            }
            isPublishing = false
            releaseButton.isEnabled = true
            loadingView.hide()
            showToast("Post released.")
        }
    }

    @objc private func handleKeyboardChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let frameValue = userInfo[
                UIResponder.keyboardFrameEndUserInfoKey
            ] as? NSValue
        else {
            return
        }

        let keyboardFrame = view.convert(frameValue.cgRectValue, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap

        if let activeView = view.findFirstResponder() {
            let rect = activeView.convert(activeView.bounds, to: scrollView)
            scrollView.scrollRectToVisible(
                rect.insetBy(dx: 0, dy: -18),
                animated: true
            )
        }
    }
}

private final class ZixyReleaseAddPhotoCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyReleaseAddPhotoCell"

    override init(frame: CGRect) {
        super.init(frame: frame)
        let imageView = UIImageView(image: ZixyImageLibrary.releaseAddPhoto)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        isAccessibilityElement = true
        accessibilityLabel = "Add photos"
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class ZixyReleasePhotoCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyReleasePhotoCell"

    var onRemove: (() -> Void)?

    private let imageView = UIImageView()
    private let removeButton = UIButton(type: .custom)

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 7

        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        removeButton.layer.cornerRadius = 3
        removeButton.setImage(
            ZixyImageLibrary.releaseRemovePhoto,
            for: .normal
        )
        removeButton.accessibilityLabel = "Remove photo"
        removeButton.addTarget(
            self,
            action: #selector(removePhoto),
            for: .touchUpInside
        )

        contentView.addSubview(imageView)
        contentView.addSubview(removeButton)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            removeButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -3
            ),
            removeButton.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -3
            ),
            removeButton.widthAnchor.constraint(equalToConstant: 20),
            removeButton.heightAnchor.constraint(equalTo: removeButton.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        onRemove = nil
    }

    func configure(image: UIImage) {
        imageView.image = image
    }

    @objc private func removePhoto() {
        onRemove?()
    }
}

private final class ZixyReleaseActionButton: UIControl {

    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 37
        layer.masksToBounds = true

        gradientLayer.colors = [
            UIColor(red: 91 / 255, green: 183 / 255, blue: 1, alpha: 1).cgColor,
            UIColor(red: 0, green: 91 / 255, blue: 1, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradientLayer, at: 0)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Release"
        titleLabel.font = ZixyFontBook.bold(size: 21, relativeTo: .title3)
        titleLabel.textColor = .white

        let circle = UIView()
        circle.translatesAutoresizingMaskIntoConstraints = false
        circle.backgroundColor = UIColor.white.withAlphaComponent(0.94)
        circle.layer.cornerRadius = 27
        circle.isUserInteractionEnabled = false

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.translatesAutoresizingMaskIntoConstraints = false
        arrow.tintColor = UIColor(
            red: 15 / 255,
            green: 69 / 255,
            blue: 151 / 255,
            alpha: 1
        )
        arrow.contentMode = .scaleAspectFit

        addSubview(titleLabel)
        addSubview(circle)
        circle.addSubview(arrow)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 31
            ),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            circle.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -9
            ),
            circle.centerYAnchor.constraint(equalTo: centerYAnchor),
            circle.widthAnchor.constraint(equalToConstant: 54),
            circle.heightAnchor.constraint(equalTo: circle.widthAnchor),

            arrow.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            arrow.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 19),
            arrow.heightAnchor.constraint(equalToConstant: 27)
        ])
        accessibilityLabel = "Release post"
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.65 : 1
        }
    }
}

private final class ZixyReleaseLoadingView: UIView {

    private let spinner = UIActivityIndicatorView(style: .large)

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black.withAlphaComponent(0.2)
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
        accessibilityLabel = "Releasing post"
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

private extension UIView {

    func findFirstResponder() -> UIView? {
        if isFirstResponder {
            return self
        }
        for subview in subviews {
            if let responder = subview.findFirstResponder() {
                return responder
            }
        }
        return nil
    }
}
