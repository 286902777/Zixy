import CoreData
import CryptoKit
import Foundation

extension Notification.Name {
    static let zixyRoomMembershipDidChange = Notification.Name(
        "zixy_room_membership_did_change"
    )
}

struct ZixyUserRecord {
    let username: String
    let email: String
    let bio: String
    let avatarAssetName: String
}

struct ZixyPostRecord {
    let id: String
    let author: ZixyUserRecord
    let title: String
    let body: String
    let primaryMediaName: String
    let secondaryImageName: String
    let comment: String
    let likeCount: Int
    let commentCount: Int
    let isLikedByCurrentUser: Bool
    let createdAt: Date

    var mediaNames: [String] {
        [primaryMediaName] + secondaryImageName
            .split(separator: "|")
            .map(String.init)
    }
}

struct ZixyPostCommentRecord {
    let id: String
    let author: ZixyUserRecord
    let body: String
    let createdAt: Date
}

private struct ZixyStoredPostComment: Codable {
    let id: String
    let authorEmail: String
    let body: String
    let createdAt: Date
}

struct ZixyChatSummaryRecord {
    let participant: ZixyUserRecord
    let lastMessage: String
    let updatedAt: Date
}

struct ZixyChatMessageRecord {
    let senderEmail: String
    let recipientEmail: String
    let body: String
    let createdAt: Date
}

struct ZixyRoomRecord {
    let id: String
    let title: String
    let owner: ZixyUserRecord
    let coverAssetName: String
    let members: [ZixyUserRecord]

    var category: String {
        ZixyRoomCatalog.category(for: coverAssetName)
    }
}

enum ZixyRoomMessageKind: String {
    case text
    case voice
    case gift
}

struct ZixyRoomMessageRecord {
    let id: String
    let roomID: String
    let accountEmail: String
    let senderEmail: String
    let kind: ZixyRoomMessageKind
    let body: String
    let mediaReference: String
    let duration: TimeInterval
    let createdAt: Date
}

enum ZixyRoomCatalog {

    struct Cover {
        let category: String
        let assetName: String
    }

    static let categories = ["Leatherwork", "Resin Art", "Talks"]

    static let covers = [
        Cover(
            category: "Leatherwork",
            assetName: "35e2c4f07eee3e5b7cf4fbadd37b2cf4"
        ),
        Cover(
            category: "Leatherwork",
            assetName: "17d20ad772523ece39e702ac850ac038"
        ),
        Cover(
            category: "Resin Art",
            assetName: "09f64812752f4a595795fb7a885571e6"
        ),
        Cover(
            category: "Resin Art",
            assetName: "144c63ee13849abc44bdee9e7192fe52"
        ),
        Cover(
            category: "Talks",
            assetName: "0aceeb076394c622ae740324f7278ff3"
        ),
        Cover(
            category: "Talks",
            assetName: "cb0e121e473f6c9bbeab3cae9ea1f51f"
        )
    ]

    static func category(for assetName: String) -> String {
        covers.first(where: { $0.assetName == assetName })?.category
            ?? categories.first
            ?? "Leatherwork"
    }

    static func randomTitle(
        for category: String,
        excluding existingTitles: Set<String>
    ) -> String {
        let titles: [String]
        switch category {
        case "Leatherwork":
            titles = [
                "Leather Makers Circle",
                "The Tannery Table",
                "Stitch and Craft",
                "Hand Tooled Stories",
                "Leather Workshop Live"
            ]
        case "Resin Art":
            titles = [
                "Resin Color Lab",
                "Crystal Cast Club",
                "Pour and Create",
                "Resin Makers Live",
                "The Casting Studio"
            ]
        default:
            titles = [
                "Creative Coffee Talk",
                "Makers Open Mic",
                "Craft Stories Live",
                "The Friendly Workshop",
                "Ideas After Hours"
            ]
        }
        let availableTitles = titles.filter { !existingTitles.contains($0) }
        if let title = availableTitles.randomElement() {
            return title
        }
        let baseTitle = titles.randomElement() ?? "Creative Room"
        var candidate = baseTitle
        repeat {
            candidate = "\(baseTitle) \(Int.random(in: 10...99))"
        } while existingTitles.contains(candidate)
        return candidate
    }
}

enum ZixyDataStoreError: Error {
    case unavailable
    case duplicateEmail
}

@MainActor
final class ZixyDataStore {

    static let shared = ZixyDataStore()
    private static let defaultRoomMessageAccount =
        "zixy_room_default_messages"

    private enum Entity {
        static let user = "ZixyUser"
        static let post = "ZixyPost"
        static let follow = "ZixyFollow"
        static let message = "ZixyMessage"
        static let room = "ZixyRoom"
        static let roomMember = "ZixyRoomMember"
        static let roomMessage = "ZixyRoomMessage"
        static let blacklist = "ZixyBlacklist"
    }

    private let container: NSPersistentContainer
    private var isPrepared = false

    private init() {
        container = NSPersistentContainer(
            name: "ZixyDatabase",
            managedObjectModel: Self.makeManagedObjectModel()
        )
        container.persistentStoreDescriptions.first?
            .shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions.first?
            .shouldMigrateStoreAutomatically = true
        container.persistentStoreDescriptions.first?
            .shouldInferMappingModelAutomatically = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func prepareIfNeeded() throws {
        guard !isPrepared else {
            return
        }

        var storeError: Error?
        container.loadPersistentStores { _, error in
            storeError = error
        }
        if storeError != nil {
            throw ZixyDataStoreError.unavailable
        }
        isPrepared = true
        try seedIfNeeded()
    }

    func authenticate(email: String, password: String) -> ZixyUserRecord? {
        guard
            let object = fetchUser(email: email),
            object.string("passwordHash") == Self.passwordHash(password)
        else {
            return nil
        }
        return makeUserRecord(from: object)
    }

    func isEmailAvailable(_ email: String) -> Bool {
        fetchUser(email: email) == nil
    }

    func registerUser(
        username: String,
        email: String,
        password: String,
        avatarAssetName: String = "zixy_user_avatar"
    ) throws -> ZixyUserRecord {
        let normalizedEmail = Self.normalizeEmail(email)
        guard fetchUser(email: normalizedEmail) == nil else {
            throw ZixyDataStoreError.duplicateEmail
        }

        let object = NSEntityDescription.insertNewObject(
            forEntityName: Entity.user,
            into: container.viewContext
        )
        object.setValue(UUID().uuidString, forKey: "id")
        object.setValue(username, forKey: "username")
        object.setValue(normalizedEmail, forKey: "email")
        object.setValue(Self.passwordHash(password), forKey: "passwordHash")
        object.setValue("", forKey: "bio")
        object.setValue(avatarAssetName, forKey: "avatarAssetName")
        try container.viewContext.save()
        try seedRoomsIfNeeded()
        return makeUserRecord(from: object)
    }

    func currentUser() -> ZixyUserRecord? {
        fetchUser(email: ZixySessionStore.currentUserIdentifier)
            .map(makeUserRecord)
    }

    func updateCurrentUserProfile(
        username: String,
        bio: String,
        avatarAssetName: String
    ) throws -> ZixyUserRecord {
        guard let object = fetchUser(
            email: ZixySessionStore.currentUserIdentifier
        ) else {
            throw ZixyDataStoreError.unavailable
        }

        let previousUsername = object.string("username")
        let previousBio = object.string("bio")
        let previousAvatarAssetName = object.string("avatarAssetName")
        object.setValue(username, forKey: "username")
        object.setValue(bio, forKey: "bio")
        object.setValue(avatarAssetName, forKey: "avatarAssetName")

        do {
            try container.viewContext.save()
            return makeUserRecord(from: object)
        } catch {
            object.setValue(previousUsername, forKey: "username")
            object.setValue(previousBio, forKey: "bio")
            object.setValue(
                previousAvatarAssetName,
                forKey: "avatarAssetName"
            )
            throw error
        }
    }

    func posts() -> [ZixyPostRecord] {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.post)
        let postObjects = (try? container.viewContext.fetch(request)) ?? []
        let blockedEmails = currentUserBlockedEmails()
        let seedOrder = Dictionary(
            uniqueKeysWithValues: Self.seedRows.enumerated().map { index, row in
                ("\(row.username.lowercased())@gmail.com", index)
            }
        )
        return postObjects.compactMap(makePostRecord)
            .filter { !blockedEmails.contains($0.author.email) }
            .sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            let lhsOrder = seedOrder[lhs.author.email] ?? Int.max
            let rhsOrder = seedOrder[rhs.author.email] ?? Int.max
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                == .orderedAscending
        }
    }

    func post(id: String) -> ZixyPostRecord? {
        guard
            let post = fetchPost(id: id).flatMap(makePostRecord),
            !currentUserBlockedEmails().contains(post.author.email)
        else {
            return nil
        }
        return post
    }

    func comments(for postID: String) -> [ZixyPostCommentRecord] {
        guard let post = fetchPost(id: postID) else {
            return []
        }
        let blockedEmails = currentUserBlockedEmails()
        return storedComments(from: post).compactMap { comment in
            guard
                !blockedEmails.contains(
                    Self.normalizeEmail(comment.authorEmail)
                ),
                let author = fetchUser(email: comment.authorEmail)
                    .map(makeUserRecord)
            else {
                return nil
            }
            return ZixyPostCommentRecord(
                id: comment.id,
                author: author,
                body: comment.body,
                createdAt: comment.createdAt
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func usersWhoLiked(postID: String) -> [ZixyUserRecord] {
        guard let post = fetchPost(id: postID) else {
            return []
        }
        let blockedEmails = currentUserBlockedEmails()
        return post.string("likedBy")
            .split(separator: "|")
            .map(String.init)
            .filter {
                !blockedEmails.contains(Self.normalizeEmail($0))
            }
            .compactMap {
                fetchUser(email: $0).map(makeUserRecord)
            }
            .sorted {
                $0.username.localizedCaseInsensitiveCompare($1.username)
                    == .orderedAscending
            }
    }

    func setPostLiked(
        _ shouldLike: Bool,
        postID: String
    ) throws -> ZixyPostRecord {
        guard
            ZixySessionStore.isAuthenticated,
            let post = fetchPost(id: postID)
        else {
            throw ZixyDataStoreError.unavailable
        }
        let email = Self.normalizeEmail(
            ZixySessionStore.currentUserIdentifier
        )
        var likedBy = Set(
            post.string("likedBy")
                .split(separator: "|")
                .map(String.init)
        )
        let wasLiked = likedBy.contains(email)
        guard wasLiked != shouldLike else {
            guard let record = makePostRecord(from: post) else {
                throw ZixyDataStoreError.unavailable
            }
            return record
        }

        if shouldLike {
            likedBy.insert(email)
        } else {
            likedBy.remove(email)
        }
        let previousCount = post.int64("likeCount")
        post.setValue(
            max(0, previousCount + (shouldLike ? 1 : -1)),
            forKey: "likeCount"
        )
        post.setValue(likedBy.sorted().joined(separator: "|"), forKey: "likedBy")
        do {
            try container.viewContext.save()
        } catch {
            container.viewContext.rollback()
            throw error
        }
        guard let record = makePostRecord(from: post) else {
            throw ZixyDataStoreError.unavailable
        }
        return record
    }

    func addComment(
        to postID: String,
        body: String
    ) throws -> ZixyPostCommentRecord {
        guard
            let author = currentUser(),
            let post = fetchPost(id: postID)
        else {
            throw ZixyDataStoreError.unavailable
        }
        let stored = ZixyStoredPostComment(
            id: UUID().uuidString,
            authorEmail: author.email,
            body: body,
            createdAt: Date()
        )
        var comments = storedComments(from: post)
        comments.append(stored)
        guard let data = try? JSONEncoder().encode(comments),
              let encoded = String(data: data, encoding: .utf8) else {
            throw ZixyDataStoreError.unavailable
        }
        post.setValue(encoded, forKey: "comment")
        do {
            try container.viewContext.save()
        } catch {
            container.viewContext.rollback()
            throw error
        }
        return ZixyPostCommentRecord(
            id: stored.id,
            author: author,
            body: stored.body,
            createdAt: stored.createdAt
        )
    }

    func createPost(
        title: String,
        body: String,
        mediaNames: [String]
    ) throws -> ZixyPostRecord {
        let videoExtensions = Set(["mp4", "mov", "m4v"])
        let videoCount = mediaNames.filter {
            videoExtensions.contains(
                ($0 as NSString).pathExtension.lowercased()
            )
        }.count
        guard
            !mediaNames.isEmpty,
            (
                videoCount == 0
                    ? mediaNames.count <= 3
                    : mediaNames.count == 1
            ),
            let author = currentUser()
        else {
            throw ZixyDataStoreError.unavailable
        }

        let object = NSEntityDescription.insertNewObject(
            forEntityName: Entity.post,
            into: container.viewContext
        )
        let timestamp = Int64(Date().timeIntervalSince1970 * 1_000)
        let postID = "published_\(timestamp)_\(UUID().uuidString.lowercased())"
        object.setValue(postID, forKey: "id")
        object.setValue(author.email, forKey: "authorEmail")
        object.setValue(title, forKey: "title")
        object.setValue(body, forKey: "body")
        object.setValue(mediaNames[0], forKey: "primaryMediaName")
        object.setValue(
            mediaNames.dropFirst().joined(separator: "|"),
            forKey: "secondaryImageName"
        )
        object.setValue("", forKey: "comment")
        object.setValue(Int64(0), forKey: "likeCount")
        object.setValue("", forKey: "likedBy")
        object.setValue(Date(), forKey: "createdAt")

        do {
            try container.viewContext.save()
        } catch {
            container.viewContext.delete(object)
            throw error
        }
        return ZixyPostRecord(
            id: postID,
            author: author,
            title: title,
            body: body,
            primaryMediaName: mediaNames[0],
            secondaryImageName: mediaNames.dropFirst().joined(separator: "|"),
            comment: "",
            likeCount: 0,
            commentCount: 0,
            isLikedByCurrentUser: false,
            createdAt: Date(timeIntervalSince1970: Double(timestamp) / 1_000)
        )
    }

    func posts(for email: String) -> [ZixyPostRecord] {
        let normalizedEmail = Self.normalizeEmail(email)
        return posts().filter { $0.author.email == normalizedEmail }
    }

    func followers(for email: String) -> [ZixyUserRecord] {
        relatedUsers(for: email, relationKey: "followedEmail", resultKey: "followerEmail")
    }

    func following(for email: String) -> [ZixyUserRecord] {
        relatedUsers(for: email, relationKey: "followerEmail", resultKey: "followedEmail")
    }

    func isFollowing(_ followedEmail: String, from followerEmail: String) -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.follow)
        request.fetchLimit = 1
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(
                format: "followerEmail == %@",
                Self.normalizeEmail(followerEmail)
            ),
            NSPredicate(
                format: "followedEmail == %@",
                Self.normalizeEmail(followedEmail)
            )
        ])
        return ((try? container.viewContext.count(for: request)) ?? 0) > 0
    }

    func setFollowing(
        _ shouldFollow: Bool,
        followedEmail: String,
        followerEmail: String
    ) throws {
        let normalizedFollower = Self.normalizeEmail(followerEmail)
        let normalizedFollowed = Self.normalizeEmail(followedEmail)
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.follow)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "followerEmail == %@", normalizedFollower),
            NSPredicate(format: "followedEmail == %@", normalizedFollowed)
        ])
        let matches = try container.viewContext.fetch(request)
        if shouldFollow, matches.isEmpty {
            insertFollow(from: normalizedFollower, to: normalizedFollowed)
        } else if !shouldFollow {
            matches.forEach(container.viewContext.delete)
        }
        try container.viewContext.save()
    }

    func blockedUsers(for blockerEmail: String) -> [ZixyUserRecord] {
        blockedUserEmails(for: blockerEmail)
            .compactMap { fetchUser(email: $0) }
            .map(makeUserRecord)
            .sorted {
                $0.username.localizedCaseInsensitiveCompare($1.username)
                    == .orderedAscending
            }
    }

    func blockedUserEmails(for blockerEmail: String) -> Set<String> {
        let request = NSFetchRequest<NSManagedObject>(
            entityName: Entity.blacklist
        )
        request.predicate = NSPredicate(
            format: "blockerEmail == %@",
            Self.normalizeEmail(blockerEmail)
        )
        return Set(
            ((try? container.viewContext.fetch(request)) ?? [])
                .map { Self.normalizeEmail($0.string("blockedEmail")) }
        )
    }

    func isBlocked(
        _ blockedEmail: String,
        by blockerEmail: String
    ) -> Bool {
        let request = NSFetchRequest<NSManagedObject>(
            entityName: Entity.blacklist
        )
        request.fetchLimit = 1
        request.predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [
                NSPredicate(
                    format: "blockerEmail == %@",
                    Self.normalizeEmail(blockerEmail)
                ),
                NSPredicate(
                    format: "blockedEmail == %@",
                    Self.normalizeEmail(blockedEmail)
                )
            ]
        )
        return ((try? container.viewContext.count(for: request)) ?? 0) > 0
    }

    func setBlocked(
        _ shouldBlock: Bool,
        blockedEmail: String,
        blockerEmail: String
    ) throws {
        let blocker = Self.normalizeEmail(blockerEmail)
        let blocked = Self.normalizeEmail(blockedEmail)
        guard
            blocker != blocked,
            fetchUser(email: blocker) != nil,
            fetchUser(email: blocked) != nil
        else {
            throw ZixyDataStoreError.unavailable
        }

        let request = NSFetchRequest<NSManagedObject>(
            entityName: Entity.blacklist
        )
        request.predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [
                NSPredicate(format: "blockerEmail == %@", blocker),
                NSPredicate(format: "blockedEmail == %@", blocked)
            ]
        )
        let existing = try container.viewContext.fetch(request)
        if shouldBlock, existing.isEmpty {
            let object = NSEntityDescription.insertNewObject(
                forEntityName: Entity.blacklist,
                into: container.viewContext
            )
            object.setValue(UUID().uuidString, forKey: "id")
            object.setValue(blocker, forKey: "blockerEmail")
            object.setValue(blocked, forKey: "blockedEmail")
            removeFollowRelationships(between: blocker, and: blocked)
            removeRoomMemberships(between: blocker, and: blocked)
        } else if !shouldBlock {
            existing.forEach(container.viewContext.delete)
        }
        try container.viewContext.save()
        NotificationCenter.default.post(
            name: .zixyBlacklistDidChange,
            object: blocked
        )
        NotificationCenter.default.post(
            name: .zixyRoomMembershipDidChange,
            object: nil
        )
    }

    @discardableResult
    func setBlocked(
        _ shouldBlock: Bool,
        blockedUsername: String,
        blockerEmail: String
    ) throws -> ZixyUserRecord {
        guard let target = user(username: blockedUsername) else {
            throw ZixyDataStoreError.unavailable
        }
        try setBlocked(
            shouldBlock,
            blockedEmail: target.email,
            blockerEmail: blockerEmail
        )
        return target
    }

    func chatSummaries(for email: String) -> [ZixyChatSummaryRecord] {
        let normalizedEmail = Self.normalizeEmail(email)
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.message)
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "senderEmail == %@", normalizedEmail),
            NSPredicate(format: "recipientEmail == %@", normalizedEmail)
        ])
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        guard let messages = try? container.viewContext.fetch(request) else {
            return []
        }

        var seen = Set<String>()
        return messages.compactMap { message in
            let sender = message.string("senderEmail")
            let recipient = message.string("recipientEmail")
            let participantEmail = sender == normalizedEmail ? recipient : sender
            guard
                seen.insert(participantEmail).inserted,
                let participant = fetchUser(email: participantEmail)
                    .map(makeUserRecord)
            else {
                return nil
            }
            return ZixyChatSummaryRecord(
                participant: participant,
                lastMessage: message.string("body"),
                updatedAt: message.value(forKey: "createdAt") as? Date ?? Date()
            )
        }
    }

    func messages(
        between firstEmail: String,
        and secondEmail: String
    ) -> [ZixyChatMessageRecord] {
        let first = Self.normalizeEmail(firstEmail)
        let second = Self.normalizeEmail(secondEmail)
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.message)
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "senderEmail == %@", first),
                NSPredicate(format: "recipientEmail == %@", second)
            ]),
            NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "senderEmail == %@", second),
                NSPredicate(format: "recipientEmail == %@", first)
            ])
        ])
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        return ((try? container.viewContext.fetch(request)) ?? []).map {
            ZixyChatMessageRecord(
                senderEmail: $0.string("senderEmail"),
                recipientEmail: $0.string("recipientEmail"),
                body: $0.string("body"),
                createdAt: $0.value(forKey: "createdAt") as? Date ?? Date()
            )
        }
    }

    func addMessage(
        body: String,
        senderEmail: String,
        recipientEmail: String
    ) throws {
        insertMessage(
            body: body,
            sender: Self.normalizeEmail(senderEmail),
            recipient: Self.normalizeEmail(recipientEmail),
            date: Date()
        )
        try container.viewContext.save()
    }

    func user(username: String) -> ZixyUserRecord? {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.user)
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "username =[c] %@",
            username.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return (try? container.viewContext.fetch(request).first)
            .flatMap { $0 }
            .map(makeUserRecord)
    }

    func user(email: String) -> ZixyUserRecord? {
        fetchUser(email: email).map(makeUserRecord)
    }

    func rooms(for email: String) -> [ZixyRoomRecord] {
        let normalizedEmail = Self.normalizeEmail(email)
        let restrictedEmails = restrictedUserEmails(for: normalizedEmail)
        let membershipRequest = NSFetchRequest<NSManagedObject>(
            entityName: Entity.roomMember
        )
        membershipRequest.predicate = NSPredicate(
            format: "userEmail == %@",
            normalizedEmail
        )
        let roomIDs = ((try? container.viewContext.fetch(membershipRequest)) ?? [])
            .map { $0.string("roomID") }
        guard !roomIDs.isEmpty else {
            return []
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.room)
        request.predicate = NSPredicate(format: "id IN %@", roomIDs)
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        return ((try? container.viewContext.fetch(request)) ?? [])
            .compactMap(makeRoomRecord)
            .compactMap {
                roomRecord(
                    $0,
                    excluding: restrictedEmails
                )
            }
    }

    func room(id: String, visibleTo email: String) -> ZixyRoomRecord? {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.room)
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id)
        let restrictedEmails = restrictedUserEmails(for: email)
        return (try? container.viewContext.fetch(request).first)
            .flatMap { $0 }
            .flatMap(makeRoomRecord)
            .flatMap {
                roomRecord(
                    $0,
                    excluding: restrictedEmails
                )
            }
    }

    @discardableResult
    func joinRoom(id: String, userEmail: String) throws -> ZixyRoomRecord {
        let normalizedEmail = Self.normalizeEmail(userEmail)
        guard fetchUser(email: normalizedEmail) != nil else {
            throw ZixyDataStoreError.unavailable
        }

        let roomRequest = NSFetchRequest<NSManagedObject>(entityName: Entity.room)
        roomRequest.fetchLimit = 1
        roomRequest.predicate = NSPredicate(format: "id == %@", id)
        guard let room = try container.viewContext.fetch(roomRequest).first else {
            throw ZixyDataStoreError.unavailable
        }
        guard !hasBlockingRelationship(
            between: normalizedEmail,
            and: room.string("ownerEmail")
        ) else {
            throw ZixyDataStoreError.unavailable
        }

        let membershipRequest = NSFetchRequest<NSManagedObject>(
            entityName: Entity.roomMember
        )
        membershipRequest.fetchLimit = 1
        membershipRequest.predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [
                NSPredicate(format: "roomID == %@", id),
                NSPredicate(format: "userEmail == %@", normalizedEmail)
            ]
        )
        if try container.viewContext.fetch(membershipRequest).isEmpty {
            let membership = NSEntityDescription.insertNewObject(
                forEntityName: Entity.roomMember,
                into: container.viewContext
            )
            membership.setValue(UUID().uuidString, forKey: "id")
            membership.setValue(id, forKey: "roomID")
            membership.setValue(normalizedEmail, forKey: "userEmail")
            do {
                try container.viewContext.save()
            } catch {
                container.viewContext.delete(membership)
                throw error
            }
        }

        guard
            let record = makeRoomRecord(from: room),
            let visibleRecord = roomRecord(
                record,
                excluding: restrictedUserEmails(for: normalizedEmail)
            )
        else {
            throw ZixyDataStoreError.unavailable
        }
        return visibleRecord
    }

    func roomMessages(
        roomID: String,
        accountEmail: String
    ) -> [ZixyRoomMessageRecord] {
        let request = NSFetchRequest<NSManagedObject>(
            entityName: Entity.roomMessage
        )
        let accountPredicate: NSPredicate
        if roomID.hasPrefix("zixy_seed_room_") {
            accountPredicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [
                    NSPredicate(
                        format: "accountEmail == %@",
                        Self.normalizeEmail(accountEmail)
                    ),
                    NSPredicate(
                        format: "accountEmail == %@",
                        Self.defaultRoomMessageAccount
                    )
                ]
            )
        } else {
            accountPredicate = NSPredicate(
                format: "accountEmail == %@",
                Self.normalizeEmail(accountEmail)
            )
        }
        request.predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [
                NSPredicate(format: "roomID == %@", roomID),
                accountPredicate
            ]
        )
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        let restrictedEmails = restrictedUserEmails(for: accountEmail)
        return ((try? container.viewContext.fetch(request)) ?? [])
            .compactMap(makeRoomMessageRecord)
            .filter {
                !restrictedEmails.contains(
                    Self.normalizeEmail($0.senderEmail)
                )
            }
    }

    @discardableResult
    func addRoomMessage(
        roomID: String,
        accountEmail: String,
        senderEmail: String,
        kind: ZixyRoomMessageKind,
        body: String,
        mediaReference: String = "",
        duration: TimeInterval = 0
    ) throws -> ZixyRoomMessageRecord {
        let object = NSEntityDescription.insertNewObject(
            forEntityName: Entity.roomMessage,
            into: container.viewContext
        )
        let id = UUID().uuidString
        let createdAt = Date()
        object.setValue(id, forKey: "id")
        object.setValue(roomID, forKey: "roomID")
        object.setValue(
            Self.normalizeEmail(accountEmail),
            forKey: "accountEmail"
        )
        object.setValue(
            Self.normalizeEmail(senderEmail),
            forKey: "senderEmail"
        )
        object.setValue(kind.rawValue, forKey: "kind")
        object.setValue(body, forKey: "body")
        object.setValue(mediaReference, forKey: "mediaReference")
        object.setValue(Int64(duration * 1_000), forKey: "durationMilliseconds")
        object.setValue(createdAt, forKey: "createdAt")
        do {
            try container.viewContext.save()
        } catch {
            container.viewContext.delete(object)
            throw error
        }
        return ZixyRoomMessageRecord(
            id: id,
            roomID: roomID,
            accountEmail: Self.normalizeEmail(accountEmail),
            senderEmail: Self.normalizeEmail(senderEmail),
            kind: kind,
            body: body,
            mediaReference: mediaReference,
            duration: duration,
            createdAt: createdAt
        )
    }

    func ownedRoom(for email: String) -> ZixyRoomRecord? {
        let normalizedEmail = Self.normalizeEmail(email)
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.room)
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "ownerEmail == %@",
            normalizedEmail
        )
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        return (try? container.viewContext.fetch(request).first)
            .flatMap { $0 }
            .flatMap(makeRoomRecord)
            .flatMap {
                roomRecord(
                    $0,
                    excluding: restrictedUserEmails(for: normalizedEmail)
                )
            }
    }

    func saveOwnedRoom(
        id: String?,
        title: String,
        coverAssetName: String,
        ownerEmail: String
    ) throws -> ZixyRoomRecord {
        let normalizedOwnerEmail = Self.normalizeEmail(ownerEmail)
        guard fetchUser(email: normalizedOwnerEmail) != nil else {
            throw ZixyDataStoreError.unavailable
        }

        let room: NSManagedObject
        if let id {
            let request = NSFetchRequest<NSManagedObject>(entityName: Entity.room)
            request.fetchLimit = 1
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "id == %@", id),
                NSPredicate(format: "ownerEmail == %@", normalizedOwnerEmail)
            ])
            guard let existingRoom = try container.viewContext.fetch(request).first else {
                throw ZixyDataStoreError.unavailable
            }
            room = existingRoom
        } else if let existingRoom = ownedRoomObject(for: normalizedOwnerEmail) {
            room = existingRoom
        } else {
            room = NSEntityDescription.insertNewObject(
                forEntityName: Entity.room,
                into: container.viewContext
            )
            room.setValue(UUID().uuidString, forKey: "id")
            room.setValue(normalizedOwnerEmail, forKey: "ownerEmail")
            room.setValue(Date(), forKey: "createdAt")
        }

        room.setValue(title, forKey: "title")
        room.setValue(coverAssetName, forKey: "coverAssetName")

        let roomID = room.string("id")
        let membershipRequest = NSFetchRequest<NSManagedObject>(
            entityName: Entity.roomMember
        )
        membershipRequest.fetchLimit = 1
        membershipRequest.predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [
                NSPredicate(format: "roomID == %@", roomID),
                NSPredicate(format: "userEmail == %@", normalizedOwnerEmail)
            ]
        )
        if try container.viewContext.fetch(membershipRequest).isEmpty {
            let membership = NSEntityDescription.insertNewObject(
                forEntityName: Entity.roomMember,
                into: container.viewContext
            )
            membership.setValue(UUID().uuidString, forKey: "id")
            membership.setValue(roomID, forKey: "roomID")
            membership.setValue(normalizedOwnerEmail, forKey: "userEmail")
        }

        try removeDefaultRoomMessagesIfNeeded(roomID: roomID)
        try container.viewContext.save()
        guard let record = makeRoomRecord(from: room) else {
            throw ZixyDataStoreError.unavailable
        }
        return record
    }

    func deleteOwnedRoom(id: String, ownerEmail: String) throws {
        let normalizedOwnerEmail = Self.normalizeEmail(ownerEmail)
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.room)
        request.fetchLimit = 1
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "id == %@", id),
            NSPredicate(format: "ownerEmail == %@", normalizedOwnerEmail)
        ])
        guard let room = try container.viewContext.fetch(request).first else {
            throw ZixyDataStoreError.unavailable
        }

        let membershipRequest = NSFetchRequest<NSManagedObject>(
            entityName: Entity.roomMember
        )
        membershipRequest.predicate = NSPredicate(format: "roomID == %@", id)
        try container.viewContext.fetch(membershipRequest)
            .forEach(container.viewContext.delete)
        let messageRequest = NSFetchRequest<NSManagedObject>(
            entityName: Entity.roomMessage
        )
        messageRequest.predicate = NSPredicate(format: "roomID == %@", id)
        try container.viewContext.fetch(messageRequest)
            .forEach(container.viewContext.delete)
        container.viewContext.delete(room)
        try container.viewContext.save()
    }

    func rooms(category: String) -> [ZixyRoomRecord] {
        let restrictedEmails = ZixySessionStore.isAuthenticated
            ? restrictedUserEmails(
                for: ZixySessionStore.currentUserIdentifier
            )
            : []
        return allRooms()
            .compactMap {
                roomRecord(
                    $0,
                    excluding: restrictedEmails
                )
            }
            .filter { $0.category == category }
    }

    private func allRooms() -> [ZixyRoomRecord] {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.room)
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        return ((try? container.viewContext.fetch(request)) ?? [])
            .compactMap(makeRoomRecord)
    }

    private func ownedRoomObject(for normalizedOwnerEmail: String) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.room)
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "ownerEmail == %@",
            normalizedOwnerEmail
        )
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        return try? container.viewContext.fetch(request).first
    }

    private func seedIfNeeded() throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.user)
        if try container.viewContext.count(for: request) == 0 {
            let rows = Self.seedRows
            let referenceDate = Date()
            for row in rows {
                let user = NSEntityDescription.insertNewObject(
                    forEntityName: Entity.user,
                    into: container.viewContext
                )
                let email = "\(row.username.lowercased())@gmail.com"
                user.setValue(UUID().uuidString, forKey: "id")
                user.setValue(row.username, forKey: "username")
                user.setValue(email, forKey: "email")
                user.setValue(Self.passwordHash("123456"), forKey: "passwordHash")
                user.setValue(row.bio, forKey: "bio")
                user.setValue(
                    (row.avatar as NSString).deletingPathExtension,
                    forKey: "avatarAssetName"
                )

                let post = NSEntityDescription.insertNewObject(
                    forEntityName: Entity.post,
                    into: container.viewContext
                )
                post.setValue(UUID().uuidString, forKey: "id")
                post.setValue(email, forKey: "authorEmail")
                post.setValue(row.title, forKey: "title")
                post.setValue(row.caption, forKey: "body")
                post.setValue(row.primaryMedia, forKey: "primaryMediaName")
                post.setValue(row.secondaryImage, forKey: "secondaryImageName")
                post.setValue(row.comment, forKey: "comment")
                post.setValue(
                    Int64.random(in: 0...100),
                    forKey: "likeCount"
                )
                post.setValue("", forKey: "likedBy")
                post.setValue(
                    Self.randomDateWithinPreviousDay(
                        referenceDate: referenceDate
                    ),
                    forKey: "createdAt"
                )
            }

            guard
                let elena = rows.first(where: { $0.username == "Elena" })
            else {
                throw ZixyDataStoreError.unavailable
            }
            let randomUsers = rows
                .filter { $0.username != elena.username }
                .shuffled()
                .prefix(2)
            let selectedUsers = [elena] + randomUsers
            let selectedEmails = selectedUsers.map {
                "\($0.username.lowercased())@gmail.com"
            }

            for follower in selectedEmails {
                for followed in selectedEmails where follower != followed {
                    insertFollow(from: follower, to: followed)
                }
            }
            insertSeedMessages(between: selectedEmails)
            try container.viewContext.save()
        }

        try backfillPostMetadataIfNeeded()
        try seedRoomsIfNeeded()
    }

    private func backfillPostMetadataIfNeeded() throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.post)
        let posts = try container.viewContext.fetch(request)
        let referenceDate = Date()
        var didChange = false
        for post in posts {
            let isSeedPost = Self.seedRows.contains(where: {
                    post.string("authorEmail")
                        == "\($0.username.lowercased())@gmail.com"
                        && post.string("title") == $0.title
                })
            if isSeedPost,
               post.string("likedBy").isEmpty,
               !(0...100).contains(post.int64("likeCount")) {
                post.setValue(Int64.random(in: 0...100), forKey: "likeCount")
                didChange = true
            }
            guard post.value(forKey: "createdAt") as? Date == nil else {
                continue
            }
            let createdAt: Date
            if isSeedPost {
                createdAt = Self.randomDateWithinPreviousDay(
                    referenceDate: referenceDate
                )
            } else if let timestamp = Self.publishedTimestamp(
                from: post.string("id")
            ) {
                createdAt = Date(
                    timeIntervalSince1970: Double(timestamp) / 1_000
                )
            } else {
                createdAt = referenceDate
            }
            post.setValue(createdAt, forKey: "createdAt")
            didChange = true
        }
        if didChange {
            try container.viewContext.save()
        }
    }

    private func seedRoomsIfNeeded() throws {
        let roomRequest = NSFetchRequest<NSManagedObject>(entityName: Entity.room)
        var roomObjects = try container.viewContext.fetch(roomRequest)
        let userRequest = NSFetchRequest<NSManagedObject>(entityName: Entity.user)
        let users = try container.viewContext.fetch(userRequest)
            .map(makeUserRecord)
        let eligibleOwners = users.filter {
            $0.username.caseInsensitiveCompare("Elena") != .orderedSame
        }
        guard users.count >= 2, !eligibleOwners.isEmpty else {
            throw ZixyDataStoreError.unavailable
        }

        let legacyTitles = [
            "Leather Craft Circle",
            "Handmade Ideas Lounge"
        ]
        let legacyRooms = roomObjects.filter {
            legacyTitles.contains($0.string("title"))
        }
        if !legacyRooms.isEmpty {
            let legacyRoomIDs = legacyRooms.map { $0.string("id") }
            let membershipRequest = NSFetchRequest<NSManagedObject>(
                entityName: Entity.roomMember
            )
            membershipRequest.predicate = NSPredicate(
                format: "roomID IN %@",
                legacyRoomIDs
            )
            try container.viewContext.fetch(membershipRequest)
                .forEach(container.viewContext.delete)
            let messageRequest = NSFetchRequest<NSManagedObject>(
                entityName: Entity.roomMessage
            )
            messageRequest.predicate = NSPredicate(
                format: "roomID IN %@",
                legacyRoomIDs
            )
            try container.viewContext.fetch(messageRequest)
                .forEach(container.viewContext.delete)
            legacyRooms.forEach(container.viewContext.delete)
            roomObjects.removeAll {
                legacyRoomIDs.contains($0.string("id"))
            }
        }

        let seededRooms = roomObjects.filter {
            $0.string("id").hasPrefix("zixy_seed_room_")
        }
        var existingTitles = Set(roomObjects.map { $0.string("title") })
        let ownedEmails = Set(roomObjects.map { $0.string("ownerEmail") })
        var ownersNeedingRooms = eligibleOwners
            .filter { !ownedEmails.contains($0.email) }
            .shuffled()
        var unusedCovers = ZixyRoomCatalog.covers.filter { cover in
            !seededRooms.contains {
                $0.string("coverAssetName") == cover.assetName
            }
        }

        var pendingRooms: [(ZixyUserRecord, ZixyRoomCatalog.Cover)] = []
        while let owner = ownersNeedingRooms.popLast() {
            let cover = unusedCovers.isEmpty
                ? ZixyRoomCatalog.covers.randomElement()
                : unusedCovers.removeFirst()
            if let cover {
                pendingRooms.append((owner, cover))
            }
        }
        while !unusedCovers.isEmpty {
            guard let owner = eligibleOwners.randomElement() else {
                break
            }
            pendingRooms.append((owner, unusedCovers.removeFirst()))
        }

        var roomIDs = roomObjects.map { $0.string("id") }
        for (owner, cover) in pendingRooms {
            let roomID = "zixy_seed_room_\(UUID().uuidString)"
            roomIDs.append(roomID)
            let title = ZixyRoomCatalog.randomTitle(
                for: cover.category,
                excluding: existingTitles
            )
            existingTitles.insert(title)
            let room = NSEntityDescription.insertNewObject(
                forEntityName: Entity.room,
                into: container.viewContext
            )
            room.setValue(roomID, forKey: "id")
            room.setValue(title, forKey: "title")
            room.setValue(owner.email, forKey: "ownerEmail")
            room.setValue(cover.assetName, forKey: "coverAssetName")
            room.setValue(Date(), forKey: "createdAt")

            let maximumMemberCount = min(6, users.count)
            let memberCount = Int.random(in: 2...maximumMemberCount)
            let otherMembers = users
                .filter { $0.email != owner.email }
                .shuffled()
                .prefix(memberCount - 1)
            let members = [owner] + Array(otherMembers)
            for member in members {
                let membership = NSEntityDescription.insertNewObject(
                    forEntityName: Entity.roomMember,
                    into: container.viewContext
                )
                membership.setValue(UUID().uuidString, forKey: "id")
                membership.setValue(roomID, forKey: "roomID")
                membership.setValue(member.email, forKey: "userEmail")
            }
        }
        try assignElenaToRandomSeedRooms(
            roomIDs: roomIDs,
            users: users
        )
        try seedDefaultRoomMessagesIfNeeded(roomIDs: roomIDs)
        try container.viewContext.save()
    }

    private func assignElenaToRandomSeedRooms(
        roomIDs: [String],
        users: [ZixyUserRecord]
    ) throws {
        guard
            let elena = users.first(where: {
                $0.username.caseInsensitiveCompare("Elena") == .orderedSame
            })
        else {
            return
        }
        let seededRoomIDs = roomIDs.filter {
            $0.hasPrefix("zixy_seed_room_")
        }
        guard !seededRoomIDs.isEmpty else {
            return
        }

        let membershipRequest = NSFetchRequest<NSManagedObject>(
            entityName: Entity.roomMember
        )
        membershipRequest.predicate = NSPredicate(
            format: "roomID IN %@",
            seededRoomIDs
        )
        var memberships = try container.viewContext.fetch(membershipRequest)
        let currentElenaRoomIDs = Set(
            memberships
                .filter {
                    $0.string("userEmail").caseInsensitiveCompare(elena.email)
                        == .orderedSame
                }
                .map { $0.string("roomID") }
        )
        guard !(2...3).contains(currentElenaRoomIDs.count) else {
            return
        }

        let targetCount = min(
            Int.random(in: 2...3),
            seededRoomIDs.count
        )
        let targetRoomIDs = Set(
            seededRoomIDs.shuffled().prefix(targetCount)
        )
        let roomRequest = NSFetchRequest<NSManagedObject>(
            entityName: Entity.room
        )
        roomRequest.predicate = NSPredicate(
            format: "id IN %@",
            seededRoomIDs
        )
        let ownerByRoomID = Dictionary(
            uniqueKeysWithValues: try container.viewContext
                .fetch(roomRequest)
                .map { ($0.string("id"), $0.string("ownerEmail")) }
        )

        for membership in memberships {
            let roomID = membership.string("roomID")
            let isElena = membership.string("userEmail")
                .caseInsensitiveCompare(elena.email) == .orderedSame
            if isElena, !targetRoomIDs.contains(roomID) {
                container.viewContext.delete(membership)
            }
        }
        memberships.removeAll {
            $0.string("userEmail").caseInsensitiveCompare(elena.email)
                == .orderedSame
                && !targetRoomIDs.contains($0.string("roomID"))
        }

        for roomID in targetRoomIDs {
            var roomMemberships = memberships.filter {
                $0.string("roomID") == roomID
            }
            let alreadyContainsElena = roomMemberships.contains {
                $0.string("userEmail").caseInsensitiveCompare(elena.email)
                    == .orderedSame
            }
            guard !alreadyContainsElena else {
                continue
            }
            if roomMemberships.count >= 6 {
                let ownerEmail = ownerByRoomID[roomID] ?? ""
                let removableMemberships = roomMemberships.filter {
                    $0.string("userEmail")
                        .caseInsensitiveCompare(ownerEmail) != .orderedSame
                }
                if let removableMembership =
                    removableMemberships.randomElement() {
                    container.viewContext.delete(removableMembership)
                    roomMemberships.removeAll { $0 === removableMembership }
                    memberships.removeAll { $0 === removableMembership }
                }
            }
            let membership = NSEntityDescription.insertNewObject(
                forEntityName: Entity.roomMember,
                into: container.viewContext
            )
            membership.setValue(UUID().uuidString, forKey: "id")
            membership.setValue(roomID, forKey: "roomID")
            membership.setValue(elena.email, forKey: "userEmail")
            memberships.append(membership)
        }

        for roomID in seededRoomIDs {
            let roomMemberships = memberships.filter {
                $0.string("roomID") == roomID
            }
            guard roomMemberships.count < 2 else {
                continue
            }
            let existingEmails = Set(
                roomMemberships.map { $0.string("userEmail") }
            )
            let replacementCandidates = users.filter {
                $0.email != elena.email
                    && !existingEmails.contains($0.email)
            }
            guard let replacement = replacementCandidates.randomElement() else {
                continue
            }
            let membership = NSEntityDescription.insertNewObject(
                forEntityName: Entity.roomMember,
                into: container.viewContext
            )
            membership.setValue(UUID().uuidString, forKey: "id")
            membership.setValue(roomID, forKey: "roomID")
            membership.setValue(replacement.email, forKey: "userEmail")
            memberships.append(membership)
        }
    }

    private func seedDefaultRoomMessagesIfNeeded(
        roomIDs: [String]
    ) throws {
        guard !roomIDs.isEmpty else {
            return
        }
        let roomRequest = NSFetchRequest<NSManagedObject>(
            entityName: Entity.room
        )
        roomRequest.predicate = NSPredicate(format: "id IN %@", roomIDs)
        let rooms = try container.viewContext.fetch(roomRequest)
        let referenceDate = Date()

        for room in rooms {
            let roomID = room.string("id")
            guard roomID.hasPrefix("zixy_seed_room_") else {
                try removeDefaultRoomMessagesIfNeeded(roomID: roomID)
                continue
            }
            let existingRequest = NSFetchRequest<NSManagedObject>(
                entityName: Entity.roomMessage
            )
            existingRequest.fetchLimit = 1
            existingRequest.predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [
                    NSPredicate(format: "roomID == %@", roomID),
                    NSPredicate(
                        format: "accountEmail == %@",
                        Self.defaultRoomMessageAccount
                    )
                ]
            )
            guard try container.viewContext.fetch(existingRequest).isEmpty else {
                continue
            }

            let membershipRequest = NSFetchRequest<NSManagedObject>(
                entityName: Entity.roomMember
            )
            membershipRequest.predicate = NSPredicate(
                format: "roomID == %@",
                roomID
            )
            var senderEmails = try container.viewContext
                .fetch(membershipRequest)
                .map { $0.string("userEmail") }
                .filter { !$0.isEmpty }
                .shuffled()
            if senderEmails.isEmpty {
                senderEmails = [room.string("ownerEmail")]
            }

            let category = ZixyRoomCatalog.category(
                for: room.string("coverAssetName")
            )
            let categoryMessage: String
            switch category {
            case "Leatherwork":
                categoryMessage =
                    "I am practicing saddle stitching this week."
            case "Resin Art":
                categoryMessage =
                    "Has anyone tried a new color mix today?"
            default:
                categoryMessage =
                    "What inspired your latest creative project?"
            }
            let bodies = [
                "Welcome to \(room.string("title"))!",
                categoryMessage,
                "Share what you are making. We would love to see it."
            ]

            for (index, body) in bodies.enumerated() {
                let message = NSEntityDescription.insertNewObject(
                    forEntityName: Entity.roomMessage,
                    into: container.viewContext
                )
                message.setValue(
                    "zixy_default_room_message_\(UUID().uuidString)",
                    forKey: "id"
                )
                message.setValue(roomID, forKey: "roomID")
                message.setValue(
                    Self.defaultRoomMessageAccount,
                    forKey: "accountEmail"
                )
                message.setValue(
                    senderEmails[index % senderEmails.count],
                    forKey: "senderEmail"
                )
                message.setValue(
                    ZixyRoomMessageKind.text.rawValue,
                    forKey: "kind"
                )
                message.setValue(body, forKey: "body")
                message.setValue("", forKey: "mediaReference")
                message.setValue(Int64(0), forKey: "durationMilliseconds")
                message.setValue(
                    referenceDate.addingTimeInterval(
                        TimeInterval((index - bodies.count) * 180)
                    ),
                    forKey: "createdAt"
                )
            }
        }
    }

    private func removeDefaultRoomMessagesIfNeeded(
        roomID: String
    ) throws {
        guard !roomID.hasPrefix("zixy_seed_room_") else {
            return
        }
        let request = NSFetchRequest<NSManagedObject>(
            entityName: Entity.roomMessage
        )
        request.predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [
                NSPredicate(format: "roomID == %@", roomID),
                NSPredicate(
                    format: "accountEmail == %@",
                    Self.defaultRoomMessageAccount
                )
            ]
        )
        try container.viewContext.fetch(request)
            .forEach(container.viewContext.delete)
    }

    private func insertSeedMessages(between emails: [String]) {
        var offset: TimeInterval = -3_600
        for firstIndex in emails.indices {
            for secondIndex in emails.indices where secondIndex > firstIndex {
                let first = emails[firstIndex]
                let second = emails[secondIndex]
                let firstName = first.components(separatedBy: "@").first?.capitalized
                    ?? "Friend"
                insertMessage(
                    body: "Hi! I loved your latest handmade project.",
                    sender: first,
                    recipient: second,
                    date: Date().addingTimeInterval(offset)
                )
                offset += 60
                insertMessage(
                    body: "Thank you, \(firstName)! What are you making this week?",
                    sender: second,
                    recipient: first,
                    date: Date().addingTimeInterval(offset)
                )
                offset += 60
                insertMessage(
                    body: "I will share the details with you soon.",
                    sender: first,
                    recipient: second,
                    date: Date().addingTimeInterval(offset)
                )
                offset += 60
            }
        }
    }

    private func insertFollow(from follower: String, to followed: String) {
        let object = NSEntityDescription.insertNewObject(
            forEntityName: Entity.follow,
            into: container.viewContext
        )
        object.setValue(UUID().uuidString, forKey: "id")
        object.setValue(follower, forKey: "followerEmail")
        object.setValue(followed, forKey: "followedEmail")
    }

    private func removeFollowRelationships(
        between firstEmail: String,
        and secondEmail: String
    ) {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.follow)
        request.predicate = NSCompoundPredicate(
            orPredicateWithSubpredicates: [
                NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "followerEmail == %@", firstEmail),
                    NSPredicate(format: "followedEmail == %@", secondEmail)
                ]),
                NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "followerEmail == %@", secondEmail),
                    NSPredicate(format: "followedEmail == %@", firstEmail)
                ])
            ]
        )
        ((try? container.viewContext.fetch(request)) ?? [])
            .forEach(container.viewContext.delete)
    }

    private func removeRoomMemberships(
        between firstEmail: String,
        and secondEmail: String
    ) {
        let roomRequest = NSFetchRequest<NSManagedObject>(
            entityName: Entity.room
        )
        roomRequest.predicate = NSPredicate(
            format: "ownerEmail IN %@",
            [firstEmail, secondEmail]
        )
        let ownedRooms = (try? container.viewContext.fetch(roomRequest)) ?? []
        for room in ownedRooms {
            let ownerEmail = Self.normalizeEmail(
                room.string("ownerEmail")
            )
            let memberEmail = ownerEmail == firstEmail
                ? secondEmail
                : firstEmail
            let membershipRequest = NSFetchRequest<NSManagedObject>(
                entityName: Entity.roomMember
            )
            membershipRequest.predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [
                    NSPredicate(
                        format: "roomID == %@",
                        room.string("id")
                    ),
                    NSPredicate(
                        format: "userEmail == %@",
                        memberEmail
                    )
                ]
            )
            ((try? container.viewContext.fetch(membershipRequest)) ?? [])
                .forEach(container.viewContext.delete)
        }
    }

    private func restrictedUserEmails(for email: String) -> Set<String> {
        let normalizedEmail = Self.normalizeEmail(email)
        guard !normalizedEmail.isEmpty else {
            return []
        }
        let request = NSFetchRequest<NSManagedObject>(
            entityName: Entity.blacklist
        )
        request.predicate = NSCompoundPredicate(
            orPredicateWithSubpredicates: [
                NSPredicate(
                    format: "blockerEmail == %@",
                    normalizedEmail
                ),
                NSPredicate(
                    format: "blockedEmail == %@",
                    normalizedEmail
                )
            ]
        )
        return Set(
            ((try? container.viewContext.fetch(request)) ?? []).compactMap {
                let blockerEmail = Self.normalizeEmail(
                    $0.string("blockerEmail")
                )
                let blockedEmail = Self.normalizeEmail(
                    $0.string("blockedEmail")
                )
                return blockerEmail == normalizedEmail
                    ? blockedEmail
                    : blockerEmail
            }
        )
    }

    private func hasBlockingRelationship(
        between firstEmail: String,
        and secondEmail: String
    ) -> Bool {
        let first = Self.normalizeEmail(firstEmail)
        let second = Self.normalizeEmail(secondEmail)
        guard !first.isEmpty, !second.isEmpty else {
            return false
        }
        return restrictedUserEmails(for: first).contains(second)
    }

    private func roomRecord(
        _ room: ZixyRoomRecord,
        excluding restrictedEmails: Set<String>
    ) -> ZixyRoomRecord? {
        guard !restrictedEmails.contains(
            Self.normalizeEmail(room.owner.email)
        ) else {
            return nil
        }
        return ZixyRoomRecord(
            id: room.id,
            title: room.title,
            owner: room.owner,
            coverAssetName: room.coverAssetName,
            members: room.members.filter {
                !restrictedEmails.contains(
                    Self.normalizeEmail($0.email)
                )
            }
        )
    }

    private func insertMessage(
        body: String,
        sender: String,
        recipient: String,
        date: Date
    ) {
        let object = NSEntityDescription.insertNewObject(
            forEntityName: Entity.message,
            into: container.viewContext
        )
        object.setValue(UUID().uuidString, forKey: "id")
        object.setValue(sender, forKey: "senderEmail")
        object.setValue(recipient, forKey: "recipientEmail")
        object.setValue(body, forKey: "body")
        object.setValue(date, forKey: "createdAt")
    }

    private func relatedUsers(
        for email: String,
        relationKey: String,
        resultKey: String
    ) -> [ZixyUserRecord] {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.follow)
        request.predicate = NSPredicate(
            format: "%K == %@",
            relationKey,
            Self.normalizeEmail(email)
        )
        let emails = ((try? container.viewContext.fetch(request)) ?? [])
            .map { $0.string(resultKey) }
        return emails.compactMap { fetchUser(email: $0).map(makeUserRecord) }
            .sorted { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }
    }

    private func fetchUser(email: String) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.user)
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "email == %@",
            Self.normalizeEmail(email)
        )
        return try? container.viewContext.fetch(request).first
    }

    private func fetchPost(id: String) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: Entity.post)
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id)
        return try? container.viewContext.fetch(request).first
    }

    private func currentUserBlockedEmails() -> Set<String> {
        guard ZixySessionStore.isAuthenticated else {
            return []
        }
        return blockedUserEmails(
            for: ZixySessionStore.currentUserIdentifier
        )
    }

    private func storedComments(
        from post: NSManagedObject
    ) -> [ZixyStoredPostComment] {
        let value = post.string("comment")
        guard !value.isEmpty else {
            return []
        }
        if let data = value.data(using: .utf8),
           let comments = try? JSONDecoder().decode(
               [ZixyStoredPostComment].self,
               from: data
           ) {
            return comments
        }

        let userRequest = NSFetchRequest<NSManagedObject>(
            entityName: Entity.user
        )
        let postAuthorEmail = post.string("authorEmail")
        let fallbackAuthorEmail = ((try? container.viewContext.fetch(userRequest)) ?? [])
            .map { $0.string("email") }
            .first { $0 != postAuthorEmail }
            ?? postAuthorEmail
        return [
            ZixyStoredPostComment(
                id: "legacy_\(post.string("id"))",
                authorEmail: fallbackAuthorEmail,
                body: value,
                createdAt: Date(timeIntervalSince1970: 1_742_534_040)
            )
        ]
    }

    private func makeUserRecord(from object: NSManagedObject) -> ZixyUserRecord {
        ZixyUserRecord(
            username: object.string("username"),
            email: object.string("email"),
            bio: object.string("bio"),
            avatarAssetName: object.string("avatarAssetName")
        )
    }

    private func makePostRecord(
        from object: NSManagedObject
    ) -> ZixyPostRecord? {
        guard
            let author = fetchUser(email: object.string("authorEmail"))
                .map(makeUserRecord)
        else {
            return nil
        }
        return ZixyPostRecord(
            id: object.string("id"),
            author: author,
            title: object.string("title"),
            body: object.string("body"),
            primaryMediaName: object.string("primaryMediaName"),
            secondaryImageName: object.string("secondaryImageName"),
            comment: object.string("comment"),
            likeCount: Int(object.int64("likeCount")),
            commentCount: storedComments(from: object).filter {
                !currentUserBlockedEmails().contains(
                    Self.normalizeEmail($0.authorEmail)
                )
            }.count,
            isLikedByCurrentUser: Set(
                object.string("likedBy")
                    .split(separator: "|")
                    .map(String.init)
            ).contains(
                Self.normalizeEmail(ZixySessionStore.currentUserIdentifier)
            ),
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
        )
    }

    private func makeRoomRecord(from object: NSManagedObject) -> ZixyRoomRecord? {
        let roomID = object.string("id")
        guard
            let owner = fetchUser(email: object.string("ownerEmail"))
                .map(makeUserRecord)
        else {
            return nil
        }
        let memberRequest = NSFetchRequest<NSManagedObject>(
            entityName: Entity.roomMember
        )
        memberRequest.predicate = NSPredicate(format: "roomID == %@", roomID)
        let members = ((try? container.viewContext.fetch(memberRequest)) ?? [])
            .compactMap { fetchUser(email: $0.string("userEmail")) }
            .map(makeUserRecord)
            .sorted {
                if $0.email == owner.email {
                    return true
                }
                if $1.email == owner.email {
                    return false
                }
                return $0.username.localizedCaseInsensitiveCompare($1.username)
                    == .orderedAscending
            }
        return ZixyRoomRecord(
            id: roomID,
            title: object.string("title"),
            owner: owner,
            coverAssetName: object.string("coverAssetName"),
            members: members
        )
    }

    private func makeRoomMessageRecord(
        from object: NSManagedObject
    ) -> ZixyRoomMessageRecord? {
        guard
            let kind = ZixyRoomMessageKind(
                rawValue: object.string("kind")
            )
        else {
            return nil
        }
        return ZixyRoomMessageRecord(
            id: object.string("id"),
            roomID: object.string("roomID"),
            accountEmail: object.string("accountEmail"),
            senderEmail: object.string("senderEmail"),
            kind: kind,
            body: object.string("body"),
            mediaReference: object.string("mediaReference"),
            duration: TimeInterval(
                object.int64("durationMilliseconds")
            ) / 1_000,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
        )
    }

    private static let seedRows = [
        SeedRow(
            username: "Elena",
            avatar: "11.jpg",
            bio: "Handmaking leather goods in Munich 🧵 | Minimalist designs & natural tan.",
            title: "Card Holder DIY",
            caption: "A super easy card holder made from cowhide scraps",
            primaryMedia: "redpandacompress_download.mp4",
            secondaryImage: "",
            comment: ""
        ),
        SeedRow(
            username: "Weber",
            avatar: "13.jpg",
            bio: "knitwear & cozy vibes",
            title: "Cozy Knitting Time",
            caption: "Watch me finish my scarf as I listen to my audiobook",
            primaryMedia: "download (2).mp4",
            secondaryImage: "",
            comment: ""
        ),
        SeedRow(
            username: "Sophie",
            avatar: "9.jpg",
            bio: "Pressing wildflowers & preserving them in epoxy.",
            title: "Wildflower Resin Art",
            caption: "I sealed a whole wildflower meadow inside resin! 🌼✨ These floral-embedded table tops and acrylic chairs turn my dining room into a sunlit spring garden. Every single flower is perfectly preserved under the clear surface.",
            primaryMedia: "redpandacompress_TikVideoApp_7663108815562280206-hd.mp4",
            secondaryImage: "",
            comment: "Love it…."
        ),
        SeedRow(
            username: "Mateo",
            avatar: "8.jpg",
            bio: "Pottery addict in Florence 🏺 | Making coffee mugs for everyday joy.",
            title: "Gift For Grand-Mère",
            caption: "Made a candlestick for my Grand-Mére, hope she likes it",
            primaryMedia: "redpandacompress_download (1) (1).mp4",
            secondaryImage: "",
            comment: "I love pottery"
        ),
        SeedRow(
            username: "Ania",
            avatar: "12.jpg",
            bio: "Silver smithing & gemstone setter from Warsaw",
            title: "Daily Energy Recharge",
            caption: "Daily energy recharge! 🔋 Found some amazing purple treasures today and now taking it easy at home. Slowly but surely.",
            primaryMedia: "a244d6f7162b41a9e6c64952b48832b1.jpg",
            secondaryImage: "bfa0deee76fa5fb390b20865a48dba49.jpg",
            comment: ""
        ),
        SeedRow(
            username: "Judy",
            avatar: "1.jpg",
            bio: "Turning fallen trees into spoons & bowls. Vienna based 🪵",
            title: "Handcrafted Wooden Spoons",
            caption: "I made spoons out of the trees I cut down from abandoned house!",
            primaryMedia: "redpandacompress_download (1).mp4",
            secondaryImage: "",
            comment: ""
        )
    ]

    private static func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func passwordHash(_ password: String) -> String {
        SHA256.hash(data: Data(password.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func publishedTimestamp(from id: String) -> Int64? {
        guard id.hasPrefix("published_") else {
            return nil
        }
        return Int64(id.split(separator: "_").dropFirst().first ?? "")
    }

    private static func randomDateWithinPreviousDay(
        referenceDate: Date
    ) -> Date {
        referenceDate.addingTimeInterval(
            -TimeInterval.random(in: 0..<(24 * 60 * 60))
        )
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let user = makeEntity(
            name: Entity.user,
            attributes: [
                stringAttribute("id"),
                stringAttribute("username"),
                stringAttribute("email"),
                stringAttribute("passwordHash"),
                stringAttribute("bio"),
                stringAttribute("avatarAssetName")
            ],
            uniqueKeys: ["email"]
        )
        let post = makeEntity(
            name: Entity.post,
            attributes: [
                stringAttribute("id"),
                stringAttribute("authorEmail"),
                stringAttribute("title"),
                stringAttribute("body"),
                stringAttribute("primaryMediaName"),
                stringAttribute("secondaryImageName", optional: true),
                stringAttribute("comment", optional: true),
                integer64Attribute("likeCount", optional: true),
                stringAttribute("likedBy", optional: true),
                dateAttribute("createdAt", optional: true)
            ],
            uniqueKeys: ["id"]
        )
        let follow = makeEntity(
            name: Entity.follow,
            attributes: [
                stringAttribute("id"),
                stringAttribute("followerEmail"),
                stringAttribute("followedEmail")
            ],
            uniqueKeys: ["id"]
        )
        let message = makeEntity(
            name: Entity.message,
            attributes: [
                stringAttribute("id"),
                stringAttribute("senderEmail"),
                stringAttribute("recipientEmail"),
                stringAttribute("body"),
                dateAttribute("createdAt")
            ],
            uniqueKeys: ["id"]
        )
        let room = makeEntity(
            name: Entity.room,
            attributes: [
                stringAttribute("id"),
                stringAttribute("title"),
                stringAttribute("ownerEmail"),
                stringAttribute("coverAssetName"),
                dateAttribute("createdAt")
            ],
            uniqueKeys: ["id"]
        )
        let roomMember = makeEntity(
            name: Entity.roomMember,
            attributes: [
                stringAttribute("id"),
                stringAttribute("roomID"),
                stringAttribute("userEmail")
            ],
            uniqueKeys: ["id"]
        )
        let roomMessage = makeEntity(
            name: Entity.roomMessage,
            attributes: [
                stringAttribute("id"),
                stringAttribute("roomID"),
                stringAttribute("accountEmail"),
                stringAttribute("senderEmail"),
                stringAttribute("kind"),
                stringAttribute("body", optional: true),
                stringAttribute("mediaReference", optional: true),
                integer64Attribute("durationMilliseconds", optional: true),
                dateAttribute("createdAt")
            ],
            uniqueKeys: ["id"]
        )
        let blacklist = makeEntity(
            name: Entity.blacklist,
            attributes: [
                stringAttribute("id"),
                stringAttribute("blockerEmail"),
                stringAttribute("blockedEmail")
            ],
            uniqueKeys: ["blockerEmail", "blockedEmail"]
        )
        model.entities = [
            user,
            post,
            follow,
            message,
            room,
            roomMember,
            roomMessage,
            blacklist
        ]
        return model
    }

    private static func makeEntity(
        name: String,
        attributes: [NSAttributeDescription],
        uniqueKeys: [String]
    ) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        entity.properties = attributes
        entity.uniquenessConstraints = [uniqueKeys]
        return entity
    }

    private static func stringAttribute(
        _ name: String,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .stringAttributeType
        attribute.isOptional = optional
        return attribute
    }

    private static func dateAttribute(
        _ name: String,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .dateAttributeType
        attribute.isOptional = optional
        return attribute
    }

    private static func integer64Attribute(
        _ name: String,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .integer64AttributeType
        attribute.isOptional = optional
        return attribute
    }
}

private struct SeedRow {
    let username: String
    let avatar: String
    let bio: String
    let title: String
    let caption: String
    let primaryMedia: String
    let secondaryImage: String
    let comment: String
}

private extension NSManagedObject {

    func string(_ key: String) -> String {
        value(forKey: key) as? String ?? ""
    }

    func int64(_ key: String) -> Int64 {
        (value(forKey: key) as? NSNumber)?.int64Value ?? 0
    }
}
