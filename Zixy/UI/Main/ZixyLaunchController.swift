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
    private var hasStarted = false
    private var hasFinishedDelay = false
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
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startIfNeeded()
    }

    private func startIfNeeded() {
        guard !hasStarted else {
            return
        }
        hasStarted = true
        startNetworkMonitoring()
        startMinimumDisplayDelay()
    }

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self, !hasCompletedLaunch else {
                    return
                }
                hasNetworkConnection = isConnected
                startRouteRequestIfReady()
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    private func startMinimumDisplayDelay() {
        let nanoseconds = UInt64(
            min(minimumDisplayDuration, 60) * 1_000_000_000
        )
        delayTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard let self, !Task.isCancelled else {
                return
            }
            hasFinishedDelay = true
            if networkMonitor.currentPath.status == .satisfied {
                hasNetworkConnection = true
            }
            startRouteRequestIfReady()
        }
    }

    private func startRouteRequestIfReady() {
        guard
            hasFinishedDelay,
            !hasStartedRouteRequest,
            !hasCompletedLaunch
        else {
            return
        }
        hasStartedRouteRequest = true
        networkMonitor.cancel()
        delayTask?.cancel()
        delayTask = nil

        routeRequestTask = Task { [weak self] in
            guard let self else {
                return
            }
            let succeeded = hasNetworkConnection
                ? await ZixyRootTool.shared.refreshRouteConfiguration()
                : false
            guard !Task.isCancelled else {
                return
            }
            hasCompletedLaunch = true
            routeRequestTask = nil
            onRouteResolved?(succeeded)
        }
    }
}
