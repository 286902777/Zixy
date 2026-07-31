import UIKit

final class ZixySettingsController: ZixyScreenController {

    private enum Item: CaseIterable {
        case privacyPolicy
        case userAgreement
        case logOut
        case deleteAccount

        var title: String {
            switch self {
            case .privacyPolicy:
                return "Privacy Policy"
            case .userAgreement:
                return "User Agreement"
            case .logOut:
                return "Log Out"
            case .deleteAccount:
                return "Delete Account"
            }
        }
    }

    private let stackView = UIStackView()
    private let loadingView = ZixySettingsLoadingView()
    private var rows: [ZixySettingsRow] = []
    private var isProcessingAccountAction = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation(title: "Setting")
        configureRows()
        configureLayout()
    }

    private func configureRows() {
        rows = Item.allCases.map { item in
            let row = ZixySettingsRow(title: item.title)
            row.addAction(
                UIAction { [weak self] _ in
                    self?.select(item)
                },
                for: .touchUpInside
            )
            return row
        }
        rows.forEach(stackView.addArrangedSubview)
    }

    private func configureLayout() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill

        contentView.addSubview(stackView)
        view.addSubview(loadingView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        rows.forEach {
            $0.heightAnchor.constraint(equalToConstant: 56).isActive = true
        }
    }

    private func select(_ item: Item) {
        guard !isProcessingAccountAction else {
            return
        }
        switch item {
        case .privacyPolicy:
            showWebPage(.privacyPolicy)
        case .userAgreement:
            showWebPage(.userAgreement)
        case .logOut:
            performAccountExit()
        case .deleteAccount:
            confirmAccountDeletion()
        }
    }

    private func showWebPage(_ page: ZixyWebController.H5Page) {
        navigationController?.pushViewController(
            ZixyWebController(page: page),
            animated: true
        )
    }

    private func confirmAccountDeletion() {
        let controller = ZixyAlertController(kind: .deleteAccount)
        controller.onPrimaryAction = { [weak self] in
            self?.performAccountExit()
        }
        present(controller, animated: true)
    }

    private func performAccountExit() {
        guard !isProcessingAccountAction else {
            return
        }
        isProcessingAccountAction = true
        rows.forEach { $0.isEnabled = false }
        loadingView.show()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else {
                return
            }
            ZixySessionStore.clear()
            guard
                let sceneDelegate = view.window?.windowScene?.delegate
                    as? SceneDelegate
            else {
                isProcessingAccountAction = false
                rows.forEach { $0.isEnabled = true }
                loadingView.hide()
                showToast("Unable to complete the account action.")
                return
            }
            sceneDelegate.showAuthenticationInterface()
        }
    }
}

private final class ZixySettingsRow: UIControl {

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityLabel = title
        accessibilityTraits = .button

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = ZixyFontBook.bold(size: 18, relativeTo: .body)
        label.textColor = UIColor.black.withAlphaComponent(0.78)
        label.isUserInteractionEnabled = false

        let disclosure = UIImageView(
            image: UIImage(
                systemName: "chevron.right",
                withConfiguration: UIImage.SymbolConfiguration(
                    pointSize: 15,
                    weight: .bold
                )
            )
        )
        disclosure.translatesAutoresizingMaskIntoConstraints = false
        disclosure.tintColor = UIColor.black.withAlphaComponent(0.86)
        disclosure.contentMode = .scaleAspectFit
        disclosure.isUserInteractionEnabled = false

        addSubview(label)
        addSubview(disclosure)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(
                lessThanOrEqualTo: disclosure.leadingAnchor,
                constant: -12
            ),

            disclosure.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -24
            ),
            disclosure.centerYAnchor.constraint(equalTo: centerYAnchor),
            disclosure.widthAnchor.constraint(equalToConstant: 10),
            disclosure.heightAnchor.constraint(equalToConstant: 17)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted
                ? UIColor.black.withAlphaComponent(0.04)
                : .clear
        }
    }
}

private final class ZixySettingsLoadingView: UIView {

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
        accessibilityLabel = "Processing account"
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
