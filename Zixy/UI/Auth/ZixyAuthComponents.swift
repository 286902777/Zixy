import UIKit

final class ZixyAuthFieldView: UIView {

    let textField = UITextField()

    init(
        title: String,
        placeholder: String,
        symbolName: String? = nil,
        assetName: String? = nil,
        isSecure: Bool = false,
        titleSize: CGFloat = 13,
        textSize: CGFloat = 12,
        fieldHeight: CGFloat = 48,
        titleHeight: CGFloat? = nil,
        labelSpacing: CGFloat = 8,
        placesIconBesideTitle: Bool = false,
        fieldHorizontalInset: CGFloat = 12
    ) {
        super.init(frame: .zero)
        configure(
            title: title,
            placeholder: placeholder,
            symbolName: symbolName,
            assetName: assetName,
            isSecure: isSecure,
            titleSize: titleSize,
            textSize: textSize,
            fieldHeight: fieldHeight,
            titleHeight: titleHeight,
            labelSpacing: labelSpacing,
            placesIconBesideTitle: placesIconBesideTitle,
            fieldHorizontalInset: fieldHorizontalInset
        )
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func configure(
        title: String,
        placeholder: String,
        symbolName: String?,
        assetName: String?,
        isSecure: Bool,
        titleSize: CGFloat,
        textSize: CGFloat,
        fieldHeight: CGFloat,
        titleHeight: CGFloat?,
        labelSpacing: CGFloat,
        placesIconBesideTitle: Bool,
        fieldHorizontalInset: CGFloat
    ) {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = ZixyFontBook.bold(size: titleSize, relativeTo: .caption1)
        titleLabel.textColor = ZixyColorPalette.ink.withAlphaComponent(0.72)

        let iconImage = assetName.flatMap(UIImage.init(named:))
            ?? symbolName.flatMap(UIImage.init(systemName:))
        let icon = UIImageView(image: iconImage)
        icon.tintColor = ZixyColorPalette.ink.withAlphaComponent(0.7)
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.isHidden = iconImage == nil

        textField.placeholder = placeholder
        textField.font = ZixyFontBook.bold(size: textSize, relativeTo: .footnote)
        textField.textColor = ZixyColorPalette.ink
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.isSecureTextEntry = isSecure

        let titleRowSubviews: [UIView] = placesIconBesideTitle
            ? [icon, titleLabel]
            : [titleLabel]
        let titleRow = UIStackView(arrangedSubviews: titleRowSubviews)
        titleRow.axis = .horizontal
        titleRow.alignment = titleHeight == nil ? .center : .top
        titleRow.spacing = 8

        let fieldRowSubviews: [UIView] = placesIconBesideTitle
            ? [textField]
            : [icon, textField]
        let row = UIStackView(arrangedSubviews: fieldRowSubviews)
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.backgroundColor = UIColor(
            red: 242 / 255,
            green: 247 / 255,
            blue: 249 / 255,
            alpha: 1
        )
        row.layer.cornerRadius = 11
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(
            top: 0,
            left: fieldHorizontalInset,
            bottom: 0,
            right: 10
        )

        if isSecure {
            let visibilityButton = UIButton(type: .system)
            visibilityButton.setImage(
                ZixyImageLibrary.authVisibilityIcon?.withRenderingMode(.alwaysOriginal),
                for: .normal
            )
            visibilityButton.alpha = 0.46
            visibilityButton.accessibilityLabel = "Toggle password visibility"
            visibilityButton.addAction(
                UIAction { [weak textField, weak visibilityButton] _ in
                    guard let textField else {
                        return
                    }
                    textField.isSecureTextEntry.toggle()
                    visibilityButton?.alpha = textField.isSecureTextEntry ? 0.46 : 1
                },
                for: .touchUpInside
            )
            row.addArrangedSubview(visibilityButton)
            visibilityButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        }

        let stack = UIStackView(arrangedSubviews: [titleRow, row])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = labelSpacing
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.heightAnchor.constraint(equalToConstant: fieldHeight),
            icon.widthAnchor.constraint(equalToConstant: 14)
        ])

        if let titleHeight {
            titleRow.heightAnchor.constraint(
                equalToConstant: titleHeight
            ).isActive = true
        }
    }
}

final class ZixyGradientActionButton: UIControl {

    private let gradientLayer = CAGradientLayer()
    private let titleLabel = UILabel()

    init(title: String, height: CGFloat = 52, titleSize: CGFloat = 18) {
        super.init(frame: .zero)
        configure(title: title, height: height, titleSize: titleSize)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure(title: "", height: 52, titleSize: 18)
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

    private func configure(title: String, height: CGFloat, titleSize: CGFloat) {
        translatesAutoresizingMaskIntoConstraints = false
        layer.insertSublayer(gradientLayer, at: 0)
        gradientLayer.colors = [
            UIColor(red: 111 / 255, green: 201 / 255, blue: 1, alpha: 1).cgColor,
            UIColor(red: 24 / 255, green: 112 / 255, blue: 1, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)

        let backgroundImageView = UIImageView(image: ZixyImageLibrary.authPrimaryButton)
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.contentMode = .scaleToFill
        backgroundImageView.isUserInteractionEnabled = false
        gradientLayer.isHidden = ZixyImageLibrary.authPrimaryButton != nil

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = ZixyFontBook.bold(size: titleSize, relativeTo: .headline)
        titleLabel.textColor = .white

        addSubview(backgroundImageView)
        addSubview(titleLabel)
        accessibilityTraits = .button
        accessibilityLabel = title

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),
            backgroundImageView.topAnchor.constraint(equalTo: topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
