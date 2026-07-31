import UIKit

final class ZixyLoadingOverlay: UIView {

    private let spinner = UIActivityIndicatorView(style: .large)
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black.withAlphaComponent(0.22)
        isHidden = true

        let panel = UIView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = UIColor.white.withAlphaComponent(0.97)
        panel.layer.cornerRadius = 18

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .systemBlue
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = ZixyFontBook.bold(size: 13, relativeTo: .footnote)
        messageLabel.textColor = UIColor.black.withAlphaComponent(0.72)
        messageLabel.textAlignment = .center

        addSubview(panel)
        panel.addSubview(spinner)
        panel.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 148),
            panel.heightAnchor.constraint(equalToConstant: 104),
            spinner.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: panel.topAnchor, constant: 18),
            messageLabel.topAnchor.constraint(
                equalTo: spinner.bottomAnchor,
                constant: 6
            ),
            messageLabel.leadingAnchor.constraint(
                equalTo: panel.leadingAnchor,
                constant: 8
            ),
            messageLabel.trailingAnchor.constraint(
                equalTo: panel.trailingAnchor,
                constant: -8
            )
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(message: String) {
        messageLabel.text = message
        accessibilityLabel = message
        isHidden = false
        spinner.startAnimating()
    }

    func hide() {
        spinner.stopAnimating()
        isHidden = true
    }
}
