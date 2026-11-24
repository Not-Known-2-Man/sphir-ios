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
        tags: [String]? = nil
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
                tags: old.tags
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
