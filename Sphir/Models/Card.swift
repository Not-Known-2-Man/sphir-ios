//
//  Card.swift
//  Sphir
//
//  Mock data model representing a captured content card.
//

import Foundation

/// The kind of content a card holds.
enum CardType: String, CaseIterable, Codable {
    case text
    case media
    case business
    case product
    case originalScribe
}

/// The app a card was captured from.
enum SourceApp: String, CaseIterable, Codable {
    case safari
    case mail
    case messages
    case photos
    case screenshot
}

/// Sync state of a card relative to the backend.
enum SyncStatus: String, CaseIterable, Codable {
    case synced
    case syncing
    case offline
}

/// A single captured piece of content.
struct Card: Identifiable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var content: String
    var cardType: CardType
    var sourceApp: SourceApp
    var imageURL: String?
    /// Thumbnail image bytes fetched from link metadata, if any.
    var imageData: Data?
    var tags: [String]
    var syncStatus: SyncStatus
    var createdAt: Date
    /// The collection this card belongs to.
    var collectionID: UUID?
    /// The card's id on the backend (nil until synced).
    var serverID: String?

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        content: String = "",
        cardType: CardType = .text,
        sourceApp: SourceApp = .safari,
        imageURL: String? = nil,
        imageData: Data? = nil,
        tags: [String] = [],
        syncStatus: SyncStatus = .synced,
        createdAt: Date = Date(),
        collectionID: UUID? = nil,
        serverID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.content = content
        self.cardType = cardType
        self.sourceApp = sourceApp
        self.imageURL = imageURL
        self.imageData = imageData
        self.tags = tags
        self.syncStatus = syncStatus
        self.createdAt = createdAt
        self.collectionID = collectionID
        self.serverID = serverID
    }
}

extension CardType {
    /// Emoji shown at the leading edge of the option row.
    var emoji: String {
        switch self {
        case .text:           return "📝"
        case .media:          return "🎬"
        case .business:       return "💼"
        case .product:        return "📦"
        case .originalScribe: return "✍️"
        }
    }

    var title: String {
        switch self {
        case .text:           return "Text"
        case .media:          return "Media"
        case .business:       return "Business"
        case .product:        return "Product"
        case .originalScribe: return "Original Scribe"
        }
    }

    var subtitle: String {
        switch self {
        case .text:           return "Articles, blogs, documents"
        case .media:          return "Videos, audio, images"
        case .business:       return "Contacts, companies"
        case .product:        return "Items, services"
        case .originalScribe: return "Your own content"
        }
    }

    /// SF Symbol representing the card type.
    var iconName: String {
        switch self {
        case .text:           return "doc.text"
        case .media:          return "play.rectangle"
        case .business:       return "briefcase"
        case .product:        return "shippingbox"
        case .originalScribe: return "pencil.and.outline"
        }
    }
}

extension SourceApp {
    var label: String {
        switch self {
        case .safari:     return "Safari"
        case .mail:       return "Mail"
        case .messages:   return "Messages"
        case .photos:     return "Photos"
        case .screenshot: return "Screenshot"
        }
    }

    /// SF Symbol representing the source app.
    var iconName: String {
        switch self {
        case .safari:     return "safari"
        case .mail:       return "envelope"
        case .messages:   return "message"
        case .photos:     return "photo"
        case .screenshot: return "camera.viewfinder"
        }
    }
}

extension SyncStatus {
    var label: String {
        switch self {
        case .synced:  return "Synced"
        case .syncing: return "Syncing"
        case .offline: return "Offline"
        }
    }

    /// SF Symbol representing the sync state.
    var iconName: String {
        switch self {
        case .synced:  return "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .offline: return "wifi.slash"
        }
    }
}

extension Card {
    /// Four deterministic template cards used as seed content for a collection.
    static func samples(for collection: Collection) -> [Card] {
        let id = collection.id
        return [
            Card(
                title: "\(collection.name): Getting Started",
                description: "An overview to kick things off.",
                content: "A longer body of text that would normally hold the captured article contents, notes, or transcript for this card.",
                cardType: .text,
                sourceApp: .safari,
                tags: ["guide", "intro"],
                syncStatus: .synced,
                createdAt: Date(timeIntervalSince1970: 1_710_000_000),
                collectionID: id
            ),
            Card(
                title: "Highlights Reel",
                description: "A saved media clip worth revisiting.",
                content: "Media card content placeholder.",
                cardType: .media,
                sourceApp: .photos,
                tags: ["video", "inspo"],
                syncStatus: .syncing,
                createdAt: Date(timeIntervalSince1970: 1_712_500_000),
                collectionID: id
            ),
            Card(
                title: "Key Contact",
                description: "An important person to remember.",
                content: "Contact details and notes.",
                cardType: .business,
                sourceApp: .messages,
                tags: ["people"],
                syncStatus: .synced,
                createdAt: Date(timeIntervalSince1970: 1_714_000_000),
                collectionID: id
            ),
            Card(
                title: "Wishlist Item",
                description: "Something to circle back to later.",
                content: "Product details and price notes.",
                cardType: .product,
                sourceApp: .mail,
                tags: ["shopping", "later"],
                syncStatus: .offline,
                createdAt: Date(timeIntervalSince1970: 1_715_200_000),
                collectionID: id
            )
        ]
    }

    /// Seed `count` cards for a collection by cycling the sample templates,
    /// so the collection's stored count matches its real card membership.
    static func seededCards(for collection: Collection) -> [Card] {
        guard collection.cardCount > 0 else { return [] }
        let templates = samples(for: collection)
        return (0..<collection.cardCount).map { index in
            var card = templates[index % templates.count]
            // Give repeated templates distinct identities and titles.
            if index >= templates.count {
                card = Card(
                    title: "\(card.title) #\(index + 1)",
                    description: card.description,
                    content: card.content,
                    cardType: card.cardType,
                    sourceApp: card.sourceApp,
                    tags: card.tags,
                    syncStatus: card.syncStatus,
                    createdAt: card.createdAt,
                    collectionID: collection.id
                )
            }
            return card
        }
    }
}
