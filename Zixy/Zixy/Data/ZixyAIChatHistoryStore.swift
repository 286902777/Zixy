import Foundation

enum ZixyAIChatRole: String, Codable {
    case assistant
    case user
}

struct ZixyAIChatHistoryRecord: Codable {
    let role: ZixyAIChatRole
    let text: String
    let createdAt: Date
}

enum ZixyAIChatHistoryStore {

    private static let defaultsPrefix = "zixy_ai_chat_history"

    static func records() -> [ZixyAIChatHistoryRecord] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let records = try? JSONDecoder().decode(
                [ZixyAIChatHistoryRecord].self,
                from: data
            )
        else {
            return []
        }
        return records
    }

    static func append(role: ZixyAIChatRole, text: String) {
        var storedRecords = records()
        storedRecords.append(
            ZixyAIChatHistoryRecord(
                role: role,
                text: text,
                createdAt: Date()
            )
        )
        save(storedRecords)
    }

    static func replace(with records: [ZixyAIChatHistoryRecord]) {
        save(records)
    }

    static var latestMessage: String? {
        records().last?.text
    }

    private static var storageKey: String {
        let normalizedIdentifier = ZixySessionStore.currentUserIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let encodedIdentifier = Data(normalizedIdentifier.utf8)
            .base64EncodedString()
        return "\(defaultsPrefix).\(encodedIdentifier)"
    }

    private static func save(_ records: [ZixyAIChatHistoryRecord]) {
        guard let data = try? JSONEncoder().encode(records) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
