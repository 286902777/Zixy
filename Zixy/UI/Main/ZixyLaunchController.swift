import Network
import UIKit

@MainActor
final class ZixyLaunchController: UIViewController {

    private let minimumDisplayDuration: TimeInterval
    private let onRouteResolved: ((Bool) -> Void)?
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(
        label: "app.zixy.network-monitor"
    )

    private var delayTask: Task<Void, Never>?
    private var routeRequestTask: Task<Void, Never>?
    private var networkPermissionTask: URLSessionDataTask?
    private var hasTriggeredNetworkPermission = false
    private var hasStartedNetworkMonitoring = false
    private var hasScheduledLaunchDelay = false
    private var hasCompletedLaunchDelay = false
    private var hasNetworkConnection = false
    private var hasStartedRouteRequest = false
    private var hasCompletedLaunch = false

    private let backgroundImageView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "zixy_launch_background"))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.isAccessibilityElement = false
        return view
    }()

    init(
        minimumDisplayDuration: TimeInterval = 1.5,
        onRouteResolved: ((Bool) -> Void)? = nil
    ) {
        self.minimumDisplayDuration = max(0, minimumDisplayDuration)
        self.onRouteResolved = onRouteResolved
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        minimumDisplayDuration = 1.5
        onRouteResolved = nil
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(backgroundImageView)
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        requestHostInfo()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startNetworkMonitoring()
        startMinimumDisplayDelay()
    }

    private func requestHostInfo() {
        guard !hasTriggeredNetworkPermission else {
            return
        }
        hasTriggeredNetworkPermission = true

        var components = URLComponents(
            string: "https://opi.832cdqtw.link/"
        )
        components?.queryItems = [
            URLQueryItem(name: "network_probe", value: UUID().uuidString)
        ]
        guard let url = components?.url else {
            return
        }

        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 10
        )
        request.httpMethod = "GET"

        networkPermissionTask = URLSession.shared.dataTask(
            with: request
        ) { [weak self] _, _, _ in
            Task { @MainActor [weak self] in
                self?.networkPermissionTask = nil
            }
        }
        networkPermissionTask?.resume()
    }

    private func startNetworkMonitoring() {
        guard !hasStartedNetworkMonitoring else {
            return
        }
        hasStartedNetworkMonitoring = true

        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else {
                return
            }
            Task { @MainActor [weak self] in
                guard let self, !hasCompletedLaunch else {
                    return
                }
                hasNetworkConnection = true
                startRouteRequestIfReady()
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    private func startMinimumDisplayDelay() {
        guard !hasScheduledLaunchDelay else {
            return
        }
        hasScheduledLaunchDelay = true

        let nanoseconds = UInt64(
            min(minimumDisplayDuration, 60) * 1_000_000_000
        )
        delayTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard let self, !Task.isCancelled else {
                return
            }
            hasCompletedLaunchDelay = true
            startRouteRequestIfReady()
        }
    }

    private func startRouteRequestIfReady() {
        guard
            hasCompletedLaunchDelay,
            hasNetworkConnection,
            !hasStartedRouteRequest,
            !hasCompletedLaunch,
            viewIfLoaded?.window != nil
        else {
            return
        }
        hasStartedRouteRequest = true
        networkMonitor.cancel()
        networkPermissionTask?.cancel()
        networkPermissionTask = nil
        delayTask?.cancel()
        delayTask = nil

        routeRequestTask = Task { [weak self] in
            guard let self else {
                return
            }
            let succeeded = await ZixyRootTool.shared
                .refreshRouteConfiguration()
            guard !Task.isCancelled else {
                return
            }
            hasCompletedLaunch = true
            routeRequestTask = nil
            onRouteResolved?(succeeded)
        }
    }
}
