//
//  Collection.swift
//  Sphir
//
//  Mock data model representing a user collection of cards.
//

import Foundation

/// Visibility level of a collection.
enum CollectionPrivacy: String, CaseIterable, Codable {
    case `private`
    case connections
    case `public`

    /// Human-readable label for display in badges.
    var label: String {
        switch self {
        case .private:     return "Private"
        case .connections: return "Connections"
        case .public:      return "Public"
        }
    }

    /// SF Symbol representing the privacy level.
    var iconName: String {
        switch self {
        case .private:     return "lock.fill"
        case .connections: return "person.2.fill"
        case .public:      return "globe"
        }
    }
}

/// A named grouping of cards.
struct Collection: Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var cardCount: Int
    var privacy: CollectionPrivacy
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        cardCount: Int,
        privacy: CollectionPrivacy = .private,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.cardCount = cardCount
        self.privacy = privacy
        self.createdAt = createdAt
    }
}

extension Collection {
    /// Mock collections used to populate the dashboard until a backend exists.
    static let mockCollections: [Collection] = [
        Collection(name: "Reading List", description: "Articles and posts saved for later.", cardCount: 12),
        Collection(name: "Inspiration", description: "Ideas, references, and things that spark joy.", cardCount: 34),
        Collection(name: "Work Assets", description: "Docs and resources for current projects.", cardCount: 8, privacy: .connections),
        Collection(name: "Mood Board", description: "Visual direction and aesthetic notes.", cardCount: 21, privacy: .public)
    ]
}
