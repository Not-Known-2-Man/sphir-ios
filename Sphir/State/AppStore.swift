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
    /// Timestamp of the last successful API sync (drives the 5-min refresh).
    private var lastSyncedAt: Date?

    /// Network seams (default to the real API services) so tests can hold a
    /// request in flight without touching the network.
    typealias FolderCreator = (_ name: String, _ description: String, _ privacy: String) async throws -> Collection
    typealias CardCreator = (_ card: Card, _ folderServerID: String?) async throws -> Card
    private let createFolder: FolderCreator
    private let createCard: CardCreator
    private let hasCredentials: () -> Bool
    typealias FolderFetcher = () async throws -> [Collection]
    typealias CardFetcher = () async throws -> [BusinessDTO]
    private let fetchFolders: FolderFetcher
    private let fetchRemoteCards: CardFetcher
    /// Collection creates still in flight (local id -> resulting folder id), so a
    /// card added meanwhile can wait for its folder. Entries are removed when done.
    private var pendingFolderCreates: [UUID: Task<String?, Never>] = [:]

    init(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        seedIfEmpty: Bool = true,
        createFolder: @escaping FolderCreator = { name, description, privacy in
            try await CollectionAPIService.createCollection(name: name, description: description, privacy: privacy)
        },
        createCard: @escaping CardCreator = { card, folderServerID in
            try await CardAPIService.createCard(card, folderServerID: folderServerID)
        },
        hasCredentials: @escaping () -> Bool = { KeychainService.hasCredentials },
        fetchFolders: @escaping FolderFetcher = { try await CollectionAPIService.fetchCollections() },
        fetchCards: @escaping CardFetcher = { try await CardAPIService.fetchAllCards() }
    ) {
        self.context = context
        self.createFolder = createFolder
        self.createCard = createCard
        self.hasCredentials = hasCredentials
        self.fetchFolders = fetchFolders
        self.fetchRemoteCards = fetchCards
        if seedIfEmpty { seedIfNeeded() }
        importPendingSharedCards()
        reload()
        publishCollectionsToSharedInbox()
    }

    // MARK: - Queries

    /// Cards belonging to a given collection (as primary or as an extra
    /// collection), newest first.
    func cards(in collectionID: UUID) -> [Card] {
        let serverID = collections.first { $0.id == collectionID }?.serverID
        return cards
            .filter { $0.isIn(collectionID: collectionID, serverID: serverID) }
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
        pushNewCard(card)
        return card
    }

    /// A card the user wrote themselves ("Write your own").
    @discardableResult
    func addOwnCard(title: String, description: String, content: String, tagsText: String,
                    collectionID: UUID? = nil) -> Card {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let card = Card(
            title: title,
            description: description,
            content: content,
            cardType: .originalScribe,
            sourceApp: .own,
            tags: tags,
            collectionID: resolveCollectionID(collectionID)
        )
        insert(card)
        save()
        reload()
        pushNewCard(card)
        return card
    }

    /// A pasted-link clip that could not be created online (offline, signed
    /// out, API error): kept locally with its type, price and cover, and
    /// pushed by the normal sync. Returns the new card's local id.
    func addClipCard(_ payload: SharePayload) -> UUID {
        let dto = SharedCardDTO(
            id: UUID(), title: payload.title, description: payload.description,
            urlString: payload.urlString ?? "", bodyText: payload.bodyText ?? "",
            imageData: payload.imageData, collectionID: payload.collectionID, createdAt: Date(),
            tags: payload.tags, cardTypeRaw: payload.cardTypeRaw, price: payload.price,
            imageURL: payload.imageURL)
        let card = Self.card(fromShared: dto, collectionID: resolveCollectionID(payload.collectionID))
        insert(card)
        save()
        reload()
        pushNewCard(card)
        return card.id
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
        pushNewCard(card)
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

        guard hasCredentials(), let serverID = card.serverID else { return }
        Task { try? await CardAPIService.updateCard(serverID: serverID, card: card) }
    }

    func deleteCard(id: UUID) {
        let serverID = cards.first(where: { $0.id == id })?.serverID
        guard let object = cdCard(id: id) else { return }
        context.delete(object)
        save()
        reload()

        guard hasCredentials(), let serverID else { return }
        Task { try? await CardAPIService.deleteCard(serverID: serverID) }
    }

    @discardableResult
    func addCollection(name: String, description: String = "", privacy: CollectionPrivacy) -> Collection {
        let collection = Collection(name: name, description: description, cardCount: 0, privacy: privacy)
        insert(collection)                 // CoreData first — instant UI update
        save()
        reload()
        publishCollectionsToSharedInbox()
        pushNewCollection(collection)      // then push to the API (if logged in)
        return collection
    }

    /// Delete a collection locally, then on the backend.
    func deleteCollection(id: UUID) {
        let serverID = collections.first(where: { $0.id == id })?.serverID
        if let object = cdCollection(id: id) {
            detachCards(fromCollection: id, serverID: object.value(forKey: "serverID") as? String)
            context.delete(object)
            save()
            reload()
            publishCollectionsToSharedInbox()
        }
        guard KeychainService.hasCredentials, let serverID else { return }
        Task { try? await CollectionAPIService.deleteCollection(serverID: serverID) }
    }

    /// Drop a collection that is about to be deleted from its cards, so none
    /// points at it: each card falls back to its next collection, or to
    /// Uncategorized when it has none left.
    private func detachCards(fromCollection id: UUID, serverID: String?) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCard")
        for card in (try? context.fetch(request)) ?? [] {
            let memberships = decodeTags(card.value(forKey: "folderIDsJSON") as? String)
            let remaining = memberships.filter { $0 != serverID }
            guard (card.value(forKey: "collectionID") as? UUID) == id || remaining != memberships else { continue }
            card.setValue(encodeTags(remaining), forKey: "folderIDsJSON")
            if (card.value(forKey: "collectionID") as? UUID) == id {
                card.setValue(primaryCollectionID(for: remaining), forKey: "collectionID")
            }
        }
    }

    // MARK: - Collections API sync

    /// Fetch folders from the API, wipe all local CoreData collections, and
    /// insert the fresh API response. This prevents duplicates from stale cache
    /// or seed data — MySQL is the single source of truth.
    func syncCollections() async {
        guard hasCredentials() else { return }
        
        // 1. Upload local collections that haven't been synced yet
        let localCollections = fetchCollections()
        for object in localCollections {
            if (object.value(forKey: "serverID") as? String) == nil {
                let name = object.value(forKey: "name") as? String ?? ""
                let desc = object.value(forKey: "collectionDescription") as? String ?? ""
                let privacy = object.value(forKey: "privacy") as? String ?? "private"
                do {
                    let remote = try await createFolder(name, desc, privacy)
                    if let serverID = remote.serverID {
                        object.setValue(serverID, forKey: "serverID")
                    }
                } catch {
                    // Skip if upload fails; keep it local (it won't have a serverID)
                }
            }
        }
        save()
        
        // 2. Fetch and reconcile
        do {
            let remote = try await fetchFolders()
            
            let existingCollections = fetchCollections()
            var existingByServerID: [String: NSManagedObject] = [:]
            for object in existingCollections {
                if let sID = object.value(forKey: "serverID") as? String {
                    existingByServerID[sID] = object
                }
            }
            
            let remoteServerIDs = Set(remote.compactMap { $0.serverID })
            
            // Delete local synced collections that are no longer on the server
            for (sID, object) in existingByServerID {
                if !remoteServerIDs.contains(sID) {
                    context.delete(object)
                }
            }
            
            // Update fields of existing collections (preserving local UUID/id) or insert new ones
            for collection in remote {
                if let sID = collection.serverID, let existingObject = existingByServerID[sID] {
                    existingObject.setValue(collection.name, forKey: "name")
                    existingObject.setValue(collection.description, forKey: "collectionDescription")
                    existingObject.setValue(collection.privacy.rawValue, forKey: "privacy")
                } else {
                    insert(collection)
                }
            }
            save()
            reload()
            publishCollectionsToSharedInbox()
        } catch {
            // Offline / unreachable → keep the cached collections.
        }
    }

    private func pushNewCollection(_ collection: Collection) {
        guard hasCredentials() else { return }
        pendingFolderCreates[collection.id] = Task { () -> String? in
            defer { pendingFolderCreates[collection.id] = nil }
            do {
                let remote = try await createFolder(
                    collection.name,
                    collection.description,
                    collection.privacy.rawValue
                )
                if let serverID = remote.serverID, let object = cdCollection(id: collection.id) {
                    object.setValue(serverID, forKey: "serverID")
                    save()
                    reload()
                    return serverID
                }
            } catch {
                // Stays local; a later sync/retry will reconcile it.
            }
            return nil
        }
    }

    // MARK: - Cards API sync

    /// Fetch cards from the API, wipe all local CoreData cards, and insert the
    /// fresh API response. Must run after syncCollections() so folder lookups
    /// by serverID resolve against the freshly inserted collections.
    func syncCards() async {
        guard hasCredentials() else { return }
        
        // 1. Upload local cards that are offline or haven't been synced yet
        let localCards = fetchCards()
        for object in localCards {
            let status = object.value(forKey: "syncStatus") as? String
            let serverID = object.value(forKey: "serverID") as? String
            
            if status == SyncStatus.offline.rawValue || serverID == nil {
                let card = card(from: object)
                let folderServerID = card.collectionID
                    .flatMap { cdCollection(id: $0)?.value(forKey: "serverID") as? String }
                do {
                    let remote = try await createCard(card, folderServerID)
                    if let remoteServerID = remote.serverID {
                        object.setValue(remoteServerID, forKey: "serverID")
                        object.setValue(SyncStatus.synced.rawValue, forKey: "syncStatus")
                    }
                } catch {
                    // Skip if upload fails; keep it local/offline
                }
            }
        }
        save()
        reload()   // uploads must show even when the fetch below fails
        
        // 2. Fetch and reconcile
        do {
            let remote = try await fetchRemoteCards()
            reconcileCards(remote)
        } catch {
            // Offline / unreachable → keep the cached cards.
        }
    }

    /// Push a just-created card to the API: mark syncing, then synced/offline.
    /// Resolves the collection's MySQL serverID on the main actor before entering
    /// the async Task so the POST body carries the correct folder_id.
    private func pushNewCard(_ card: Card) {
        guard hasCredentials() else { return }
        setSyncStatus(.syncing, for: card.id)
        // A collection without a folder id yet: wait for its in-flight create, or
        // (no create / it failed) stay offline so syncCards uploads the card later
        // with its folder instead of dropping it in Uncategorized. The card is
        // re-read after every wait: deleted -> never POSTed; edits and collection
        // changes made meanwhile are what gets sent.
        Task {
            while true {
                guard let object = cdCard(id: card.id) else { return }
                let current = self.card(from: object)
                let collection = current.collectionID.flatMap { cdCollection(id: $0) }
                let folderServerID = collection?.value(forKey: "serverID") as? String
                if folderServerID == nil, collection != nil {
                    if let pending = current.collectionID.flatMap({ pendingFolderCreates[$0] }) {
                        _ = await pending.value
                        continue
                    }
                    setSyncStatus(.offline, for: card.id)
                    return
                }
                do {
                    let remote = try await createCard(current, folderServerID)
                    if let object = cdCard(id: card.id) {
                        object.setValue(remote.serverID, forKey: "serverID")
                        object.setValue(SyncStatus.synced.rawValue, forKey: "syncStatus")
                        save()
                        reload()
                    }
                } catch {
                    setSyncStatus(.offline, for: card.id)
                }
                return
            }
        }
    }

    private func setSyncStatus(_ status: SyncStatus, for id: UUID) {
        guard let object = cdCard(id: id) else { return }
        object.setValue(status.rawValue, forKey: "syncStatus")
        save()
        reload()
    }

    /// Replace the card's collections on the API (primary first) and keep the
    /// confirmed list locally. Returns false (state unchanged) when it fails.
    func setCardCollections(cardID: UUID, folderServerIDs: [String]) async -> Bool {
        guard KeychainService.hasCredentials,
              let serverID = cards.first(where: { $0.id == cardID })?.serverID,
              !folderServerIDs.isEmpty else { return false }
        do {
            let dto = try await CardAPIService.setFolders(serverID: serverID, folderIDs: folderServerIDs)
            let confirmed = dto.folderServerIDs.isEmpty ? folderServerIDs : dto.folderServerIDs
            applyCardCollections(cardID: cardID, folderServerIDs: confirmed)
            return true
        } catch {
            return false
        }
    }

    /// Store the card's confirmed collections (primary first) locally, and
    /// point its local primary at the first one known on this device.
    func applyCardCollections(cardID: UUID, folderServerIDs: [String]) {
        guard let object = cdCard(id: cardID) else { return }
        object.setValue(encodeTags(folderServerIDs), forKey: "folderIDsJSON")
        object.setValue(primaryCollectionID(for: folderServerIDs), forKey: "collectionID")
        save()
        reload()
    }

    /// Local id of the first collection in `folderServerIDs` that exists on
    /// this device (the API lists the primary first); nil when none does.
    private func primaryCollectionID(for folderServerIDs: [String]) -> UUID? {
        folderServerIDs.lazy
            .compactMap { self.cdCollection(serverID: $0)?.value(forKey: "id") as? UUID }
            .first
    }

    // MARK: - Combined sync

    /// Pull collections then cards from the API (order matters so cards can be
    /// filed under their folders).
    func syncFromAPI() async {
        guard KeychainService.hasCredentials else { return }
        await syncCollections()
        await syncCards()
        lastSyncedAt = Date()
    }

    /// Re-sync only if it's been more than 5 minutes (used on foreground).
    func syncIfNeeded() async {
        guard KeychainService.hasCredentials else { return }
        if let last = lastSyncedAt, Date().timeIntervalSince(last) < 300 { return }
        await syncFromAPI()
    }

    // MARK: - Share Extension Bridge

    func publishCollectionsToSharedInbox() {
        SharedInbox.saveCollections(Self.sharedCollections(from: collections))
    }

    /// What the extension sees: each collection with its API folder id, so it
    /// no longer has to match folders by name.
    nonisolated static func sharedCollections(from collections: [Collection]) -> [SharedCollectionDTO] {
        collections.map { SharedCollectionDTO(id: $0.id, name: $0.name, serverID: $0.serverID) }
    }

    /// A queued clip as a card: keeps the type, price and cover URL the clip
    /// flow queued; older queued cards (no type) stay plain text.
    nonisolated static func card(fromShared dto: SharedCardDTO, collectionID: UUID?) -> Card {
        let isLink = !dto.urlString.isEmpty
        return Card(
            title: dto.title.isEmpty ? (isLink ? "Shared Link" : "Shared Text") : dto.title,
            description: dto.description,
            content: isLink ? dto.urlString : dto.bodyText,
            cardType: dto.cardTypeRaw.flatMap(CardType.init(rawValue:)) ?? .text,
            sourceApp: SourceApp(rawValue: dto.sourceAppRaw) ?? .safari,
            imageURL: dto.imageURL,
            imageData: dto.imageData,
            price: dto.price ?? "",
            tags: dto.tags ?? [],
            collectionID: collectionID
        )
    }

    func importPendingSharedCards() {
        let pending = SharedInbox.loadPendingCards()
        guard !pending.isEmpty else { return }

        for dto in pending {
            insert(Self.card(fromShared: dto, collectionID: resolveCollectionID(dto.collectionID)))
        }
        SharedInbox.clearPendingCards()
        save()
        reload()
    }

    // MARK: - Seeding

    private func seedIfNeeded() {
        // Sample data exists only for the mock UI-test experience. Never seed
        // in real mode: after sign-up, syncCollections uploads every local
        // collection without a serverID, which would push the samples into
        // the user's real account.
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("UITEST") || args.contains("LOGGED_OUT") else { return }

        #if DEBUG
        // Under UI tests, CoreData persists across test runs on the simulator.
        // Reset to deterministic state so every test sees identical mock data.
        if ProcessInfo.processInfo.arguments.contains("UITEST") {
            fetchCards().forEach { context.delete($0) }
            fetchCollections().forEach { context.delete($0) }
            save()
        }
        #endif

        guard fetchCollections().isEmpty else { return }
        for mock in Collection.mockCollections {
            insert(mock)
            for card in Card.seededCards(for: mock) {
                insert(card)
            }
        }
        save()
    }

    /// Reconciles local CoreData cards against a remote card list.
    func reconcileCards(_ remote: [BusinessDTO]) {
        let localCards = fetchCards()
        var remoteServerIDs = Set<String>()
        
        for dto in remote {
            guard let remoteID = dto.serverID else { continue }
            remoteServerIDs.insert(remoteID)
            
            if let existingObject = localCards.first(where: { ($0.value(forKey: "serverID") as? String) == remoteID }) {
                // Update text fields of the existing local card, leaving imageData untouched!
                existingObject.setValue(dto.title.isEmpty ? "Untitled" : dto.title, forKey: "title")
                existingObject.setValue(dto.description, forKey: "cardDescription")
                existingObject.setValue(dto.website, forKey: "content")
                existingObject.setValue(encodeTags(dto.tags), forKey: "tagsJSON")
                existingObject.setValue(dto.price, forKey: "price")
                existingObject.setValue(encodeTags(dto.folderServerIDs), forKey: "folderIDsJSON")
                existingObject.setValue(dto.imageURL, forKey: "imageURL")
                
                if let folderServerID = dto.folderServerID,
                   let folder = cdCollection(serverID: folderServerID) {
                    existingObject.setValue(folder.value(forKey: "id") as? UUID, forKey: "collectionID")
                } else {
                    existingObject.setValue(nil, forKey: "collectionID")
                }
                existingObject.setValue(SyncStatus.synced.rawValue, forKey: "syncStatus")
            } else {
                // Create new local card
                var card = dto.toCard()
                if let folderServerID = dto.folderServerID,
                   let folder = cdCollection(serverID: folderServerID) {
                    card.collectionID = folder.value(forKey: "id") as? UUID
                }
                insert(card)
            }
        }
        
        // Delete local cards that were deleted on the server
        for object in localCards {
            let status = object.value(forKey: "syncStatus") as? String
            let serverID = object.value(forKey: "serverID") as? String
            
            if status == SyncStatus.synced.rawValue, let sid = serverID, !remoteServerIDs.contains(sid) {
                context.delete(object)
            }
        }
        
        save()
        reload()
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

    private func cdCard(serverID: String) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCard")
        request.predicate = NSPredicate(format: "serverID == %@", serverID)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    private func cdCollection(id: UUID) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCollection")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    private func cdCollection(serverID: String) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCollection")
        request.predicate = NSPredicate(format: "serverID == %@", serverID)
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
        object.setValue(collection.serverID, forKey: "serverID")
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
        object.setValue(card.serverID, forKey: "serverID")
        object.setValue(card.price, forKey: "price")
        object.setValue(encodeTags(card.folderServerIDs), forKey: "folderIDsJSON")
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

        let collectionObjects = fetchCollections()
        var countByCollection: [UUID: Int] = [:]
        for object in collectionObjects {
            guard let id = object.value(forKey: "id") as? UUID else { continue }
            let serverID = object.value(forKey: "serverID") as? String
            countByCollection[id] = mappedCards.filter { $0.isIn(collectionID: id, serverID: serverID) }.count
        }

        self.collections = collectionObjects.map { object in
            let id = object.value(forKey: "id") as? UUID ?? UUID()
            return Collection(
                id: id,
                name: object.value(forKey: "name") as? String ?? "",
                description: object.value(forKey: "collectionDescription") as? String ?? "",
                cardCount: countByCollection[id] ?? 0,
                privacy: CollectionPrivacy(rawValue: object.value(forKey: "privacy") as? String ?? "") ?? .private,
                createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
                serverID: object.value(forKey: "serverID") as? String
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
            price: object.value(forKey: "price") as? String ?? "",
            tags: decodeTags(object.value(forKey: "tagsJSON") as? String),
            syncStatus: SyncStatus(rawValue: object.value(forKey: "syncStatus") as? String ?? "") ?? .synced,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            collectionID: object.value(forKey: "collectionID") as? UUID,
            serverID: object.value(forKey: "serverID") as? String,
            folderServerIDs: decodeTags(object.value(forKey: "folderIDsJSON") as? String)
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
