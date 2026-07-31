import Foundation

enum ZixySessionStore {

    private static let authenticatedDefaultsKey = "zixy_user_authenticated"
    private static let guestDefaultsKey = "zixy_guest_session"
    private static let userIdentifierDefaultsKey = "zixy_current_user_identifier"

    static var isAuthenticated: Bool {
        UserDefaults.standard.bool(forKey: authenticatedDefaultsKey)
    }

    static var isGuest: Bool {
        UserDefaults.standard.bool(forKey: guestDefaultsKey)
    }

    static var hasActiveSession: Bool {
        isAuthenticated || isGuest
    }

    static var allowsSocialInteraction: Bool {
        isAuthenticated && !isGuest
    }

    static var currentUserIdentifier: String {
        UserDefaults.standard.string(forKey: userIdentifierDefaultsKey)
            ?? (isGuest ? "guest" : "authenticated")
    }

    static func setCurrentUserIdentifier(_ identifier: String) {
        let normalizedIdentifier = identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalizedIdentifier.isEmpty else {
            return
        }
        UserDefaults.standard.set(
            normalizedIdentifier,
            forKey: userIdentifierDefaultsKey
        )
    }

    static func migrateUserIdentifier(
        from oldIdentifier: String,
        to newIdentifier: String
    ) {
        let oldValue = oldIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let newValue = newIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !oldValue.isEmpty, !newValue.isEmpty, oldValue != newValue else {
            return
        }

        let defaults = UserDefaults.standard
        if defaults.string(forKey: userIdentifierDefaultsKey) == oldValue {
            defaults.set(newValue, forKey: userIdentifierDefaultsKey)
        }

        let oldEncoded = Data(oldValue.utf8).base64EncodedString()
        let newEncoded = Data(newValue.utf8).base64EncodedString()
        let keyPairs = [
            (
                "zixy_ai_chat_history.\(oldEncoded)",
                "zixy_ai_chat_history.\(newEncoded)"
            ),
            (
                "zixy_ai_chat_daily_usage.\(oldEncoded).day",
                "zixy_ai_chat_daily_usage.\(newEncoded).day"
            ),
            (
                "zixy_ai_chat_daily_usage.\(oldEncoded).count",
                "zixy_ai_chat_daily_usage.\(newEncoded).count"
            )
        ]
        for (oldKey, newKey) in keyPairs {
            if defaults.object(forKey: newKey) == nil,
               let value = defaults.object(forKey: oldKey) {
                defaults.set(value, forKey: newKey)
            }
            defaults.removeObject(forKey: oldKey)
        }
    }

    @MainActor
    static func homeRooms(category: String) -> [ZixyRoomRecord] {
        ZixyDataStore.shared.rooms(category: category)
    }

    @MainActor
    static func roomMessages(roomID: String) -> [ZixyRoomMessageRecord] {
        ZixyDataStore.shared.roomMessages(
            roomID: roomID,
            accountEmail: currentUserIdentifier
        )
    }

    static func markAuthenticated() {
        UserDefaults.standard.set(true, forKey: authenticatedDefaultsKey)
        UserDefaults.standard.set(false, forKey: guestDefaultsKey)
    }

    static func markGuest() {
        UserDefaults.standard.set(false, forKey: authenticatedDefaultsKey)
        UserDefaults.standard.set(true, forKey: guestDefaultsKey)
        UserDefaults.standard.set("guest", forKey: userIdentifierDefaultsKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: authenticatedDefaultsKey)
        UserDefaults.standard.removeObject(forKey: guestDefaultsKey)
        UserDefaults.standard.removeObject(forKey: userIdentifierDefaultsKey)
    }
}
