import UIKit

final class ZixyTermsController: UIViewController {

    static let acceptedDefaultsKey = "zixy_eula_accepted"

    private let requiresAcceptance: Bool
    private let onAgree: () -> Void
    private let onCancel: () -> Void

    init(
        requiresAcceptance: Bool,
        onAgree: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.requiresAcceptance = requiresAcceptance
        self.onAgree = onAgree
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        requiresAcceptance = false
        onAgree = {}
        onCancel = {}
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.68)
        configureContent()
    }

    private func configureContent() {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        let panelView = UIImageView(
            image: ZixyImageLibrary.eulaPanel?.resizableImage(
                withCapInsets: UIEdgeInsets(top: 125, left: 50, bottom: 50, right: 50),
                resizingMode: .stretch
            )
        )
        panelView.translatesAutoresizingMaskIntoConstraints = false
        panelView.contentMode = .scaleToFill
        panelView.isUserInteractionEnabled = false

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "EULA"
        titleLabel.font = ZixyFontBook.bold(size: 22, relativeTo: .title2)
        titleLabel.textAlignment = .center

        let bodyView = UITextView()
        bodyView.translatesAutoresizingMaskIntoConstraints = false
        bodyView.text = Self.agreementText
        bodyView.font = ZixyFontBook.bold(size: 9, relativeTo: .caption2)
        bodyView.textColor = ZixyColorPalette.ink.withAlphaComponent(0.74)
        bodyView.backgroundColor = .clear
        bodyView.isEditable = false
        bodyView.isSelectable = true
        bodyView.showsVerticalScrollIndicator = true
        bodyView.textContainerInset = .zero
        bodyView.textContainer.lineFragmentPadding = 0

        let cancelButton = makeButton(
            title: "Cancel",
            image: ZixyImageLibrary.eulaCancelButton,
            action: #selector(cancel)
        )
        let agreeButton = makeButton(
            title: "Agree",
            image: ZixyImageLibrary.eulaAgreeButton,
            action: #selector(agree)
        )
        let buttons = UIStackView(arrangedSubviews: [cancelButton, agreeButton])
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.axis = .horizontal
        buttons.spacing = 10
        buttons.distribution = .fillEqually

        view.addSubview(card)
        card.addSubview(panelView)
        card.addSubview(titleLabel)
        card.addSubview(bodyView)
        card.addSubview(buttons)

        let preferredCardHeight = card.heightAnchor.constraint(equalToConstant: 644)
        preferredCardHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 28
            ),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            preferredCardHeight,
            card.heightAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor,
                constant: -36
            ),
            card.bottomAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -8
            ),
            panelView.topAnchor.constraint(equalTo: card.topAnchor),
            panelView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            panelView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 21),
            titleLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            bodyView.topAnchor.constraint(equalTo: card.topAnchor, constant: 68),
            bodyView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            bodyView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            bodyView.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -10),
            buttons.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            buttons.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            buttons.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -13),
            buttons.heightAnchor.constraint(equalToConstant: 39)
        ])
    }

    private func makeButton(
        title: String,
        image: UIImage?,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(image, for: .normal)
        button.accessibilityLabel = title
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func agree() {
        if requiresAcceptance {
            UserDefaults.standard.set(true, forKey: Self.acceptedDefaultsKey)
        }
        onAgree()
    }

    @objc private func cancel() {
        onCancel()
    }

    private static let agreementText = """
    Welcome to Zixy. To create a positive, safe, and standardized space for beauty and makeup sharing, the following content is strictly prohibited:

    1. Content involving child harm, pornography, or materials detrimental to minors' physical and mental health, including text, images, videos, or comments that insult, defame, or improperly use minors' portraits and information.

    2. False or harmful public information, including content generated by AI or other means that disrupts public order, especially fake beauty tutorials, misleading skincare guidance, and false public opinion content.

    3. Violent content, cyberbullying, and any content that promotes pornography, illegal acts, or disrupts the network ecological environment.
    """
}
