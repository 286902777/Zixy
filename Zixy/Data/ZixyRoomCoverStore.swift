import Foundation
import UIKit

enum ZixyRoomCoverStore {

    private static let localReferencePrefix = "zixy_local_room_cover_"
    private static let directoryName = "RoomCovers"

    static func image(reference: String) -> UIImage? {
        guard reference.hasPrefix(localReferencePrefix) else {
            return UIImage(named: reference)
        }
        guard let url = localURL(reference: reference) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    static func save(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.86) else {
            throw ZixyDataStoreError.unavailable
        }
        let reference = "\(localReferencePrefix)\(UUID().uuidString.lowercased()).jpg"
        let url = try mediaDirectoryURL().appendingPathComponent(
            reference,
            isDirectory: false
        )
        try data.write(to: url, options: .atomic)
        return reference
    }

    static func remove(reference: String) {
        guard
            reference.hasPrefix(localReferencePrefix),
            let url = localURL(reference: reference)
        else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    private static func localURL(reference: String) -> URL? {
        try? mediaDirectoryURL().appendingPathComponent(
            reference,
            isDirectory: false
        )
    }

    private static func mediaDirectoryURL() throws -> URL {
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
