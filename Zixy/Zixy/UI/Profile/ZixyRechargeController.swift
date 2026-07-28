import StoreKit
import UIKit

final class ZixyRechargeController: ZixyScreenController {

    struct Tier {
        let productIdentifier: String?
        let coinAmount: Int
        let displayPrice: String
    }

    private enum Layout {
        static let horizontalInset: CGFloat = 19
        static let rowHeight: CGFloat = 62
        static let rowSpacing: CGFloat = 14
        static let headerHeight: CGFloat = 193
    }

    private enum Storage {
        static let balanceKey = "zixy_coin_balance"
        static let processedTransactionsKey = "zixy_processed_store_transactions"
    }

    private var currentBalance: Int
    private let tiers: [Tier]
    private var productsByIdentifier: [String: Product] = [:]
    private var processedTransactionIdentifiers: Set<String>
    private var isPurchasing = false
    private var productLoadingTask: Task<Void, Never>?
    private var transactionUpdatesTask: Task<Void, Never>?
    private var unfinishedTransactionsTask: Task<Void, Never>?
    private let loadingView = ZixyRechargeLoadingView()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = Layout.rowSpacing
        layout.sectionInset = UIEdgeInsets(
            top: 0,
            left: Layout.horizontalInset,
            bottom: 32,
            right: Layout.horizontalInset
        )
        layout.headerReferenceSize = CGSize(
            width: UIScreen.main.bounds.width,
            height: Layout.headerHeight
        )

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            ZixyRechargeTierCell.self,
            forCellWithReuseIdentifier: ZixyRechargeTierCell.reuseIdentifier
        )
        collectionView.register(
            ZixyRechargeHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ZixyRechargeHeaderView.reuseIdentifier
        )
        return collectionView
    }()

    init(
        balance: Int = 30_000,
        tiers: [Tier] = ZixyRechargeController.defaultTiers
    ) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Storage.balanceKey) == nil {
            defaults.set(balance, forKey: Storage.balanceKey)
        }
        currentBalance = defaults.integer(forKey: Storage.balanceKey)
        self.tiers = tiers
        processedTransactionIdentifiers = Set(
            defaults.stringArray(forKey: Storage.processedTransactionsKey) ?? []
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation(title: "Recharge")
        configureLayout()
        loadProducts()
        observeTransactions()
        processUnfinishedTransactions()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isMovingFromParent || navigationController?.isBeingDismissed == true else {
            return
        }
        productLoadingTask?.cancel()
        transactionUpdatesTask?.cancel()
        unfinishedTransactionsTask?.cancel()
        productLoadingTask = nil
        transactionUpdatesTask = nil
        unfinishedTransactionsTask = nil
    }

    private func configureLayout() {
        contentView.addSubview(collectionView)
        view.addSubview(loadingView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func selectTier(at indexPath: IndexPath) {
        guard !isPurchasing else {
            return
        }
        guard ZixySessionStore.isAuthenticated else {
            showToast("Sign in to make a purchase.")
            return
        }
        guard tiers.indices.contains(indexPath.item) else {
            return
        }
        let tier = tiers[indexPath.item]
        guard
            let identifier = tier.productIdentifier,
            let product = productsByIdentifier[identifier]
        else {
            showToast("This purchase is currently unavailable.")
            loadProducts()
            return
        }
        Task { [weak self] in
            await self?.purchase(product, for: tier)
        }
    }

    private func loadProducts() {
        productLoadingTask?.cancel()
        let identifiers = Set(tiers.compactMap(\.productIdentifier))
        guard !identifiers.isEmpty else {
            return
        }
        productLoadingTask = Task { [weak self] in
            do {
                let products = try await Product.products(for: identifiers)
                guard !Task.isCancelled else {
                    return
                }
                self?.productsByIdentifier = Dictionary(
                    uniqueKeysWithValues: products.map { ($0.id, $0) }
                )
                self?.collectionView.reloadData()
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                self?.productsByIdentifier = [:]
            }
        }
    }

    private func purchase(_ product: Product, for tier: Tier) async {
        guard !isPurchasing else {
            return
        }
        isPurchasing = true
        collectionView.isUserInteractionEnabled = false
        loadingView.show(message: "Processing purchase")
        defer {
            isPurchasing = false
            collectionView.isUserInteractionEnabled = true
            loadingView.hide()
        }

        do {
            switch try await product.purchase() {
            case let .success(result):
                await handleTransaction(result, expectedTier: tier, showsToast: true)
            case .pending:
                showToast("Purchase is pending approval.")
            case .userCancelled:
                break
            @unknown default:
                showToast("Unable to complete the purchase.")
            }
        } catch {
            showToast("Unable to complete the purchase.")
        }
    }

    private func observeTransactions() {
        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self, !Task.isCancelled else {
                    return
                }
                await handleTransaction(
                    result,
                    expectedTier: nil,
                    showsToast: true
                )
            }
        }
    }

    private func processUnfinishedTransactions() {
        unfinishedTransactionsTask?.cancel()
        unfinishedTransactionsTask = Task { [weak self] in
            for await result in Transaction.unfinished {
                guard let self, !Task.isCancelled else {
                    return
                }
                await handleTransaction(
                    result,
                    expectedTier: nil,
                    showsToast: false
                )
            }
        }
    }

    private func handleTransaction(
        _ result: VerificationResult<Transaction>,
        expectedTier: Tier?,
        showsToast: Bool
    ) async {
        guard case let .verified(transaction) = result else {
            if showsToast {
                showToast("The purchase could not be verified.")
            }
            return
        }
        guard
            let tier = expectedTier
                ?? tiers.first(where: {
                    $0.productIdentifier == transaction.productID
                }),
            tier.productIdentifier == transaction.productID
        else {
            return
        }

        let transactionIdentifier = String(transaction.id)
        guard !processedTransactionIdentifiers.contains(transactionIdentifier) else {
            await transaction.finish()
            return
        }

        processedTransactionIdentifiers.insert(transactionIdentifier)
        currentBalance += tier.coinAmount
        let defaults = UserDefaults.standard
        defaults.set(currentBalance, forKey: Storage.balanceKey)
        defaults.set(
            Array(processedTransactionIdentifiers).sorted(),
            forKey: Storage.processedTransactionsKey
        )
        collectionView.reloadSections(IndexSet(integer: 0))
        await transaction.finish()

        if showsToast {
            showToast("\(tier.coinAmount) coins added.")
        }
    }

    private static let defaultTiers = [
        Tier(productIdentifier: "ymohxnvpkqxutvab", coinAmount: 63700, displayPrice: "$99.99"),
        Tier(productIdentifier: "qnrcuelbtiuflyky", coinAmount: 29400, displayPrice: "$49.99"),
        Tier(productIdentifier: "yadwwvxspgxwlndb", coinAmount: 10800, displayPrice: "$19.99"),
        Tier(productIdentifier: "khtxlcejaxmqcsra", coinAmount: 5150, displayPrice: "$9.99"),
        Tier(productIdentifier: "dxismgcwewhrtezo", coinAmount: 2450, displayPrice: "$4.99"),
        Tier(productIdentifier: "lvbsvhxcgcrvesor", coinAmount: 400, displayPrice: "$0.99")
    ]
}

extension ZixyRechargeController:
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        tiers.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ZixyRechargeTierCell.reuseIdentifier,
            for: indexPath
        ) as? ZixyRechargeTierCell else {
            return UICollectionViewCell()
        }
        let tier = tiers[indexPath.item]
        let displayPrice = tier.productIdentifier
            .flatMap { productsByIdentifier[$0]?.displayPrice }
            ?? tier.displayPrice
        cell.configure(
            coinAmount: tier.coinAmount,
            displayPrice: displayPrice
        )
        cell.onPurchase = { [weak self, weak cell] in
            guard
                let self,
                let cell,
                let currentIndexPath = collectionView.indexPath(for: cell)
            else {
                return
            }
            selectTier(at: currentIndexPath)
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard
            kind == UICollectionView.elementKindSectionHeader,
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: ZixyRechargeHeaderView.reuseIdentifier,
                for: indexPath
            ) as? ZixyRechargeHeaderView
        else {
            return UICollectionReusableView()
        }
        header.configure(balance: currentBalance)
        return header
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(
            width: collectionView.bounds.width - (Layout.horizontalInset * 2),
            height: Layout.rowHeight
        )
    }
}

private final class ZixyRechargeLoadingView: UIView {

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
            panel.widthAnchor.constraint(equalToConstant: 156),
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

private final class ZixyRechargeHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "ZixyRechargeHeaderView"

    private let bannerImageView = UIImageView(
        image: ZixyImageLibrary.rechargeBalanceBanner
    )
    private let currentBalanceLabel = UILabel()
    private let balanceLabel = UILabel()
    private let sectionTitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(balance: Int) {
        let number = NumberFormatter.localizedString(
            from: NSNumber(value: balance),
            number: .decimal
        )
        let text = NSMutableAttributedString(
            string: number,
            attributes: [
                .font: ZixyFontBook.bold(size: 36, relativeTo: .largeTitle),
                .foregroundColor: UIColor(
                    red: 236 / 255,
                    green: 151 / 255,
                    blue: 21 / 255,
                    alpha: 1
                )
            ]
        )
        text.append(
            NSAttributedString(
                string: " coins",
                attributes: [
                    .font: ZixyFontBook.bold(size: 16, relativeTo: .headline),
                    .foregroundColor: UIColor(
                        red: 222 / 255,
                        green: 134 / 255,
                        blue: 15 / 255,
                        alpha: 1
                    )
                ]
            )
        )
        balanceLabel.attributedText = text
        accessibilityLabel = "Current balance \(number) coins"
    }

    private func configureLayout() {
        bannerImageView.translatesAutoresizingMaskIntoConstraints = false
        bannerImageView.contentMode = .scaleToFill
        bannerImageView.clipsToBounds = true

        currentBalanceLabel.translatesAutoresizingMaskIntoConstraints = false
        currentBalanceLabel.text = "Current balance"
        currentBalanceLabel.font = ZixyFontBook.bold(size: 16, relativeTo: .headline)
        currentBalanceLabel.textColor = UIColor.black.withAlphaComponent(0.72)

        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        balanceLabel.adjustsFontSizeToFitWidth = true
        balanceLabel.minimumScaleFactor = 0.8

        sectionTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        sectionTitleLabel.text = "Top-up tiers"
        sectionTitleLabel.font = ZixyFontBook.bold(size: 23, relativeTo: .title2)
        sectionTitleLabel.textColor = UIColor.black.withAlphaComponent(0.75)

        addSubview(bannerImageView)
        addSubview(currentBalanceLabel)
        addSubview(balanceLabel)
        addSubview(sectionTitleLabel)
        NSLayoutConstraint.activate([
            bannerImageView.topAnchor.constraint(equalTo: topAnchor),
            bannerImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 33),
            bannerImageView.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -31
            ),
            bannerImageView.heightAnchor.constraint(equalToConstant: 148),

            currentBalanceLabel.leadingAnchor.constraint(
                equalTo: bannerImageView.leadingAnchor,
                constant: 16
            ),
            currentBalanceLabel.topAnchor.constraint(
                equalTo: bannerImageView.topAnchor,
                constant: 39
            ),

            balanceLabel.leadingAnchor.constraint(
                equalTo: currentBalanceLabel.leadingAnchor
            ),
            balanceLabel.topAnchor.constraint(
                equalTo: currentBalanceLabel.bottomAnchor,
                constant: 1
            ),
            balanceLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: bannerImageView.trailingAnchor,
                constant: -104
            ),

            sectionTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            sectionTitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3)
        ])
    }
}

private final class ZixyRechargeTierCell: UICollectionViewCell {

    static let reuseIdentifier = "ZixyRechargeTierCell"

    var onPurchase: (() -> Void)?

    private let coinImageView = UIImageView(image: ZixyImageLibrary.rechargeCoinStack)
    private let amountLabel = UILabel()
    private let priceButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onPurchase = nil
    }

    func configure(coinAmount: Int, displayPrice: String) {
        amountLabel.text = NumberFormatter.localizedString(
            from: NSNumber(value: coinAmount),
            number: .decimal
        )
        priceButton.setTitle("\(displayPrice)   ➜", for: .normal)
        priceButton.accessibilityLabel = "Buy \(coinAmount) coins for \(displayPrice)"
        accessibilityLabel = "\(coinAmount) coins, \(displayPrice)"
    }

    private func configureLayout() {
        contentView.backgroundColor = UIColor(
            red: 20 / 255,
            green: 20 / 255,
            blue: 58 / 255,
            alpha: 1
        )
        contentView.layer.cornerRadius = 14
        contentView.layer.borderWidth = 2
        contentView.layer.borderColor = UIColor(
            red: 142 / 255,
            green: 144 / 255,
            blue: 208 / 255,
            alpha: 1
        ).cgColor

        coinImageView.translatesAutoresizingMaskIntoConstraints = false
        coinImageView.contentMode = .scaleAspectFit

        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.font = ZixyFontBook.bold(size: 28, relativeTo: .title1)
        amountLabel.textColor = UIColor(
            red: 1,
            green: 190 / 255,
            blue: 145 / 255,
            alpha: 1
        )

        priceButton.translatesAutoresizingMaskIntoConstraints = false
        priceButton.backgroundColor = UIColor(
            red: 1,
            green: 190 / 255,
            blue: 145 / 255,
            alpha: 1
        )
        priceButton.setTitleColor(.black, for: .normal)
        priceButton.titleLabel?.font = ZixyFontBook.bold(
            size: 14,
            relativeTo: .subheadline
        )
        priceButton.layer.cornerRadius = 11
        priceButton.addTarget(
            self,
            action: #selector(purchaseTapped),
            for: .touchUpInside
        )

        contentView.addSubview(coinImageView)
        contentView.addSubview(amountLabel)
        contentView.addSubview(priceButton)
        NSLayoutConstraint.activate([
            coinImageView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 12
            ),
            coinImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            coinImageView.widthAnchor.constraint(equalToConstant: 46),
            coinImageView.heightAnchor.constraint(equalToConstant: 46),

            amountLabel.leadingAnchor.constraint(
                equalTo: coinImageView.trailingAnchor,
                constant: 8
            ),
            amountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            amountLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: priceButton.leadingAnchor,
                constant: -8
            ),

            priceButton.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -9
            ),
            priceButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            priceButton.widthAnchor.constraint(equalToConstant: 99),
            priceButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    @objc private func purchaseTapped() {
        onPurchase?()
    }
}
