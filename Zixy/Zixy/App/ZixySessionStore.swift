import Foundation

enum ZixySessionStore {

    private static let authenticatedDefaultsKey = "zixy_user_authenticated"
    private static let guestDefaultsKey = "zixy_guest_session"

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

    static func markAuthenticated() {
        UserDefaults.standard.set(true, forKey: authenticatedDefaultsKey)
        UserDefaults.standard.set(false, forKey: guestDefaultsKey)
    }

    static func markGuest() {
        UserDefaults.standard.set(false, forKey: authenticatedDefaultsKey)
        UserDefaults.standard.set(true, forKey: guestDefaultsKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: authenticatedDefaultsKey)
        UserDefaults.standard.removeObject(forKey: guestDefaultsKey)
    }
}
