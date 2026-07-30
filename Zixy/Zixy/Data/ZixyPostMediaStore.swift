import Foundation
import UIKit

extension Notification.Name {
    static let zixyPostDidCreate = Notification.Name(
        "zixy_post_did_create"
    )
    static let zixyBlacklistDidChange = Notification.Name(
        "zixy_blacklist_did_change"
    )
}

enum ZixyPostMediaStore {

    private static let localReferencePrefix = "zixy_local_post_"
    private static let directoryName = "PostMedia"

    static func image(reference: String) -> UIImage? {
        guard reference.hasPrefix(localReferencePrefix) else {
            let assetName = (reference as NSString).deletingPathExtension
            return UIImage(named: assetName)
        }
        guard let url = localURL(reference: reference) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    static func mediaURL(reference: String) -> URL? {
        if reference.hasPrefix(localReferencePrefix) {
            return localURL(reference: reference)
        }
        let path = reference as NSString
        return Bundle.main.url(
            forResource: path.deletingPathExtension,
            withExtension: path.pathExtension
        )
    }

    static func save(_ images: [UIImage]) throws -> [String] {
        guard !images.isEmpty, images.count <= 3 else {
            throw ZixyDataStoreError.unavailable
        }
        var savedReferences: [String] = []
        do {
            for image in images {
                guard let data = image.jpegData(compressionQuality: 0.86) else {
                    throw ZixyDataStoreError.unavailable
                }
                let reference = "\(localReferencePrefix)\(UUID().uuidString.lowercased()).jpg"
                let url = try mediaDirectoryURL().appendingPathComponent(
                    reference,
                    isDirectory: false
                )
                try data.write(to: url, options: .atomic)
                savedReferences.append(reference)
            }
            return savedReferences
        } catch {
            for reference in savedReferences {
                remove(reference: reference)
            }
            throw error
        }
    }

    static func saveVideo(from sourceURL: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ZixyDataStoreError.unavailable
        }
        let reference = "\(localReferencePrefix)\(UUID().uuidString.lowercased()).mov"
        let destinationURL = try mediaDirectoryURL().appendingPathComponent(
            reference,
            isDirectory: false
        )
        do {
            try FileManager.default.copyItem(
                at: sourceURL,
                to: destinationURL
            )
            return reference
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
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
