//
//  AppStore.swift
//  Sphir
//
//  In-memory app state shared across the dashboard and creation flows.
//  Backed by mock data for now; swap the storage for CoreData later
//  without changing the view layer.
//

import SwiftUI
import Combine

@MainActor
final class AppStore: ObservableObject {
    @Published var collections: [Collection]
    @Published var cards: [Card]

    init(
        collections: [Collection] = Collection.mockCollections,
        cards: [Card]? = nil
    ) {
        self.collections = collections
        // Seed each collection with real card objects so membership and
        // counts are consistent from launch.
        self.cards = cards ?? collections.flatMap { Card.seededCards(for: $0) }

        // Bridge with the share extensions via the App Group.
        importPendingSharedCards()
        publishCollectionsToSharedInbox()
    }

    // MARK: - Share Extension Bridge

    /// Publish current collections so share extensions can populate pickers.
    func publishCollectionsToSharedInbox() {
        SharedInbox.saveCollections(
            collections.map { SharedCollectionDTO(id: $0.id, name: $0.name) }
        )
    }

    /// Import any cards captured by a share extension since last launch.
    func importPendingSharedCards() {
        let pending = SharedInbox.loadPendingCards()
        guard !pending.isEmpty else { return }

        for dto in pending {
            let isLink = !dto.urlString.isEmpty
            let title = dto.title.isEmpty ? (isLink ? "Shared Link" : "Shared Text") : dto.title

            guard let index = resolveTargetIndex(dto.collectionID) else { continue }

            let card = Card(
                title: title,
                description: dto.description,
                content: isLink ? dto.urlString : dto.bodyText,
                cardType: .text,
                sourceApp: SourceApp(rawValue: dto.sourceAppRaw) ?? .safari,
                imageData: dto.imageData,
                collectionID: collections[index].id
            )
            cards.append(card)
            collections[index].cardCount += 1
        }
        SharedInbox.clearPendingCards()
    }

    /// The index of the requested collection, else the first one.
    private func resolveTargetIndex(_ collectionID: UUID?) -> Int? {
        if let collectionID, let idx = collections.firstIndex(where: { $0.id == collectionID }) {
            return idx
        }
        return collections.indices.first
    }

    /// Cards belonging to a given collection, newest first.
    func cards(in collectionID: UUID) -> [Card] {
        cards
            .filter { $0.collectionID == collectionID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Create a card from the "+Card" flow and file it into a collection.
    /// Returns the created card. Defaults to the first collection when none
    /// is specified.
    @discardableResult
    func addCard(
        title: String,
        description: String,
        urlText: String,
        tagsText: String,
        type: CardType,
        source: CardSource,
        collectionID: UUID? = nil,
        imageData: Data? = nil
    ) -> Card {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Resolve the destination collection (requested, else the first one).
        let targetIndex = resolveTargetIndex(collectionID)
        let targetID = targetIndex.map { collections[$0].id }

        let card = Card(
            title: title,
            description: description,
            content: source == .url ? urlText : "",
            cardType: type,
            sourceApp: source.mappedSourceApp,
            imageData: imageData,
            tags: tags,
            collectionID: targetID
        )

        cards.append(card)

        if let index = targetIndex {
            collections[index].cardCount += 1
        }

        return card
    }

    /// Create a new collection from the "+Collection" flow.
    @discardableResult
    func addCollection(
        name: String,
        description: String = "",
        privacy: CollectionPrivacy
    ) -> Collection {
        let collection = Collection(
            name: name,
            description: description,
            cardCount: 0,
            privacy: privacy
        )
        collections.append(collection)
        publishCollectionsToSharedInbox()
        return collection
    }
}

extension CardSource {
    /// Best-effort mapping from a capture method to a stored provenance value.
    var mappedSourceApp: SourceApp {
        switch self {
        case .photos:      return .photos
        case .camera:      return .photos
        case .url:         return .safari
        case .screenshots: return .screenshot
        }
    }
}
