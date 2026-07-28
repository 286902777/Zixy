import UIKit

final class ZixyScreenHeader: UIView {

    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let buttonSize: CGFloat = 40
        static let cornerRadius: CGFloat = 11
        static let titleSize: CGFloat = 27
    }

    let backButton: UIButton = {
        let button = UIButton(type: .system)
        let configuration = UIImage.SymbolConfiguration(
            pointSize: 20,
            weight: .black
        )
        button.setImage(
            UIImage(systemName: "arrow.left", withConfiguration: configuration),
            for: .normal
        )
        button.tintColor = .white
        button.backgroundColor = ZixyColorPalette.ink
        button.layer.cornerRadius = Layout.cornerRadius
        button.accessibilityLabel = "Back"
        return button
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ZixyFontBook.bold(size: Layout.titleSize, relativeTo: .title2)
        label.textColor = ZixyColorPalette.ink
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        return label
    }()

    private let rightContainer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func configure(
        title: String,
        showsBackButton: Bool,
        rightView: UIView? = nil
    ) {
        titleLabel.text = title
        backButton.isHidden = !showsBackButton

        rightContainer.subviews.forEach { $0.removeFromSuperview() }
        guard let rightView else {
            return
        }

        rightView.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.addSubview(rightView)
        NSLayoutConstraint.activate([
            rightView.centerXAnchor.constraint(
                equalTo: rightContainer.centerXAnchor
            ),
            rightView.centerYAnchor.constraint(
                equalTo: rightContainer.centerYAnchor
            ),
            rightView.widthAnchor.constraint(
                lessThanOrEqualToConstant: Layout.buttonSize
            ),
            rightView.heightAnchor.constraint(
                lessThanOrEqualToConstant: Layout.buttonSize
            )
        ])
    }

    private func configureView() {
        backgroundColor = .clear

        [backButton, titleLabel, rightContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: Layout.horizontalInset
            ),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.widthAnchor.constraint(
                equalToConstant: Layout.buttonSize
            ),
            backButton.heightAnchor.constraint(
                equalToConstant: Layout.buttonSize
            ),

            rightContainer.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            rightContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightContainer.widthAnchor.constraint(
                equalToConstant: Layout.buttonSize
            ),
            rightContainer.heightAnchor.constraint(
                equalToConstant: Layout.buttonSize
            ),

            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: backButton.trailingAnchor,
                constant: 12
            ),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: rightContainer.leadingAnchor,
                constant: -12
            )
        ])
    }
}
