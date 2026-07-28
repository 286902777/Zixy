import UIKit

final class ZixyDockBar: UIView {

    struct Item {
        let normalImageName: String
        let selectedImageName: String
        let accessibilityLabel: String
    }

    static let contentHeight: CGFloat = 64

    var onSelectionChanged: ((Int) -> Void)?

    private let buttonStack = UIStackView()
    private var items: [Item] = []
    private var buttons: [UIButton] = []

    private(set) var selectedIndex = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func configure(items: [Item], selectedIndex: Int = 0) {
        self.items = items
        self.selectedIndex = min(
            max(selectedIndex, 0),
            max(items.count - 1, 0)
        )

        buttons.forEach { button in
            buttonStack.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        buttons = items.enumerated().map(makeButton)
        buttons.forEach(buttonStack.addArrangedSubview)
        updateImages()
    }

    func select(index: Int, sendsAction: Bool) {
        guard
            items.indices.contains(index),
            buttons.indices.contains(index),
            buttons[index].isEnabled
        else {
            return
        }
        selectedIndex = index
        updateImages()
        if sendsAction {
            onSelectionChanged?(index)
        }
    }

    func setEnabled(_ enabled: Bool, at index: Int) {
        guard buttons.indices.contains(index) else {
            return
        }
        let button = buttons[index]
        button.isEnabled = enabled
        button.alpha = 1
        button.accessibilityValue = enabled ? nil : "Sign in required"
    }

    private func configureView() {
        backgroundColor = .white
        layer.cornerRadius = 28
        layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner
        ]
        layer.masksToBounds = true

        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.alignment = .fill
        buttonStack.distribution = .fillEqually

        addSubview(buttonStack)
        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: topAnchor),
            buttonStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            buttonStack.heightAnchor.constraint(
                equalToConstant: Self.contentHeight
            )
        ])
    }

    private func makeButton(
        index: Int,
        item: Item
    ) -> UIButton {
        let button = UIButton(type: .custom)
        button.tag = index
        button.adjustsImageWhenDisabled = false
        button.accessibilityLabel = item.accessibilityLabel
        button.accessibilityTraits = .button
        button.addTarget(
            self,
            action: #selector(selectButton(_:)),
            for: .touchUpInside
        )
        return button
    }

    private func updateImages() {
        for (index, button) in buttons.enumerated() {
            let isSelected = index == selectedIndex
            let imageName = isSelected
                ? items[index].selectedImageName
                : items[index].normalImageName
            button.setImage(
                UIImage(named: imageName)?.withRenderingMode(.alwaysOriginal),
                for: .normal
            )
            button.isSelected = isSelected
            button.accessibilityTraits = isSelected
                ? [.button, .selected]
                : .button
        }
    }

    @objc private func selectButton(_ sender: UIButton) {
        select(index: sender.tag, sendsAction: true)
    }
}
