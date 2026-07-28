import UIKit
import WebKit

final class ZixyWebController: ZixyScreenController,
    WKNavigationDelegate {

    enum H5Page {
        case userAgreement
        case privacyPolicy
        case communityGuidelines
        case aboutZixy

        fileprivate var title: String {
            switch self {
            case .userAgreement:
                return "User Agreement"
            case .privacyPolicy:
                return "Privacy Policy"
            case .communityGuidelines:
                return "Community Guidelines"
            case .aboutZixy:
                return "About Zixy"
            }
        }

        fileprivate var urlString: String {
            switch self {
            case .userAgreement:
                return "https://sites.google.com/view/zixy/users"
            case .privacyPolicy:
                return "https://sites.google.com/view/zixy/privacy"
            case .communityGuidelines:
                return ""
            case .aboutZixy:
                return ""
            }
        }
    }

    private let page: H5Page

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .systemBlue
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Content will be available soon."
        label.font = ZixyFontBook.bold(size: 16, relativeTo: .body)
        label.textColor = .systemGray
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    init(page: H5Page) {
        self.page = page
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation(title: page.title)
        configureWebView()
        loadPage()
    }

    private func configureWebView() {
        contentView.addSubview(webView)
        contentView.addSubview(emptyLabel)
        contentView.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: contentView.topAnchor),
            webView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(
                equalTo: contentView.centerXAnchor
            ),
            emptyLabel.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor,
                constant: -30
            ),
            emptyLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: contentView.leadingAnchor,
                constant: 24
            ),
            emptyLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: contentView.trailingAnchor,
                constant: -24
            ),

            loadingIndicator.centerXAnchor.constraint(
                equalTo: contentView.centerXAnchor
            ),
            loadingIndicator.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor,
                constant: -30
            )
        ])
    }

    private func loadPage() {
        let urlText = page.urlString.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard
            !urlText.isEmpty,
            let url = URL(string: urlText),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        else {
            webView.isHidden = true
            emptyLabel.isHidden = false
            return
        }

        emptyLabel.isHidden = true
        webView.isHidden = false
        loadingIndicator.startAnimating()
        webView.load(URLRequest(url: url))
    }

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation?
    ) {
        loadingIndicator.stopAnimating()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation?,
        withError error: Error
    ) {
        handleLoadFailure()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation?,
        withError error: Error
    ) {
        handleLoadFailure()
    }

    private func handleLoadFailure() {
        loadingIndicator.stopAnimating()
        showToast("Unable to load this page.")
    }
}
