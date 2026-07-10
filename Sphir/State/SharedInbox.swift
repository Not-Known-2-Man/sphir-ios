//
//  SharedInbox.swift
//  Sphir + SphirShare
//
//  App Group–backed bridge between the main app and the share extensions.
//  The main app publishes its collections here so extensions can populate
//  their pickers; extensions enqueue captured cards here so the main app
//  can import them on next launch.
//
//  NOTE: This file must also be added to the SphirShare extension target
//  (Target Membership) so both processes share the same storage code.
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
    let urlString: String
    let collectionID: UUID?
    let createdAt: Date
}

/// Read/write access to the shared App Group container.
enum SharedInbox {
    static let appGroupID = "group.com.sphir.shared"

    private static let collectionsKey = "shared.collections"
    private static let pendingCardsKey = "shared.pendingCards"

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

    // MARK: - Pending cards (enqueued by extensions)

    static func enqueueCard(_ card: SharedCardDTO) {
        var pending = loadPendingCards()
        pending.append(card)
        guard let data = try? JSONEncoder().encode(pending) else { return }
        defaults?.set(data, forKey: pendingCardsKey)
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
