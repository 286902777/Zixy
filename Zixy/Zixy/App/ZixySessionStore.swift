import Foundation

enum ZixySessionStore {

    private static let authenticatedDefaultsKey = "zixy_user_authenticated"

    static var isAuthenticated: Bool {
        UserDefaults.standard.bool(forKey: authenticatedDefaultsKey)
    }

    static func markAuthenticated() {
        UserDefaults.standard.set(true, forKey: authenticatedDefaultsKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: authenticatedDefaultsKey)
    }
}
