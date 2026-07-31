import UIKit
import PhotosUI

final class ZixyProfileSetupController: ZixyAuthCanvasController,
    UIPickerViewDataSource,
    UIPickerViewDelegate,
    PHPickerViewControllerDelegate {

    enum Gender {
        case female
        case male
    }

    var onCompleted: ((String, UIImage?) -> Bool)?

    private let nameField = ZixyAuthFieldView(
        title: "Name",
        placeholder: "Please enter",
        titleSize: 16,
        textSize: 16,
        fieldHeight: 59,
        labelSpacing: 8,
        fieldHorizontalInset: 19
    )
    private let birthdayField = ZixyAuthFieldView(
        title: "Birthday",
        placeholder: "01/01/1990",
        titleSize: 16,
        textSize: 16,
        fieldHeight: 59,
        labelSpacing: 8,
        fieldHorizontalInset: 19
    )
    private let locationField = ZixyAuthFieldView(
        title: "Location",
        placeholder: "NL",
        titleSize: 16,
        textSize: 16,
        fieldHeight: 59,
        labelSpacing: 8,
        fieldHorizontalInset: 19
    )
    private let femaleButton = UIButton(type: .custom)
    private let maleButton = UIButton(type: .custom)
    private let avatarView = UIImageView(image: ZixyImageLibrary.userAvatar)
    private let birthdayPicker = UIDatePicker()
    private let locationPicker = UIPickerView()
    private let countryCodes = Locale.isoRegionCodes.sorted()
    private let releaseButton = ZixyGradientActionButton(
        title: "Save",
        height: 74,
        titleSize: 22
    )
    private let loadingOverlay = ZixyLoadingOverlay()

    private var selectedGender: Gender = .female
    private var selectedAvatarImage: UIImage?
    private var isProcessing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.alwaysBounceVertical = false
        scrollView.bounces = false
        scrollView.showsVerticalScrollIndicator = false
        configureContent()
        configureControlledInputs()
        applyGender()
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
            view.bounds.maxY - releaseButton.frame.minY
        )
        if abs(minimumScrollBottomInset - coveredHeight) > 0.5 {
            minimumScrollBottomInset = coveredHeight
        }
    }

    private func configureContent() {
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 50
        avatarView.accessibilityLabel = "User avatar"
        avatarView.accessibilityTraits = .button
        avatarView.isUserInteractionEnabled = true
        avatarView.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(presentPhotoPicker)
            )
        )

        let cameraButton = UIButton(type: .system)
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        cameraButton.setImage(
            ZixyImageLibrary.profileCamera?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        cameraButton.accessibilityLabel = "Change profile photo"
        cameraButton.addTarget(
            self,
            action: #selector(presentPhotoPicker),
            for: .touchUpInside
        )

        let profileHeaderView = UIImageView(image: ZixyImageLibrary.profileHeader)
        profileHeaderView.translatesAutoresizingMaskIntoConstraints = false
        profileHeaderView.contentMode = .scaleAspectFit
        profileHeaderView.accessibilityLabel =
            "Improve your profile so that everyone can better understand you"

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(avatarView)
        header.addSubview(cameraButton)
        header.addSubview(profileHeaderView)

        let genderLabel = UILabel()
        genderLabel.text = "Gender"
        genderLabel.font = ZixyFontBook.bold(size: 16, relativeTo: .body)
        genderLabel.textColor = ZixyColorPalette.ink.withAlphaComponent(0.55)

        configureGenderButton(
            femaleButton,
            image: ZixyImageLibrary.genderFemale,
            accessibilityLabel: "Female"
        )
        configureGenderButton(
            maleButton,
            image: ZixyImageLibrary.genderMale,
            accessibilityLabel: "Male"
        )
        femaleButton.addTarget(self, action: #selector(selectFemale), for: .touchUpInside)
        maleButton.addTarget(self, action: #selector(selectMale), for: .touchUpInside)

        let genderRow = UIStackView(arrangedSubviews: [femaleButton, maleButton])
        genderRow.axis = .horizontal
        genderRow.spacing = 18
        genderRow.alignment = .fill
        genderRow.distribution = .fillEqually

        let genderStack = UIStackView(arrangedSubviews: [genderLabel, genderRow])
        genderStack.axis = .vertical
        genderStack.alignment = .leading
        genderStack.spacing = 8

        releaseButton.addTarget(
            self,
            action: #selector(completeProfile),
            for: .touchUpInside
        )

        let form = UIStackView(
            arrangedSubviews: [
                nameField,
                birthdayField,
                locationField,
                genderStack
            ]
        )
        form.translatesAutoresizingMaskIntoConstraints = false
        form.axis = .vertical
        form.spacing = 21

        scrollContentView.addSubview(header)
        scrollContentView.addSubview(form)
        view.addSubview(releaseButton)

        let contentBottomConstraint = scrollContentView.bottomAnchor.constraint(
            greaterThanOrEqualTo: form.bottomAnchor,
            constant: 24
        )

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(
                equalTo: scrollContentView.safeAreaLayoutGuide.topAnchor,
                constant: 54
            ),
            header.leadingAnchor.constraint(
                equalTo: scrollContentView.leadingAnchor,
                constant: 20
            ),
            header.trailingAnchor.constraint(
                equalTo: scrollContentView.trailingAnchor,
                constant: -20
            ),
            header.heightAnchor.constraint(equalToConstant: 100),
            avatarView.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            avatarView.topAnchor.constraint(equalTo: header.topAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 100),
            avatarView.heightAnchor.constraint(equalTo: avatarView.widthAnchor),
            cameraButton.centerXAnchor.constraint(
                equalTo: avatarView.trailingAnchor,
                constant: -12
            ),
            cameraButton.centerYAnchor.constraint(
                equalTo: avatarView.bottomAnchor,
                constant: -18
            ),
            cameraButton.widthAnchor.constraint(equalToConstant: 32),
            cameraButton.heightAnchor.constraint(equalToConstant: 32),
            profileHeaderView.trailingAnchor.constraint(
                equalTo: header.trailingAnchor,
                constant: -1
            ),
            profileHeaderView.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            profileHeaderView.widthAnchor.constraint(equalToConstant: 207),
            profileHeaderView.heightAnchor.constraint(equalToConstant: 100),
            form.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 31),
            form.leadingAnchor.constraint(
                equalTo: scrollContentView.leadingAnchor,
                constant: 19
            ),
            form.trailingAnchor.constraint(
                equalTo: scrollContentView.trailingAnchor,
                constant: -18
            ),
            contentBottomConstraint,
            genderRow.widthAnchor.constraint(equalToConstant: 138),
            genderRow.heightAnchor.constraint(equalToConstant: 60),
            releaseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            releaseButton.widthAnchor.constraint(equalToConstant: 286),
            releaseButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -6
            )
        ])
    }

    private func configureGenderButton(
        _ button: UIButton,
        image: UIImage?,
        accessibilityLabel: String
    ) {
        button.setImage(
            image?.withRenderingMode(.alwaysOriginal),
            for: .normal
        )
        button.layer.cornerRadius = 12
        button.accessibilityLabel = accessibilityLabel
    }

    private func configureControlledInputs() {
        var birthdayComponents = DateComponents()
        birthdayComponents.calendar = Calendar(identifier: .gregorian)
        birthdayComponents.year = 1990
        birthdayComponents.month = 1
        birthdayComponents.day = 1

        birthdayPicker.datePickerMode = .date
        birthdayPicker.preferredDatePickerStyle = .wheels
        birthdayPicker.calendar = Calendar(identifier: .gregorian)
        birthdayPicker.locale = Locale(identifier: "en_US_POSIX")
        birthdayPicker.maximumDate = Date()
        birthdayPicker.date = birthdayComponents.date ?? Date()
        birthdayPicker.addTarget(
            self,
            action: #selector(updateBirthday),
            for: .valueChanged
        )

        locationPicker.dataSource = self
        locationPicker.delegate = self

        birthdayField.textField.inputView = birthdayPicker
        birthdayField.textField.inputAccessoryView = makePickerToolbar()
        birthdayField.textField.addTarget(
            self,
            action: #selector(beginBirthdaySelection),
            for: .editingDidBegin
        )

        locationField.textField.inputView = locationPicker
        locationField.textField.inputAccessoryView = makePickerToolbar()
        locationField.textField.addTarget(
            self,
            action: #selector(beginLocationSelection),
            for: .editingDidBegin
        )

        if
            let regionCode = Locale.current.regionCode,
            let row = countryCodes.firstIndex(of: regionCode)
        {
            locationPicker.selectRow(row, inComponent: 0, animated: false)
        }
    }

    private func makePickerToolbar() -> UIToolbar {
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
                action: #selector(finishPickerEditing)
            )
        ]
        return toolbar
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(
        _ pickerView: UIPickerView,
        numberOfRowsInComponent component: Int
    ) -> Int {
        countryCodes.count
    }

    func pickerView(
        _ pickerView: UIPickerView,
        titleForRow row: Int,
        forComponent component: Int
    ) -> String? {
        let code = countryCodes[row]
        let countryName = Locale(identifier: "en_US").localizedString(
            forRegionCode: code
        ) ?? code
        return "\(code)  \(countryName)"
    }

    func pickerView(
        _ pickerView: UIPickerView,
        didSelectRow row: Int,
        inComponent component: Int
    ) {
        locationField.textField.text = countryCodes[row]
    }

    private func applyGender() {
        let isFemale = selectedGender == .female
        femaleButton.backgroundColor = isFemale
            ? UIColor(
                red: 1,
                green: 220 / 255,
                blue: 239 / 255,
                alpha: 1
            )
            : .white
        femaleButton.tintColor = .systemPink
        maleButton.backgroundColor = isFemale
            ? .white
            : UIColor(
                red: 218 / 255,
                green: 241 / 255,
                blue: 1,
                alpha: 1
            )
        maleButton.tintColor = .systemBlue
        femaleButton.accessibilityTraits = isFemale ? [.button, .selected] : .button
        maleButton.accessibilityTraits = isFemale ? .button : [.button, .selected]
    }

    @objc private func selectFemale() {
        selectedGender = .female
        applyGender()
    }

    @objc private func selectMale() {
        selectedGender = .male
        applyGender()
    }

    @objc private func beginBirthdaySelection() {
        guard birthdayField.textField.text?.isEmpty != false else {
            return
        }
        updateBirthday()
    }

    @objc private func updateBirthday() {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yyyy"
        birthdayField.textField.text = formatter.string(
            from: birthdayPicker.date
        )
    }

    @objc private func beginLocationSelection() {
        guard locationField.textField.text?.isEmpty != false else {
            return
        }
        let row = locationPicker.selectedRow(inComponent: 0)
        locationField.textField.text = countryCodes[row]
    }

    @objc private func finishPickerEditing() {
        view.endEditing(true)
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
                self?.selectedAvatarImage = image
                self?.avatarView.image = image
            }
        }
    }

    @objc private func completeProfile() {
        guard !isProcessing else {
            return
        }
        view.endEditing(true)
        let name = nameField.textField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard (2...20).contains(name.count) else {
            showToast("Name must contain 2 to 20 characters.")
            return
        }
        guard !(birthdayField.textField.text ?? "").isEmpty else {
            showToast("Enter your birthday.")
            return
        }
        guard !(locationField.textField.text ?? "").isEmpty else {
            showToast("Enter your location.")
            return
        }
        isProcessing = true
        releaseButton.isEnabled = false
        loadingOverlay.show(message: "Creating account")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else {
                return
            }
            let didComplete = self.onCompleted?(
                name,
                self.selectedAvatarImage
            ) ?? false
            self.isProcessing = false
            self.releaseButton.isEnabled = true
            self.loadingOverlay.hide()
            if !didComplete {
                self.showToast("Unable to create the account.")
            }
        }
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }
}
