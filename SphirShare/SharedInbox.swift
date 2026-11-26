//
//  SharedInbox.swift
//  Sphir + SphirShare
//
//  App Group–backed bridge between the main app and the share extension.
//  The main app publishes its collections here so the extension can populate
//  its picker; the extension enqueues captured cards here so the main app can
//  import them on next launch.
//
//  This file exists twice, byte for byte: Sphir/State/SharedInbox.swift (app
//  target) and SphirShare/SharedInbox.swift (extension target). The targets
//  are separate binaries, so each compiles its own copy. Keep them identical.
//

import Foundation

/// A lightweight, Codable snapshot of a collection for the App Group.
struct SharedCollectionDTO: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    /// The folder's id on the API (nil until the collection has synced, and for
    /// snapshots published by an older build).
    let serverID: String?

    init(id: UUID, name: String, serverID: String? = nil) {
        self.id = id
        self.name = name
        self.serverID = serverID
    }
}

/// A card captured by a share extension, awaiting import by the main app.
struct SharedCardDTO: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let urlString: String
    /// Body text for non-URL shares (Mail/Messages).
    let bodyText: String
    let imageData: Data?
    /// SourceApp rawValue ("safari", "mail", "messages", …).
    let sourceAppRaw: String
    let collectionID: UUID?
    let createdAt: Date
    /// Tags chosen in the share sheet. Optional so cards queued by an older
    /// build still decode.
    let tags: [String]?
    /// CardType rawValue of a queued clip ("product", "video", …). Optional so
    /// cards queued by an older build still decode (they import as plain text).
    let cardTypeRaw: String?
    /// Display price of a queued clip (e.g. "$29.99").
    let price: String?
    /// Site name and publication date (YYYY-MM-DD) of a queued clip.
    let site: String?
    let published: String?
    /// Cover image URL of a queued clip.
    let imageURL: String?

    init(
        id: UUID,
        title: String,
        description: String = "",
        urlString: String = "",
        bodyText: String = "",
        imageData: Data? = nil,
        sourceAppRaw: String = "safari",
        collectionID: UUID?,
        createdAt: Date,
        tags: [String]? = nil,
        cardTypeRaw: String? = nil,
        price: String? = nil,
        site: String? = nil,
        published: String? = nil,
        imageURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.urlString = urlString
        self.bodyText = bodyText
        self.imageData = imageData
        self.sourceAppRaw = sourceAppRaw
        self.collectionID = collectionID
        self.createdAt = createdAt
        self.tags = tags
        self.cardTypeRaw = cardTypeRaw
        self.price = price
        self.site = site
        self.published = published
        self.imageURL = imageURL
    }
}

/// Read/write access to the shared App Group container.
enum SharedInbox {
    static let appGroupID = "group.com.sphir.shared"

    private static let collectionsKey = "shared.collections"
    private static let pendingCardsKey = "shared.pendingCards"
    private static let lastCollectionKey = "shared.lastClipCollection"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Collections (published by the main app)

    static func saveCollections(_ collections: [SharedCollectionDTO]) {
        guard let data = try? JSONEncoder().encode(collections) else { return }
        defaults?.set(data, forKey: collectionsKey)
    }

    static func loadCollections() -> [SharedCollectionDTO] {
        guard let data = defaults?.data(forKey: collectionsKey),
              let decoded = try? JSONDecoder().decode([SharedCollectionDTO].self, from: data)
        else { return [] }
        return decoded
    }

    // MARK: - Last collection used by the extension

    /// Server folder id (or collection UUID string when offline) of the last
    /// collection a clip was saved to; preselected on the next clip.
    static var lastClipCollection: String? {
        get { defaults?.string(forKey: lastCollectionKey) }
        set { defaults?.set(newValue, forKey: lastCollectionKey) }
    }

    // MARK: - Pending cards (enqueued by extensions)

    static func enqueueCard(_ card: SharedCardDTO) {
        var pending = loadPendingCards()
        pending.append(card)
        guard let data = try? JSONEncoder().encode(pending) else { return }
        defaults?.set(data, forKey: pendingCardsKey)
    }

    static func updateCollection(forCardID id: UUID, newCollectionID: UUID?) {
        var pending = loadPendingCards()
        if let idx = pending.firstIndex(where: { $0.id == id }) {
            let old = pending[idx]
            let updated = SharedCardDTO(
                id: old.id,
                title: old.title,
                description: old.description,
                urlString: old.urlString,
                bodyText: old.bodyText,
                imageData: old.imageData,
                sourceAppRaw: old.sourceAppRaw,
                collectionID: newCollectionID,
                createdAt: old.createdAt,
                tags: old.tags,
                cardTypeRaw: old.cardTypeRaw,
                price: old.price,
                site: old.site,
                published: old.published,
                imageURL: old.imageURL
            )
            pending[idx] = updated
            guard let data = try? JSONEncoder().encode(pending) else { return }
            defaults?.set(data, forKey: pendingCardsKey)
        }
    }

    static func loadPendingCards() -> [SharedCardDTO] {
        guard let data = defaults?.data(forKey: pendingCardsKey),
              let decoded = try? JSONDecoder().decode([SharedCardDTO].self, from: data)
        else { return [] }
        return decoded
    }

    static func clearPendingCards() {
        defaults?.removeObject(forKey: pendingCardsKey)
    }

    // MARK: - Fallback

    /// Default collections used by an extension before the app has ever
    /// published its real collections. Fixed IDs so repeat runs are stable.
    static let fallbackCollections: [SharedCollectionDTO] = [
        SharedCollectionDTO(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Reading List"),
        SharedCollectionDTO(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Inspiration"),
        SharedCollectionDTO(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Work Assets"),
        SharedCollectionDTO(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, name: "Mood Board")
    ]
}
