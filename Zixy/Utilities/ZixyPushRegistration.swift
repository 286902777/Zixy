import UIKit
import UserNotifications

@MainActor
final class ZixyPushRegistration {

    static let shared = ZixyPushRegistration()

    private var registrationTask: Task<Void, Never>?

    private init() {}

    func start() {
        guard registrationTask == nil else {
            return
        }

        registrationTask = Task { [weak self] in
            await self?.requestRegistration()
            self?.registrationTask = nil
        }
    }

    private func requestRegistration() async {
        let notificationCenter = UNUserNotificationCenter.current()
        let settings = await notificationCenter.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )) ?? false
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }

        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()

        case .denied:
            return

        @unknown default:
            return
        }
    }
}
