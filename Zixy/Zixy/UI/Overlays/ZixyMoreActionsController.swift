import UIKit

final class ZixyMoreActionsController: UIViewController {

    var onFollowed: (() -> Void)?
    var onReport: (() -> Void)?
    var onBlock: (() -> Void)?

    private let dimmingControl: UIControl = {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        control.backgroundColor = UIColor.black.withAlphaComponent(0.66)
        return control
    }()

    private let panelView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.cornerRadius = 28
        view.clipsToBounds = true
        return view
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.16)
        return view
    }()

    private lazy var followedButton = makeActionButton(
        title: "Followed",
        action: #selector(followedSelected)
    )

    private lazy var reportButton = makeActionButton(
        title: "Report",
        action: #selector(reportSelected)
    )

    private lazy var blockButton = makeActionButton(
        title: "Block",
        action: #selector(blockSelected)
    )

    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(UIColor.black.withAlphaComponent(0.78), for: .normal)
        button.titleLabel?.font = ZixyFontBook.bold(size: 21, relativeTo: .title3)
        button.accessibilityLabel = "Cancel"
        button.addTarget(self, action: #selector(cancelSelected), for: .touchUpInside)
        return button
    }()

    init(targetName: String) {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        view.accessibilityLabel = "More options for \(targetName)"
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLayout()
        configureInteractions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.layoutIfNeeded()
        panelView.transform = CGAffineTransform(
            translationX: 0,
            y: panelView.bounds.height
        )
        dimmingControl.alpha = 0
        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: {
                self.panelView.transform = .identity
                self.dimmingControl.alpha = 1
            }
        )
    }

    private func configureLayout() {
        view.backgroundColor = .clear

        let actionStack = UIStackView(
            arrangedSubviews: [followedButton, reportButton, blockButton]
        )
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.axis = .vertical
        actionStack.spacing = 0
        actionStack.distribution = .fillEqually

        view.addSubview(dimmingControl)
        view.addSubview(panelView)
        panelView.addSubview(actionStack)
        panelView.addSubview(separatorView)
        panelView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            dimmingControl.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingControl.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingControl.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingControl.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            panelView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: 9
            ),
            panelView.heightAnchor.constraint(equalToConstant: 284),

            actionStack.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 20),
            actionStack.leadingAnchor.constraint(equalTo: panelView.leadingAnchor),
            actionStack.trailingAnchor.constraint(equalTo: panelView.trailingAnchor),
            actionStack.heightAnchor.constraint(equalToConstant: 174),

            separatorView.topAnchor.constraint(
                equalTo: actionStack.bottomAnchor,
                constant: 10
            ),
            separatorView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1),

            cancelButton.topAnchor.constraint(equalTo: separatorView.bottomAnchor),
            cancelButton.leadingAnchor.constraint(equalTo: panelView.leadingAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: panelView.trailingAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: panelView.bottomAnchor)
        ])
    }

    private func configureInteractions() {
        dimmingControl.addTarget(
            self,
            action: #selector(cancelSelected),
            for: .touchUpInside
        )
    }

    private func makeActionButton(
        title: String,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIColor.black.withAlphaComponent(0.78), for: .normal)
        button.titleLabel?.font = ZixyFontBook.bold(size: 21, relativeTo: .title3)
        button.accessibilityLabel = title
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func followedSelected() {
        let action = onFollowed
        dismissSheet(completion: action)
    }

    @objc private func reportSelected() {
        let action = onReport
        dismissSheet(completion: action)
    }

    @objc private func blockSelected() {
        let action = onBlock
        dismissSheet(completion: action)
    }

    @objc private func cancelSelected() {
        dismissSheet()
    }

    private func dismissSheet(completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: {
                self.panelView.transform = CGAffineTransform(
                    translationX: 0,
                    y: self.panelView.bounds.height
                )
                self.dimmingControl.alpha = 0
            },
            completion: { _ in
                self.dismiss(animated: false, completion: completion)
            }
        )
    }
}
