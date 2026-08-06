import UIKit

@MainActor
final class ZixySecureContentView: UIView {

    let contentView = UIView()

    private enum Installation {
        static let retryDelay: TimeInterval = 0.05
        static let maximumAttempts = 10
    }

    private let secureTextField = ZixyNonEditingSecureTextField()
    private var installationWorkItem: DispatchWorkItem?
    private var installationAttempts = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSecureHierarchy()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSecureHierarchy()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        installProtectedContainerIfAvailable()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        guard window != nil else {
            installationWorkItem?.cancel()
            installationWorkItem = nil
            installationAttempts = 0
            return
        }
        installProtectedContainerIfAvailable()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        installProtectedContainerIfAvailable()
    }

    private func configureSecureHierarchy() {
        clipsToBounds = true

        secureTextField.translatesAutoresizingMaskIntoConstraints = false
        secureTextField.backgroundColor = .clear
        secureTextField.borderStyle = .none
        secureTextField.isSecureTextEntry = true
        secureTextField.text = " "
        secureTextField.textColor = .clear
        secureTextField.tintColor = .clear
        secureTextField.isAccessibilityElement = false
        addSubview(secureTextField)

        NSLayoutConstraint.activate([
            secureTextField.topAnchor.constraint(equalTo: topAnchor),
            secureTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            secureTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
            secureTextField.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
    }

    private func installProtectedContainerIfAvailable() {
        guard contentView.superview == nil else {
            return
        }

        secureTextField.layoutIfNeeded()
        guard let container = findSecureCanvas(in: secureTextField) else {
            scheduleInstallationRetryIfNeeded()
            return
        }

        installationWorkItem?.cancel()
        installationWorkItem = nil
        installationAttempts = 0
        embedContent(in: container)
    }

    private func scheduleInstallationRetryIfNeeded() {
        guard window != nil,
              installationWorkItem == nil,
              installationAttempts < Installation.maximumAttempts else {
            return
        }

        installationAttempts += 1
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            self.installationWorkItem = nil
            self.installProtectedContainerIfAvailable()
        }
        installationWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Installation.retryDelay,
            execute: workItem
        )
    }

    private func findSecureCanvas(in root: UIView) -> UIView? {
        for child in root.subviews where child !== contentView {
            let className = String(describing: type(of: child))
            if className.contains("CanvasView") {
                return child
            }
            if let nestedCanvas = findSecureCanvas(in: child) {
                return nestedCanvas
            }
        }
        return nil
    }

    private func embedContent(in container: UIView) {
        guard contentView.superview == nil else {
            return
        }
        container.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: container.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}

private final class ZixyNonEditingSecureTextField: UITextField {

    override var canBecomeFirstResponder: Bool {
        false
    }
}

@MainActor
final class ZixyCapturePrivacyGuard {

    static let shared = ZixyCapturePrivacyGuard()

    private weak var protectedWindow: UIWindow?
    private var privacyOverlay: UIView?
    private var observers: [NSObjectProtocol] = []

    private init() {}

    func activate(in window: UIWindow) {
        startMonitoring(in: window)
    }

    func startMonitoring(in window: UIWindow) {
        protectedWindow = window
        startObservingIfNeeded()
        updatePrivacyOverlay()
    }

    func deactivate() {
        stopMonitoring()
    }

    func stopMonitoring() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        hidePrivacyOverlay()
        protectedWindow = nil
    }

    private func startObservingIfNeeded() {
        guard observers.isEmpty else {
            return
        }

        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: UIScreen.capturedDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.updatePrivacyOverlay()
                }
            },
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.showPrivacyOverlay()
                }
            },
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.updatePrivacyOverlay()
                }
            }
        ]
    }

    private func updatePrivacyOverlay() {
        let screen = protectedWindow?.windowScene?.screen ?? UIScreen.main
        if screen.isCaptured {
            showPrivacyOverlay()
        } else {
            hidePrivacyOverlay()
        }
    }

    private func showPrivacyOverlay() {
        guard privacyOverlay == nil, let window = targetWindow() else {
            return
        }

        let overlay = UIImageView(image: ZixyImageLibrary.launchBackground)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.contentMode = .scaleAspectFill
        overlay.clipsToBounds = true
        overlay.isUserInteractionEnabled = true
        overlay.accessibilityLabel = "Protected content hidden"
        window.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: window.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: window.bottomAnchor)
        ])
        privacyOverlay = overlay
    }

    private func hidePrivacyOverlay() {
        privacyOverlay?.removeFromSuperview()
        privacyOverlay = nil
    }

    private func targetWindow() -> UIWindow? {
        if let protectedWindow {
            return protectedWindow
        }

        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}
