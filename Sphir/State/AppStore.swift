//
//  AppStore.swift
//  Sphir
//
//  CoreData-backed repository for collections and cards. Views observe the
//  published struct projections; every mutation writes to CoreData, saves,
//  and refreshes the projections so state survives relaunches.
//

import SwiftUI
import CoreData
import Combine

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var collections: [Collection] = []
    @Published private(set) var cards: [Card] = []
    /// Set when an operation fails; views present it as an alert.
    @Published var errorMessage: String?

    private let context: NSManagedObjectContext

    init(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        seedIfEmpty: Bool = true
    ) {
        self.context = context
        if seedIfEmpty { seedIfNeeded() }
        importPendingSharedCards()
        reload()
        publishCollectionsToSharedInbox()
    }

    // MARK: - Queries

    /// Cards belonging to a given collection, newest first.
    func cards(in collectionID: UUID) -> [Card] {
        cards
            .filter { $0.collectionID == collectionID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Mutations

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

        let card = Card(
            title: title,
            description: description,
            content: source == .url ? urlText : "",
            cardType: type,
            sourceApp: source.mappedSourceApp,
            imageData: imageData,
            tags: tags,
            collectionID: resolveCollectionID(collectionID)
        )
        insert(card)
        save()
        reload()
        return card
    }

    @discardableResult
    func addScreenshotCard(title: String, content: String, imageData: Data?, collectionID: UUID? = nil) -> Card {
        addImageCard(
            title: title.isEmpty ? "Screenshot" : title,
            content: content,
            imageData: imageData,
            sourceApp: .screenshot,
            collectionID: collectionID
        )
    }

    @discardableResult
    func addPhotoCard(title: String, content: String, imageData: Data?, collectionID: UUID? = nil) -> Card {
        addImageCard(
            title: title.isEmpty ? "Photo" : title,
            content: content,
            imageData: imageData,
            sourceApp: .photos,
            collectionID: collectionID
        )
    }

    @discardableResult
    private func addImageCard(
        title: String,
        content: String,
        imageData: Data?,
        sourceApp: SourceApp,
        collectionID: UUID?
    ) -> Card {
        let card = Card(
            title: title,
            content: content,
            cardType: .text,
            sourceApp: sourceApp,
            imageData: imageData,
            collectionID: resolveCollectionID(collectionID)
        )
        insert(card)
        save()
        reload()
        return card
    }

    /// Update the editable fields of an existing card.
    func updateCard(_ card: Card) {
        guard let object = cdCard(id: card.id) else { return }
        object.setValue(card.title, forKey: "title")
        object.setValue(card.description, forKey: "cardDescription")
        object.setValue(card.content, forKey: "content")
        object.setValue(encodeTags(card.tags), forKey: "tagsJSON")
        save()
        reload()
    }

    func deleteCard(id: UUID) {
        guard let object = cdCard(id: id) else { return }
        context.delete(object)
        save()
        reload()
    }

    @discardableResult
    func addCollection(name: String, description: String = "", privacy: CollectionPrivacy) -> Collection {
        let collection = Collection(name: name, description: description, cardCount: 0, privacy: privacy)
        insert(collection)
        save()
        reload()
        publishCollectionsToSharedInbox()
        return collection
    }

    // MARK: - Share Extension Bridge

    func publishCollectionsToSharedInbox() {
        SharedInbox.saveCollections(
            collections.map { SharedCollectionDTO(id: $0.id, name: $0.name) }
        )
    }

    func importPendingSharedCards() {
        let pending = SharedInbox.loadPendingCards()
        guard !pending.isEmpty else { return }

        for dto in pending {
            let isLink = !dto.urlString.isEmpty
            let title = dto.title.isEmpty ? (isLink ? "Shared Link" : "Shared Text") : dto.title
            let card = Card(
                title: title,
                description: dto.description,
                content: isLink ? dto.urlString : dto.bodyText,
                cardType: .text,
                sourceApp: SourceApp(rawValue: dto.sourceAppRaw) ?? .safari,
                imageData: dto.imageData,
                collectionID: resolveCollectionID(dto.collectionID)
            )
            insert(card)
        }
        SharedInbox.clearPendingCards()
        save()
        reload()
    }

    // MARK: - Seeding

    private func seedIfNeeded() {
        guard fetchCollections().isEmpty else { return }
        for mock in Collection.mockCollections {
            insert(mock)
            for card in Card.seededCards(for: mock) {
                insert(card)
            }
        }
        save()
    }

    // MARK: - CoreData helpers

    private func resolveCollectionID(_ id: UUID?) -> UUID? {
        let collections = fetchCollections()
        if let id, collections.contains(where: { ($0.value(forKey: "id") as? UUID) == id }) {
            return id
        }
        return collections.first?.value(forKey: "id") as? UUID
    }

    private func fetchCollections() -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCollection")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    private func fetchCards() -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCard")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    private func cdCard(id: UUID) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCard")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    private func insert(_ collection: Collection) {
        let object = NSEntityDescription.insertNewObject(forEntityName: "CDCollection", into: context)
        object.setValue(collection.id, forKey: "id")
        object.setValue(collection.name, forKey: "name")
        object.setValue(collection.description, forKey: "collectionDescription")
        object.setValue(collection.privacy.rawValue, forKey: "privacy")
        object.setValue(collection.createdAt, forKey: "createdAt")
    }

    private func insert(_ card: Card) {
        let object = NSEntityDescription.insertNewObject(forEntityName: "CDCard", into: context)
        object.setValue(card.id, forKey: "id")
        object.setValue(card.title, forKey: "title")
        object.setValue(card.description, forKey: "cardDescription")
        object.setValue(card.content, forKey: "content")
        object.setValue(card.cardType.rawValue, forKey: "cardType")
        object.setValue(card.sourceApp.rawValue, forKey: "sourceApp")
        object.setValue(card.imageURL, forKey: "imageURL")
        object.setValue(card.imageData, forKey: "imageData")
        object.setValue(encodeTags(card.tags), forKey: "tagsJSON")
        object.setValue(card.syncStatus.rawValue, forKey: "syncStatus")
        object.setValue(card.createdAt, forKey: "createdAt")
        object.setValue(card.collectionID, forKey: "collectionID")
    }

    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Sphir CoreData save failed: \(error)")
            errorMessage = "Couldn't save your changes. Please try again."
        }
    }

    /// Rebuild the published projections from CoreData.
    private func reload() {
        let cardObjects = fetchCards()
        let mappedCards = cardObjects.map(card(from:))
        self.cards = mappedCards

        var countByCollection: [UUID: Int] = [:]
        for card in mappedCards {
            if let cid = card.collectionID {
                countByCollection[cid, default: 0] += 1
            }
        }

        self.collections = fetchCollections().map { object in
            let id = object.value(forKey: "id") as? UUID ?? UUID()
            return Collection(
                id: id,
                name: object.value(forKey: "name") as? String ?? "",
                description: object.value(forKey: "collectionDescription") as? String ?? "",
                cardCount: countByCollection[id] ?? 0,
                privacy: CollectionPrivacy(rawValue: object.value(forKey: "privacy") as? String ?? "") ?? .private,
                createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
            )
        }
    }

    private func card(from object: NSManagedObject) -> Card {
        Card(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            title: object.value(forKey: "title") as? String ?? "",
            description: object.value(forKey: "cardDescription") as? String ?? "",
            content: object.value(forKey: "content") as? String ?? "",
            cardType: CardType(rawValue: object.value(forKey: "cardType") as? String ?? "") ?? .text,
            sourceApp: SourceApp(rawValue: object.value(forKey: "sourceApp") as? String ?? "") ?? .safari,
            imageURL: object.value(forKey: "imageURL") as? String,
            imageData: object.value(forKey: "imageData") as? Data,
            tags: decodeTags(object.value(forKey: "tagsJSON") as? String),
            syncStatus: SyncStatus(rawValue: object.value(forKey: "syncStatus") as? String ?? "") ?? .synced,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            collectionID: object.value(forKey: "collectionID") as? UUID
        )
    }

    private func encodeTags(_ tags: [String]) -> String {
        guard let data = try? JSONEncoder().encode(tags),
              let string = String(data: data, encoding: .utf8) else { return "[]" }
        return string
    }

    private func decodeTags(_ json: String?) -> [String] {
        guard let json, let data = json.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return tags
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
