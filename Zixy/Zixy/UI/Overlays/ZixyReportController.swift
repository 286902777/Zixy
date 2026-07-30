import UIKit

final class ZixyReportController: ZixyScreenController {

    private enum Reason: String, CaseIterable {
        case hateSpeech = "Hate speech or symbols"
        case harassment = "Harassment or bullying"
        case scam = "Scam or fraud"
        case pornography = "Pornographic content"
        case rights = "Infringement of rights"
        case other = "Other"
    }

    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let sectionTitleHeight: CGFloat = 24
        static let reasonRowHeight: CGFloat = 61
        static let detailsHeight: CGFloat = 94
        static let submitWidth: CGFloat = 284
        static let submitHeight: CGFloat = 74
        static let submitBottomSpacing: CGFloat = 6
    }

    private let reportedUserName: String
    private let isCurrentUser: Bool
    private var selectedReason: Reason = .hateSpeech
    private var reasonRows: [ZixyReportReasonRow] = []
    private var isSubmitting = false
    private var submitBottomConstraint: NSLayoutConstraint?

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()

    private let scrollContentView = UIView()
    private let formView = UIView()
    private let reasonCard = UIView()
    private let reasonStack = UIStackView()

    private let reasonTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Why are you reporting this?"
        label.font = ZixyFontBook.bold(size: 16, relativeTo: .headline)
        label.textColor = UIColor.black.withAlphaComponent(0.32)
        return label
    }()

    private let detailsTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Add more details (optional)"
        label.font = ZixyFontBook.bold(size: 16, relativeTo: .headline)
        label.textColor = UIColor.black.withAlphaComponent(0.32)
        return label
    }()

    private let detailsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        return view
    }()

    private let detailsTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        textView.font = ZixyFontBook.bold(size: 14, relativeTo: .body)
        textView.textColor = UIColor.black.withAlphaComponent(0.82)
        textView.tintColor = UIColor(
            red: 62 / 255,
            green: 103 / 255,
            blue: 1,
            alpha: 1
        )
        textView.returnKeyType = .default
        textView.textContainerInset = UIEdgeInsets(
            top: 13,
            left: 12,
            bottom: 12,
            right: 12
        )
        textView.accessibilityLabel = "Additional report information"
        return textView
    }()

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Provide additional information"
        label.font = ZixyFontBook.bold(size: 14, relativeTo: .body)
        label.textColor = UIColor.black.withAlphaComponent(0.82)
        label.isUserInteractionEnabled = false
        return label
    }()

    private let submitButton = ZixyGradientActionButton(
        title: "Submit Report",
        height: Layout.submitHeight,
        titleSize: 20
    )

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    init(reportedUserName: String, isCurrentUser: Bool) {
        self.reportedUserName = reportedUserName
        self.isCurrentUser = isCurrentUser
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation(title: "Report")
        configureReasonRows()
        configureLayout()
        configureInteractions()
        observeKeyboard()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isMovingFromParent || navigationController?.isBeingDismissed == true else {
            return
        }
        NotificationCenter.default.removeObserver(self)
    }

    private func configureReasonRows() {
        reasonRows = Reason.allCases.enumerated().map { index, reason in
            let row = ZixyReportReasonRow(
                title: reason.rawValue,
                showsSeparator: index < Reason.allCases.count - 1
            )
            row.isSelected = reason == selectedReason
            row.addAction(
                UIAction { [weak self] _ in
                    self?.select(reason)
                },
                for: .touchUpInside
            )
            return row
        }

        reasonStack.translatesAutoresizingMaskIntoConstraints = false
        reasonStack.axis = .vertical
        reasonStack.alignment = .fill
        reasonStack.distribution = .fill
        reasonStack.spacing = 0
        reasonRows.forEach(reasonStack.addArrangedSubview)
    }

    private func configureLayout() {
        scrollContentView.translatesAutoresizingMaskIntoConstraints = false
        formView.translatesAutoresizingMaskIntoConstraints = false
        reasonCard.translatesAutoresizingMaskIntoConstraints = false
        reasonCard.backgroundColor = .white
        reasonCard.layer.cornerRadius = 12

        contentView.addSubview(scrollView)
        contentView.addSubview(submitButton)
        scrollView.addSubview(scrollContentView)
        scrollContentView.addSubview(formView)
        formView.addSubview(reasonTitleLabel)
        formView.addSubview(reasonCard)
        reasonCard.addSubview(reasonStack)
        formView.addSubview(detailsTitleLabel)
        formView.addSubview(detailsContainer)
        detailsContainer.addSubview(detailsTextView)
        detailsContainer.addSubview(placeholderLabel)
        submitButton.addSubview(loadingIndicator)

        let bottomConstraint = submitButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: -Layout.submitBottomSpacing
        )
        submitBottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            submitButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            submitButton.widthAnchor.constraint(
                equalToConstant: Layout.submitWidth
            ),
            bottomConstraint,

            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(
                equalTo: submitButton.topAnchor,
                constant: -12
            ),

            scrollContentView.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor
            ),
            scrollContentView.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor
            ),
            scrollContentView.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor
            ),
            scrollContentView.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor
            ),
            scrollContentView.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor
            ),

            formView.topAnchor.constraint(equalTo: scrollContentView.topAnchor),
            formView.leadingAnchor.constraint(
                equalTo: scrollContentView.leadingAnchor,
                constant: Layout.horizontalInset
            ),
            formView.trailingAnchor.constraint(
                equalTo: scrollContentView.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            formView.bottomAnchor.constraint(
                equalTo: scrollContentView.bottomAnchor,
                constant: -18
            ),

            reasonTitleLabel.topAnchor.constraint(
                equalTo: formView.topAnchor,
                constant: 8
            ),
            reasonTitleLabel.leadingAnchor.constraint(equalTo: formView.leadingAnchor),
            reasonTitleLabel.trailingAnchor.constraint(
                equalTo: formView.trailingAnchor
            ),
            reasonTitleLabel.heightAnchor.constraint(
                equalToConstant: Layout.sectionTitleHeight
            ),

            reasonCard.topAnchor.constraint(
                equalTo: reasonTitleLabel.bottomAnchor,
                constant: 8
            ),
            reasonCard.leadingAnchor.constraint(equalTo: formView.leadingAnchor),
            reasonCard.trailingAnchor.constraint(equalTo: formView.trailingAnchor),

            reasonStack.topAnchor.constraint(equalTo: reasonCard.topAnchor),
            reasonStack.leadingAnchor.constraint(equalTo: reasonCard.leadingAnchor),
            reasonStack.trailingAnchor.constraint(equalTo: reasonCard.trailingAnchor),
            reasonStack.bottomAnchor.constraint(equalTo: reasonCard.bottomAnchor),

            detailsTitleLabel.topAnchor.constraint(
                equalTo: reasonCard.bottomAnchor,
                constant: 12
            ),
            detailsTitleLabel.leadingAnchor.constraint(equalTo: formView.leadingAnchor),
            detailsTitleLabel.trailingAnchor.constraint(
                equalTo: formView.trailingAnchor
            ),
            detailsTitleLabel.heightAnchor.constraint(
                equalToConstant: Layout.sectionTitleHeight
            ),

            detailsContainer.topAnchor.constraint(
                equalTo: detailsTitleLabel.bottomAnchor,
                constant: 4
            ),
            detailsContainer.leadingAnchor.constraint(equalTo: formView.leadingAnchor),
            detailsContainer.trailingAnchor.constraint(equalTo: formView.trailingAnchor),
            detailsContainer.bottomAnchor.constraint(equalTo: formView.bottomAnchor),
            detailsContainer.heightAnchor.constraint(
                equalToConstant: Layout.detailsHeight
            ),

            detailsTextView.topAnchor.constraint(
                equalTo: detailsContainer.topAnchor
            ),
            detailsTextView.leadingAnchor.constraint(
                equalTo: detailsContainer.leadingAnchor
            ),
            detailsTextView.trailingAnchor.constraint(
                equalTo: detailsContainer.trailingAnchor
            ),
            detailsTextView.bottomAnchor.constraint(
                equalTo: detailsContainer.bottomAnchor
            ),

            placeholderLabel.topAnchor.constraint(
                equalTo: detailsContainer.topAnchor,
                constant: 15
            ),
            placeholderLabel.leadingAnchor.constraint(
                equalTo: detailsContainer.leadingAnchor,
                constant: 17
            ),
            placeholderLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: detailsContainer.trailingAnchor,
                constant: -12
            ),

            loadingIndicator.centerYAnchor.constraint(
                equalTo: submitButton.centerYAnchor
            ),
            loadingIndicator.centerXAnchor.constraint(
                equalTo: submitButton.centerXAnchor,
                constant: 70
            )
        ])

        reasonRows.forEach {
            $0.heightAnchor.constraint(
                equalToConstant: Layout.reasonRowHeight
            ).isActive = true
        }
    }

    private func configureInteractions() {
        detailsTextView.delegate = self
        submitButton.addTarget(
            self,
            action: #selector(submitReport),
            for: .touchUpInside
        )

        let doneToolbar = UIToolbar()
        doneToolbar.sizeToFit()
        doneToolbar.items = [
            UIBarButtonItem(
                systemItem: .flexibleSpace
            ),
            UIBarButtonItem(
                title: "Done",
                style: .done,
                target: self,
                action: #selector(dismissKeyboard)
            )
        ]
        detailsTextView.inputAccessoryView = doneToolbar

        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
    }

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardChange(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private func select(_ reason: Reason) {
        selectedReason = reason
        for (index, row) in reasonRows.enumerated() {
            row.isSelected = Reason.allCases[index] == selectedReason
        }
    }

    private func setSubmitting(_ submitting: Bool) {
        isSubmitting = submitting
        submitButton.isUserInteractionEnabled = !submitting
        submitButton.alpha = submitting ? 0.78 : 1
        submitButton.setTitle(submitting ? "Submitting..." : "Submit Report")
        if submitting {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }

    @objc private func submitReport() {
        guard !isCurrentUser else {
            showToast("You cannot report your own account.")
            return
        }
        guard !reportedUserName.isEmpty else {
            showToast("Unable to identify the reported user.")
            return
        }
        guard !isSubmitting else {
            return
        }

        view.endEditing(true)
        setSubmitting(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else {
                return
            }
            setSubmitting(false)
            if let navigationController,
               navigationController.viewControllers.count > 1 {
                let previousController = navigationController.viewControllers[
                    navigationController.viewControllers.count - 2
                ]
                navigationController.popViewController(animated: true)
                previousController.showToast("Report submitted.")
            } else {
                showToast("Report submitted.")
            }
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func handleKeyboardChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let frameValue = userInfo[
                  UIResponder.keyboardFrameEndUserInfoKey
              ] as? NSValue else {
            return
        }

        let keyboardFrame = view.convert(frameValue.cgRectValue, from: nil)
        let safeBottom = view.safeAreaLayoutGuide.layoutFrame.maxY
        let overlap = max(0, safeBottom - keyboardFrame.minY)
        submitBottomConstraint?.constant = -(
            overlap + Layout.submitBottomSpacing
        )

        let duration = userInfo[
            UIResponder.keyboardAnimationDurationUserInfoKey
        ] as? TimeInterval ?? 0.25
        let curve = userInfo[
            UIResponder.keyboardAnimationCurveUserInfoKey
        ] as? UInt ?? 7
        let options = UIView.AnimationOptions(rawValue: curve << 16)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [options, .beginFromCurrentState],
            animations: {
                self.view.layoutIfNeeded()
                let detailsRect = self.scrollView.convert(
                    self.detailsContainer.bounds,
                    from: self.detailsContainer
                )
                self.scrollView.scrollRectToVisible(
                    detailsRect.insetBy(dx: 0, dy: -16),
                    animated: false
                )
            }
        )
    }
}

extension ZixyReportController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
}

extension ZixyReportController: UIGestureRecognizerDelegate {

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard let touchedView = touch.view else {
            return true
        }
        return !touchedView.isDescendant(of: detailsTextView)
    }
}

private final class ZixyReportReasonRow: UIControl {

    private let checkmarkView = UIImageView(
        image: ZixyImageLibrary.reportCheckmark
    )

    override var isSelected: Bool {
        didSet {
            checkmarkView.isHidden = !isSelected
            accessibilityTraits = isSelected
                ? [.button, .selected]
                : .button
        }
    }

    init(title: String, showsSeparator: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityLabel = title
        accessibilityTraits = .button

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = ZixyFontBook.bold(size: 15, relativeTo: .body)
        titleLabel.textColor = UIColor.black.withAlphaComponent(0.82)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.isUserInteractionEnabled = false

        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.contentMode = .scaleAspectFit
        checkmarkView.isHidden = true
        checkmarkView.isUserInteractionEnabled = false

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor.black.withAlphaComponent(0.08)
        separator.isHidden = !showsSeparator
        separator.isUserInteractionEnabled = false

        addSubview(titleLabel)
        addSubview(checkmarkView)
        addSubview(separator)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 17),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: checkmarkView.leadingAnchor,
                constant: -10
            ),

            checkmarkView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -17
            ),
            checkmarkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 20),
            checkmarkView.heightAnchor.constraint(equalToConstant: 20),

            separator.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 17
            ),
            separator.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -17
            ),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted
                ? UIColor.black.withAlphaComponent(0.035)
                : .clear
        }
    }
}
