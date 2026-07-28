import UIKit

final class ZixyPreviewController: ZixyScreenController {

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation(title: "Following", showsBackButton: true)
        configurePreview()
    }

    private func configurePreview() {
        let avatarImageView = UIImageView(image: ZixyImageLibrary.userAvatar)
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 48
        avatarImageView.layer.borderWidth = 3
        avatarImageView.layer.borderColor = UIColor.white.cgColor
        avatarImageView.accessibilityLabel = "User avatar"

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "User Profile"
        label.font = ZixyFontBook.bold(size: 18, relativeTo: .body)
        label.textColor = ZixyColorPalette.ink.withAlphaComponent(0.6)

        contentView.addSubview(avatarImageView)
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            avatarImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            avatarImageView.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 24
            ),
            avatarImageView.widthAnchor.constraint(equalToConstant: 96),
            avatarImageView.heightAnchor.constraint(equalTo: avatarImageView.widthAnchor),
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.topAnchor.constraint(
                equalTo: avatarImageView.bottomAnchor,
                constant: 12
            )
        ])
    }
}
