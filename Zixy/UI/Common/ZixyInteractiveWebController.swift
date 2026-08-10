@preconcurrency import StoreKit
import UIKit
import WebKit

@MainActor
final class ZixyInteractiveWebController: UIViewController {

    private struct CommerceIntent: Codable, Equatable {
        let productIdentifier: String
        let orderReference: String
    }

    var didRequestDismissal: (() -> Void)?
    var didResolveFirstNavigation: ((Bool) -> Void)?

    private enum PortalPreference {
        static let destination = "zixy.remote_route.host_url"
        static let openedOnce = "zixy.remote_portal.has_opened"
        static let pendingCommerceIntent =
            "zixy.remote_portal.pending_commerce_intent"
    }

    private enum SignalChannel {
        static let commerce = "rechargePay"
        static let dismissal = "Close"
        static let externalLink = "openBrowser"
        static let registered = [externalLink, commerce, dismissal]
    }

    private let messageHub = WKUserContentController()
    private var destination: URL?
    private var navigationBeganAt: Date?
    private var didPublishFirstOutcome = false
    private var privacyIsActive = false
    private var hasRequestedPushRegistration = false
    private var pendingCommerceIntent: CommerceIntent?
    private var productsRequest: SKProductsRequest?
    private var paymentReportTask: Task<Void, Never>?
    private var purchaseCompletionTask: Task<Void, Never>?
    private var purchaseStartedAt: Date?
    private var reportingTransactionIdentifiers = Set<String>()
    private var isPurchaseInProgress = false

    private let purchaseLoadingOverlay = ZixyLoadingOverlay()
    private let secureContentView: ZixySecureContentView = {
        let secureView = ZixySecureContentView()
        secureView.translatesAutoresizingMaskIntoConstraints = false
        return secureView
    }()

    private lazy var browserBackGesture: UIScreenEdgePanGestureRecognizer = {
        let gesture = UIScreenEdgePanGestureRecognizer(
            target: self,
            action: #selector(handleBrowserBackGesture(_:))
        )
        gesture.edges = .left
        gesture.delegate = self
        return gesture
    }()

    private lazy var browser: WKWebView = assembleBrowser()

    init(destination: URL? = nil) {
        self.destination = destination
        super.init(nibName: nil, bundle: nil)
        registerMessageChannels()
    }

    convenience init(address: String?) {
        let trimmedAddress = address?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        self.init(destination: trimmedAddress.flatMap(URL.init(string:)))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerMessageChannels()
    }

    private func relayExternalOpenResult(_ opened: Bool, target: URL) {
        let payload = [
            "state": opened ? "success" : "failed",
            "url": target.absoluteString
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }

        browser.evaluateJavaScript(
            "window.dispatchEvent(new CustomEvent('nativeOpenState', { detail: \(json) }));"
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        mountInterface()
        pendingCommerceIntent = Self.loadPendingCommerceIntent()
        SKPaymentQueue.default().add(self)
        navigateToDestination()
    }

    private func assembleBrowser() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = messageHub
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        return webView
    }

    private func publishFirstOutcome(_ succeeded: Bool) {
        guard !didPublishFirstOutcome else {
            return
        }
        didPublishFirstOutcome = true
        didResolveFirstNavigation?(succeeded)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ZixyRuntimeContext.shared.updateLoginState(true)
        enablePrivacyIfNeeded()
        requestPushRegistrationIfNeeded()
    }

    private func requestPushRegistrationIfNeeded() {
        guard !hasRequestedPushRegistration else {
            return
        }
        hasRequestedPushRegistration = true
        ZixyPushRegistration.shared.start()
    }

    private func resolveEndpoint() -> URL? {
        let storedDestination = UserDefaults.standard
            .string(forKey: PortalPreference.destination)
            .flatMap(URL.init(string:))
        guard
            let endpoint = destination ?? storedDestination,
            let scheme = endpoint.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        else {
            return nil
        }
        return endpoint
    }

    private func consumeCommercePayload(_ payload: Any) {
        guard
            let values = payload as? [String: Any],
            let productIdentifier = values["batchNo"] as? String,
            let orderReference = values["orderCode"] as? String,
            !productIdentifier.isEmpty,
            !orderReference.isEmpty
        else {
            showToast("The selected purchase is unavailable.")
            return
        }

        let intent = CommerceIntent(
            productIdentifier: productIdentifier,
            orderReference: orderReference
        )
        if let pendingCommerceIntent {
            guard pendingCommerceIntent == intent else {
                showToast("Another purchase is still being processed.")
                return
            }

            if let transaction = SKPaymentQueue.default().transactions.first(
                where: { $0.payment.productIdentifier == productIdentifier }
            ) {
                handle(transaction)
                return
            }
        }

        guard !isPurchaseInProgress else {
            return
        }
        guard SKPaymentQueue.canMakePayments() else {
            showToast("Purchases are not allowed on this device.")
            return
        }

        pendingCommerceIntent = intent
        persistPendingCommerceIntent(intent)
        beginPurchaseLoading(message: "Loading product...")

        let request = SKProductsRequest(
            productIdentifiers: [intent.productIdentifier]
        )
        productsRequest = request
        request.delegate = self
        request.start()
    }

    private func mountInterface() {
        view.backgroundColor = UIColor(
            red: 15 / 255,
            green: 14 / 255,
            blue: 44 / 255,
            alpha: 1
        )
        view.addGestureRecognizer(browserBackGesture)
        view.addSubview(secureContentView)
        [browser, purchaseLoadingOverlay]
            .forEach(secureContentView.contentView.addSubview)

        NSLayoutConstraint.activate([
            secureContentView.topAnchor.constraint(equalTo: view.topAnchor),
            secureContentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            secureContentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            secureContentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            browser.topAnchor.constraint(
                equalTo: secureContentView.contentView.topAnchor
            ),
            browser.leadingAnchor.constraint(
                equalTo: secureContentView.contentView.leadingAnchor
            ),
            browser.trailingAnchor.constraint(
                equalTo: secureContentView.contentView.trailingAnchor
            ),
            browser.bottomAnchor.constraint(
                equalTo: secureContentView.contentView.bottomAnchor
            ),
            purchaseLoadingOverlay.topAnchor.constraint(
                equalTo: secureContentView.contentView.topAnchor
            ),
            purchaseLoadingOverlay.leadingAnchor.constraint(
                equalTo: secureContentView.contentView.leadingAnchor
            ),
            purchaseLoadingOverlay.trailingAnchor.constraint(
                equalTo: secureContentView.contentView.trailingAnchor
            ),
            purchaseLoadingOverlay.bottomAnchor.constraint(
                equalTo: secureContentView.contentView.bottomAnchor
            )
        ])
    }

    private func openOutsideApplication(_ target: URL) {
        guard acceptsExternalTarget(target) else {
            relayExternalOpenResult(false, target: target)
            return
        }

        UIApplication.shared.open(target, options: [:]) { [weak self] opened in
            Task { @MainActor in
                self?.relayExternalOpenResult(opened, target: target)
            }
        }
    }

    func replaceDestination(with target: URL? = nil) {
        if let target {
            destination = target
        }
        navigateToDestination()
    }

    private func displayNavigationFailure() {
        publishFirstOutcome(false)
        if viewIfLoaded?.window != nil {
            showToast("Unable to load this page.")
        }
    }

    private func registerMessageChannels() {
        let forwarder = ZixyWebSignalForwarder(recipient: self)
        SignalChannel.registered.forEach {
            messageHub.add(forwarder, name: $0)
        }
    }

    private func enablePrivacyIfNeeded() {
        guard !privacyIsActive, let window = view.window else {
            return
        }
        privacyIsActive = true
        ZixyCapturePrivacyGuard.shared.startMonitoring(in: window)
    }

    private func navigateToDestination() {
        guard let endpoint = resolveEndpoint() else {
            displayNavigationFailure()
            return
        }
        browser.load(URLRequest(url: endpoint))
    }

    private func acceptsExternalTarget(_ target: URL) -> Bool {
        guard let scheme = target.scheme?.lowercased() else {
            return false
        }
        let allowedSchemes: Set<String> = [
            "http", "https", "mailto", "tel", "sms",
            "itms-apps", "upi", "phonepe",
            "paytm", "paytmmp", "gpay"
        ]
        return allowedSchemes.contains(scheme)
    }

    private func disablePrivacy() {
        guard privacyIsActive else {
            return
        }
        privacyIsActive = false
        ZixyCapturePrivacyGuard.shared.stopMonitoring()
    }

    private func beginPurchaseLoading(message: String) {
        purchaseCompletionTask?.cancel()
        purchaseCompletionTask = nil
        isPurchaseInProgress = true
        purchaseStartedAt = purchaseStartedAt ?? Date()
        purchaseLoadingOverlay.show(message: message)
    }

    private func waitForMinimumPurchaseLoadingDuration() async {
        guard let purchaseStartedAt else {
            return
        }
        let remainingDuration = max(
            0,
            1 - Date().timeIntervalSince(purchaseStartedAt)
        )
        guard remainingDuration > 0 else {
            return
        }
        try? await Task.sleep(
            nanoseconds: UInt64(remainingDuration * 1_000_000_000)
        )
    }

    private func finishPurchaseUI(
        clearingIntent: Bool,
        message: String?
    ) {
        purchaseCompletionTask?.cancel()
        purchaseCompletionTask = Task { [weak self] in
            guard let self else {
                return
            }
            await waitForMinimumPurchaseLoadingDuration()
            guard !Task.isCancelled else {
                return
            }

            if clearingIntent {
                clearPendingCommerceIntent()
            }
            isPurchaseInProgress = false
            purchaseStartedAt = nil
            purchaseLoadingOverlay.hide()
            if let message {
                showToast(message)
            }
            purchaseCompletionTask = nil
        }
    }

    private func handle(_ transaction: SKPaymentTransaction) {
        switch transaction.transactionState {
        case .purchasing:
            guard transactionMatchesPendingIntent(transaction) else {
                return
            }
            beginPurchaseLoading(message: "Processing purchase...")
        case .deferred:
            guard transactionMatchesPendingIntent(transaction) else {
                return
            }
            finishPurchaseUI(
                clearingIntent: false,
                message: "Purchase is pending approval."
            )
        case .purchased, .restored:
            processCompletedTransaction(transaction)
        case .failed:
            processFailedTransaction(transaction)
        @unknown default:
            guard transactionMatchesPendingIntent(transaction) else {
                return
            }
            finishPurchaseUI(
                clearingIntent: false,
                message: "Unable to complete the purchase."
            )
        }
    }

    private func transactionMatchesPendingIntent(
        _ transaction: SKPaymentTransaction
    ) -> Bool {
        guard let pendingCommerceIntent else {
            return false
        }
        return transaction.payment.productIdentifier
            == pendingCommerceIntent.productIdentifier
    }

    private func processCompletedTransaction(
        _ transaction: SKPaymentTransaction
    ) {
        guard
            let intent = pendingCommerceIntent,
            transaction.payment.productIdentifier == intent.productIdentifier
        else {
            return
        }
        guard
            let transactionNumber = transaction.transactionIdentifier,
            !transactionNumber.isEmpty
        else {
            beginPurchaseLoading(message: "Verifying purchase...")
            finishPurchaseUI(
                clearingIntent: false,
                message: "Unable to identify the purchase transaction."
            )
            return
        }
        guard !reportingTransactionIdentifiers.contains(transactionNumber) else {
            return
        }
        guard
            let receiptURL = Bundle.main.appStoreReceiptURL,
            let receiptData = try? Data(contentsOf: receiptURL),
            !receiptData.isEmpty
        else {
            beginPurchaseLoading(message: "Verifying purchase...")
            finishPurchaseUI(
                clearingIntent: false,
                message: "Unable to verify the purchase receipt."
            )
            return
        }

        reportingTransactionIdentifiers.insert(transactionNumber)
        beginPurchaseLoading(message: "Verifying purchase...")
        let receipt = receiptData.base64EncodedString()
        paymentReportTask?.cancel()
        paymentReportTask = Task { [weak self, weak transaction] in
            guard let self, let transaction else {
                return
            }
            let reported = await ZixyRootTool.shared.reportPayment(
                transactionNumber: transactionNumber,
                orderCode: intent.orderReference,
                receipt: receipt
            )
            await waitForMinimumPurchaseLoadingDuration()
            guard !Task.isCancelled else {
                return
            }

            reportingTransactionIdentifiers.remove(transactionNumber)
            if reported {
                SKPaymentQueue.default().finishTransaction(transaction)
                clearPendingCommerceIntent()
                showToast("Purchase completed.")
            } else {
                showToast("Unable to verify the purchase.")
            }
            isPurchaseInProgress = false
            purchaseStartedAt = nil
            purchaseLoadingOverlay.hide()
            paymentReportTask = nil
        }
    }

    private func processFailedTransaction(
        _ transaction: SKPaymentTransaction
    ) {
        let matchesPendingIntent = transactionMatchesPendingIntent(transaction)
        SKPaymentQueue.default().finishTransaction(transaction)
        guard matchesPendingIntent else {
            return
        }

        let wasCancelled = (transaction.error as? SKError)?.code
            == .paymentCancelled
        finishPurchaseUI(
            clearingIntent: true,
            message: wasCancelled ? nil : "Unable to complete the purchase."
        )
    }

    private func persistPendingCommerceIntent(_ intent: CommerceIntent) {
        guard let data = try? JSONEncoder().encode(intent) else {
            return
        }
        UserDefaults.standard.set(
            data,
            forKey: PortalPreference.pendingCommerceIntent
        )
    }

    private func clearPendingCommerceIntent() {
        pendingCommerceIntent = nil
        UserDefaults.standard.removeObject(
            forKey: PortalPreference.pendingCommerceIntent
        )
    }

    private static func loadPendingCommerceIntent() -> CommerceIntent? {
        guard let data = UserDefaults.standard.data(
            forKey: PortalPreference.pendingCommerceIntent
        ) else {
            return nil
        }
        return try? JSONDecoder().decode(CommerceIntent.self, from: data)
    }

    private func receiveProducts(
        for request: SKProductsRequest,
        response: SKProductsResponse
    ) {
        guard productsRequest === request else {
            return
        }
        productsRequest = nil

        guard
            let intent = pendingCommerceIntent,
            let product = response.products.first(where: {
                $0.productIdentifier == intent.productIdentifier
            })
        else {
            finishPurchaseUI(
                clearingIntent: true,
                message: "This purchase is currently unavailable."
            )
            return
        }

        purchaseLoadingOverlay.show(message: "Processing purchase...")
        SKPaymentQueue.default().add(SKPayment(product: product))
    }

    private func receiveProductRequestFailure(_ request: SKRequest) {
        guard productsRequest === request else {
            return
        }
        productsRequest = nil
        finishPurchaseUI(
            clearingIntent: true,
            message: "Unable to load this purchase."
        )
    }

    private func receiveTransactions(
        _ transactions: [SKPaymentTransaction]
    ) {
        transactions.forEach(handle)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            disablePrivacy()
        }
    }

    private func exitExperience() {
        guard !isPurchaseInProgress else {
            showToast("Please wait for the purchase to finish.")
            return
        }
        ZixyRuntimeContext.shared.updateLoginState(false)
        disablePrivacy()
        didRequestDismissal?()

        if let navigationController,
           navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func handleBrowserBackGesture(
        _ gesture: UIScreenEdgePanGestureRecognizer
    ) {
        guard gesture.state == .recognized,
              !isPurchaseInProgress,
              browser.canGoBack else {
            return
        }
        browser.goBack()
    }

    deinit {
        MainActor.assumeIsolated {
            productsRequest?.cancel()
            paymentReportTask?.cancel()
            purchaseCompletionTask?.cancel()
            SKPaymentQueue.default().remove(self)
            SignalChannel.registered.forEach {
                messageHub.removeScriptMessageHandler(forName: $0)
            }
        }
    }
}

extension ZixyInteractiveWebController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard gestureRecognizer === browserBackGesture else {
            return true
        }
        return !isPurchaseInProgress && browser.canGoBack
    }
}

extension ZixyInteractiveWebController: SKProductsRequestDelegate {

    nonisolated func productsRequest(
        _ request: SKProductsRequest,
        didReceive response: SKProductsResponse
    ) {
        let callback = ZixyUncheckedTransfer(
            value: (request: request, response: response)
        )
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.receiveProducts(
                    for: callback.value.request,
                    response: callback.value.response
                )
            }
        }
    }

    nonisolated func request(
        _ request: SKRequest,
        didFailWithError error: Error
    ) {
        let callback = ZixyUncheckedTransfer(value: request)
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.receiveProductRequestFailure(callback.value)
            }
        }
    }
}

extension ZixyInteractiveWebController: SKPaymentTransactionObserver {

    nonisolated func paymentQueue(
        _ queue: SKPaymentQueue,
        updatedTransactions transactions: [SKPaymentTransaction]
    ) {
        let callback = ZixyUncheckedTransfer(value: transactions)
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.receiveTransactions(callback.value)
            }
        }
    }
}

extension ZixyInteractiveWebController: WKScriptMessageHandler {

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case SignalChannel.externalLink:
            guard
                let values = message.body as? [String: Any],
                let address = values["url"] as? String,
                let target = URL(string: address)
            else {
                return
            }
            openOutsideApplication(target)
        case SignalChannel.dismissal:
            exitExperience()
        case SignalChannel.commerce:
            consumeCommercePayload(message.body)
        default:
            return
        }
    }
}

extension ZixyInteractiveWebController: WKUIDelegate {

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard
            navigationAction.targetFrame == nil,
            let target = navigationAction.request.url
        else {
            return nil
        }

        if ["http", "https"].contains(target.scheme?.lowercased() ?? "") {
            webView.load(URLRequest(url: target))
        } else {
            openOutsideApplication(target)
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(.grant)
    }
}

extension ZixyInteractiveWebController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard
            let target = navigationAction.request.url,
            let scheme = target.scheme?.lowercased()
        else {
            decisionHandler(.cancel)
            return
        }

        if ["http", "https", "file", "about"].contains(scheme) {
            decisionHandler(.allow)
        } else {
            openOutsideApplication(target)
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        publishFirstOutcome(true)
        UserDefaults.standard.set(true, forKey: PortalPreference.openedOnce)
    }

    func webView(
        _ webView: WKWebView,
        didStartProvisionalNavigation navigation: WKNavigation?
    ) {
        navigationBeganAt = Date()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation?,
        withError error: Error
    ) {
        displayNavigationFailure()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation?,
        withError error: Error
    ) {
        displayNavigationFailure()
    }
}

private final class ZixyWebSignalForwarder: NSObject,
    WKScriptMessageHandler {

    weak var recipient: WKScriptMessageHandler?

    init(recipient: WKScriptMessageHandler) {
        self.recipient = recipient
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        recipient?.userContentController(userContentController, didReceive: message)
    }
}

private struct ZixyUncheckedTransfer<Value>: @unchecked Sendable {
    let value: Value
}
