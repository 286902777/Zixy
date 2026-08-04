import UIKit

@MainActor
final class ZixySecureContentView: UIView {

    let contentView = UIView()

    private let secureTextField = ZixyNonEditingSecureTextField()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSecureHierarchy()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSecureHierarchy()
    }

    private func configureSecureHierarchy() {
        clipsToBounds = true

        secureTextField.translatesAutoresizingMaskIntoConstraints = false
        secureTextField.backgroundColor = .clear
        secureTextField.borderStyle = .none
        secureTextField.isSecureTextEntry = true
        secureTextField.textColor = .clear
        secureTextField.tintColor = .clear
        addSubview(secureTextField)

        NSLayoutConstraint.activate([
            secureTextField.topAnchor.constraint(equalTo: topAnchor),
            secureTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            secureTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
            secureTextField.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        secureTextField.layoutIfNeeded()
        let protectedContainer = secureTextField.subviews.first {
            String(describing: type(of: $0)).contains("CanvasView")
        } ?? secureTextField

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        protectedContainer.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: protectedContainer.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: protectedContainer.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: protectedContainer.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: protectedContainer.bottomAnchor)
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
                forName: UIApplication.willResignActiveNotification,
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
