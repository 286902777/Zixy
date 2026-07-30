import UIKit

class ZixyAuthCanvasController: UIViewController, UITextFieldDelegate {

    let scrollView = UIScrollView()
    let scrollContentView = UIView()
    var minimumScrollBottomInset: CGFloat = 0 {
        didSet {
            scrollContentMinimumHeightConstraint?.constant =
                -minimumScrollBottomInset
            applyResolvedScrollInsets()
        }
    }

    private let backgroundImageView = ZixyImageLibrary.makePageBackgroundView()
    private var keyboardObservers: [NSObjectProtocol] = []
    private var keyboardOverlap: CGFloat = 0
    private var scrollContentMinimumHeightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureBackground()
        configureScrollView()
        configureDismissGesture()
        observeKeyboard()
    }

    deinit {
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
    }

    func registerTextFields(in view: UIView) {
        view.allTextFields.forEach {
            $0.delegate = self
            $0.returnKeyType = .done
            $0.addTarget(
                self,
                action: #selector(textFieldDidFinishEditing),
                for: .editingDidEndOnExit
            )
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return true
    }

    @objc private func textFieldDidFinishEditing() {
        view.endEditing(true)
    }

    private func configureBackground() {
        view.backgroundColor = ZixyColorPalette.pageBackground
        view.addSubview(backgroundImageView)
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollContentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true

        view.addSubview(scrollView)
        scrollView.addSubview(scrollContentView)

        let minimumHeightConstraint = scrollContentView.heightAnchor.constraint(
            greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor
        )
        scrollContentMinimumHeightConstraint = minimumHeightConstraint

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollContentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            minimumHeightConstraint
        ])
    }

    private func configureDismissGesture() {
        let gesture = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        gesture.cancelsTouchesInView = false
        view.addGestureRecognizer(gesture)
    }

    private func observeKeyboard() {
        let center = NotificationCenter.default
        keyboardObservers = [
            center.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.updateForKeyboard(notification)
            },
            center.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.updateForKeyboard(notification)
            }
        ]
    }

    private func updateForKeyboard(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let frame = userInfo[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect,
            let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey]
                as? TimeInterval,
            let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey]
                as? UInt
        else {
            return
        }

        let keyboardFrame = view.convert(frame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
        let options = UIView.AnimationOptions(rawValue: curveValue << 16)

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [options, .beginFromCurrentState],
            animations: {
                self.keyboardOverlap = overlap
                self.applyResolvedScrollInsets()
                self.view.layoutIfNeeded()
            }
        )

        guard overlap > 0, let responder = view.currentFirstResponder else {
            return
        }
        let rect = responder.convert(responder.bounds, to: scrollView)
        scrollView.scrollRectToVisible(rect.insetBy(dx: 0, dy: -24), animated: true)
    }

    private func applyResolvedScrollInsets() {
        let bottomInset = max(minimumScrollBottomInset, keyboardOverlap)
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

private extension UIView {

    var allTextFields: [UITextField] {
        subviews.flatMap { view in
            (view as? UITextField).map { [$0] } ?? view.allTextFields
        }
    }

    var currentFirstResponder: UIView? {
        if isFirstResponder {
            return self
        }
        return subviews.lazy.compactMap(\.currentFirstResponder).first
    }
}
