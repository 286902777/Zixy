import Foundation

enum ZixyRoomVoiceStore {

    private static let referencePrefix = "zixy_room_voice_"
    private static let directoryName = "RoomVoiceMessages"

    static func save(from sourceURL: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ZixyDataStoreError.unavailable
        }
        let reference = "\(referencePrefix)\(UUID().uuidString.lowercased()).m4a"
        let destinationURL = try directoryURL().appendingPathComponent(
            reference,
            isDirectory: false
        )
        do {
            try FileManager.default.copyItem(
                at: sourceURL,
                to: destinationURL
            )
            try? FileManager.default.removeItem(at: sourceURL)
            return reference
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
    }

    static func url(reference: String) -> URL? {
        guard reference.hasPrefix(referencePrefix) else {
            return nil
        }
        guard
            let url = try? directoryURL().appendingPathComponent(
                reference,
                isDirectory: false
            ),
            FileManager.default.fileExists(atPath: url.path)
        else {
            return nil
        }
        return url
    }

    static func remove(reference: String) {
        guard let url = url(reference: reference) else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    private static func directoryURL() throws -> URL {
        let fileManager = FileManager.default
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = applicationSupportURL
            .appendingPathComponent("Zixy", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        return directoryURL
    }
}
