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
