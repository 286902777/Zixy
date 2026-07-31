import UIKit

extension UIViewController {

    func showToast(_ message: String) {
        let toastView = UIView()
        toastView.translatesAutoresizingMaskIntoConstraints = false
        toastView.backgroundColor = UIColor.black.withAlphaComponent(0.82)
        toastView.layer.cornerRadius = 14
        toastView.clipsToBounds = true
        toastView.alpha = 0

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.font = ZixyFontBook.bold(size: 14, relativeTo: .footnote)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0

        toastView.addSubview(label)
        view.addSubview(toastView)
        NSLayoutConstraint.activate([
            toastView.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor,
                constant: 28
            ),
            toastView.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: -28
            ),
            toastView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -28
            ),
            toastView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            label.topAnchor.constraint(equalTo: toastView.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: toastView.bottomAnchor, constant: -8)
        ])

        UIView.animate(withDuration: 0.2) {
            toastView.alpha = 1
        }
        UIView.animate(
            withDuration: 0.2,
            delay: 1.7,
            options: [.curveEaseInOut],
            animations: {
                toastView.alpha = 0
            },
            completion: { _ in
                toastView.removeFromSuperview()
            }
        )
    }
}
