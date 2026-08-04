import UIKit

@MainActor
final class ZixyCapturePrivacyGuard {

    static let shared = ZixyCapturePrivacyGuard()

    private enum Configuration {
        static let protectionDelay: TimeInterval = 1
    }

    private weak var protectedWindow: UIWindow?
    private var privacyOverlay: UIView?
    private var observers: [NSObjectProtocol] = []
    private var pendingInstallations: [ObjectIdentifier: DispatchWorkItem] = [:]
    private var protectionTokens: [ObjectIdentifier: ZixyCaptureProtectionToken] = [:]

    private init() {}

    func activate(in window: UIWindow) {
        startMonitoring(in: window)
        window.subviews.forEach(protect)
    }

    func startMonitoring(in window: UIWindow) {
        protectedWindow = window
        startObservingIfNeeded()
        updatePrivacyOverlay()
    }

    func protect(_ view: UIView) {
        let identifier = ObjectIdentifier(view)
        guard protectionTokens[identifier] == nil else {
            return
        }

        pendingInstallations.removeValue(forKey: identifier)?.cancel()
        let workItem = DispatchWorkItem { [weak self, weak view] in
            guard let self, let view else {
                return
            }
            pendingInstallations[identifier] = nil
            guard protectionTokens[identifier] == nil else {
                return
            }
            protectionTokens[identifier] = view.makeCaptureProtectionToken()
        }
        pendingInstallations[identifier] = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Configuration.protectionDelay,
            execute: workItem
        )
    }

    func removeProtection(from view: UIView) {
        let identifier = ObjectIdentifier(view)
        pendingInstallations.removeValue(forKey: identifier)?.cancel()
        protectionTokens.removeValue(forKey: identifier)?.restore()
    }

    func deactivate() {
        pendingInstallations.values.forEach { $0.cancel() }
        pendingInstallations.removeAll()

        protectionTokens.values.forEach { $0.restore() }
        protectionTokens.removeAll()

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

@MainActor
private final class ZixyCaptureProtectionToken {

    private weak var protectedView: UIView?
    private weak var originalSuperlayer: CALayer?
    private let originalLayerIndex: Int
    private let secureTextField: UITextField
    private let constraints: [NSLayoutConstraint]
    private var isRestored = false

    init(
        protectedView: UIView,
        originalSuperlayer: CALayer,
        originalLayerIndex: Int,
        secureTextField: UITextField,
        constraints: [NSLayoutConstraint]
    ) {
        self.protectedView = protectedView
        self.originalSuperlayer = originalSuperlayer
        self.originalLayerIndex = originalLayerIndex
        self.secureTextField = secureTextField
        self.constraints = constraints
    }

    func restore() {
        guard !isRestored else {
            return
        }
        isRestored = true
        NSLayoutConstraint.deactivate(constraints)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let protectedView, let originalSuperlayer {
            protectedView.layer.removeFromSuperlayer()
            let layerCount = originalSuperlayer.sublayers?.count ?? 0
            originalSuperlayer.insertSublayer(
                protectedView.layer,
                at: UInt32(min(originalLayerIndex, layerCount))
            )
        }
        secureTextField.layer.removeFromSuperlayer()
        CATransaction.commit()

        secureTextField.removeFromSuperview()
        protectedView?.setNeedsLayout()
    }

    deinit {
        MainActor.assumeIsolated {
            restore()
        }
    }
}

@MainActor
private extension UIView {

    func makeCaptureProtectionToken() -> ZixyCaptureProtectionToken? {
        guard
            superview != nil,
            let originalSuperlayer = layer.superlayer,
            let originalLayerIndex = originalSuperlayer.sublayers?
                .firstIndex(where: { $0 === layer })
        else {
            return nil
        }

        let secureTextField = UITextField()
        secureTextField.translatesAutoresizingMaskIntoConstraints = false
        secureTextField.backgroundColor = .clear
        secureTextField.isUserInteractionEnabled = false
        secureTextField.isSecureTextEntry = true
        insertSubview(secureTextField, at: 0)

        let constraints = [
            secureTextField.topAnchor.constraint(equalTo: topAnchor),
            secureTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            secureTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
            secureTextField.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
        layoutIfNeeded()
        secureTextField.layoutIfNeeded()

        guard let secureContainerLayer = secureTextField.layer.sublayers?.last else {
            NSLayoutConstraint.deactivate(constraints)
            secureTextField.removeFromSuperview()
            return nil
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        originalSuperlayer.addSublayer(secureTextField.layer)
        secureContainerLayer.addSublayer(layer)
        CATransaction.commit()

        return ZixyCaptureProtectionToken(
            protectedView: self,
            originalSuperlayer: originalSuperlayer,
            originalLayerIndex: originalLayerIndex,
            secureTextField: secureTextField,
            constraints: constraints
        )
    }
}
