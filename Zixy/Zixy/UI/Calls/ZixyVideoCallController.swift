import UIKit

final class ZixyVideoCallController: UIViewController {

    private let participantName: String
    private var callingAnimationTimer: Timer?
    private var callingFrame = 0
    private var isEndingCall = false

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView(image: ZixyImageLibrary.callBackground)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private let blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemMaterialDark)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()

    private let dimmingView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.08)
        view.isUserInteractionEnabled = false
        return view
    }()

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView(image: ZixyImageLibrary.callAvatar)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 61
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ZixyFontBook.bold(size: 24, relativeTo: .title2)
        label.textColor = .white
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ZixyFontBook.bold(size: 18, relativeTo: .headline)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.72
        return label
    }()

    private let endCallButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(ZixyImageLibrary.callEnd, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.accessibilityLabel = "End call"
        button.accessibilityHint = "Returns to the previous screen"
        return button
    }()

    init(participantName: String = "Katrina✨Ray") {
        self.participantName = participantName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLayout()
        configureInteractions()
        nameLabel.text = participantName
        updateCallingText()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        startCallingAnimation()
        animateContentIn()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        callingAnimationTimer?.invalidate()
        callingAnimationTimer = nil
    }

    private func configureLayout() {
        view.backgroundColor = .black
        view.addSubview(backgroundImageView)
        view.addSubview(blurView)
        view.addSubview(dimmingView)
        view.addSubview(avatarImageView)
        view.addSubview(nameLabel)
        view.addSubview(statusLabel)
        view.addSubview(endCallButton)

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            avatarImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(
                equalTo: view.centerYAnchor,
                constant: -4
            ),
            avatarImageView.widthAnchor.constraint(equalToConstant: 122),
            avatarImageView.heightAnchor.constraint(equalTo: avatarImageView.widthAnchor),

            nameLabel.topAnchor.constraint(
                equalTo: avatarImageView.bottomAnchor,
                constant: 24
            ),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            statusLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            endCallButton.topAnchor.constraint(
                equalTo: statusLabel.bottomAnchor,
                constant: 84
            ),
            endCallButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            endCallButton.widthAnchor.constraint(equalToConstant: 72),
            endCallButton.heightAnchor.constraint(equalTo: endCallButton.widthAnchor),
            endCallButton.bottomAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -40
            )
        ])
    }

    private func configureInteractions() {
        endCallButton.addTarget(
            self,
            action: #selector(endCall),
            for: .touchUpInside
        )
    }

    private func startCallingAnimation() {
        callingAnimationTimer?.invalidate()
        callingAnimationTimer = Timer.scheduledTimer(
            withTimeInterval: 0.55,
            repeats: true
        ) { [weak self] _ in
            self?.callingFrame = ((self?.callingFrame ?? 0) + 1) % 4
            self?.updateCallingText()
        }
    }

    private func updateCallingText() {
        let dots = String(repeating: ".", count: callingFrame)
        statusLabel.text = "You are calling \(participantName) \(dots)"
        statusLabel.accessibilityLabel = "Calling \(participantName)"
    }

    private func animateContentIn() {
        let contentViews = [
            avatarImageView,
            nameLabel,
            statusLabel,
            endCallButton
        ]
        contentViews.forEach {
            $0.alpha = 0
            $0.transform = CGAffineTransform(translationX: 0, y: 12)
        }
        UIView.animate(
            withDuration: 0.35,
            delay: 0.05,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: {
                contentViews.forEach {
                    $0.alpha = 1
                    $0.transform = .identity
                }
            }
        )
    }

    @objc private func endCall() {
        guard !isEndingCall else {
            return
        }
        isEndingCall = true
        endCallButton.isEnabled = false
        callingAnimationTimer?.invalidate()
        callingAnimationTimer = nil

        UIView.animate(
            withDuration: 0.18,
            animations: {
                self.view.alpha = 0
            },
            completion: { _ in
                if self.navigationController?.viewControllers.count ?? 0 > 1 {
                    self.navigationController?.popViewController(animated: false)
                } else {
                    self.dismiss(animated: false)
                }
            }
        )
    }
}
