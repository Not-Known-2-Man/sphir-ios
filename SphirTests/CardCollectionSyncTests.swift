//
//  CardCollectionSyncTests.swift
//  SphirTests
//
//  The local primary collection (`collectionID`) must follow the card's
//  server memberships (`folderServerIDs`, primary first), so a card never
//  shows under Uncategorized while it belongs to a collection, and never
//  points at a deleted collection.
//

import Testing
import Foundation
import CoreData
@testable import Sphir

@MainActor
struct CardCollectionSyncTests {

    private let context = PersistenceController(inMemory: true).container.viewContext

    private func makeStore() -> AppStore {
        AppStore(context: context, seedIfEmpty: false)
    }

    /// A local collection that already has its server id.
    private func addSyncedCollection(_ store: AppStore, name: String, serverID: String) -> UUID {
        let collection = store.addCollection(name: name, privacy: .private)
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDCollection")
        request.predicate = NSPredicate(format: "id == %@", collection.id as CVarArg)
        try! context.fetch(request).first!.setValue(serverID, forKey: "serverID")
        try! context.save()
        return collection.id
    }

    private func addCard(_ store: AppStore, collectionID: UUID? = nil) -> UUID {
        store.addCard(title: "Card", description: "", urlText: "", tagsText: "",
                      type: .text, source: .url, collectionID: collectionID).id
    }

    private func card(_ store: AppStore, _ id: UUID) -> Card {
        store.cards.first(where: { $0.id == id })!
    }

    // MARK: - Add to collections

    @Test func addToCollectionsMovesUncategorizedCardToItsPrimary() {
        let store = makeStore()
        // Created while no collection exists, so it starts Uncategorized
        // (addCard otherwise falls back to the first collection).
        let cardID = addCard(store)
        let recipes = addSyncedCollection(store, name: "Recipes", serverID: "7")
        let gifts = addSyncedCollection(store, name: "Gifts", serverID: "8")
        #expect(card(store, cardID).collectionID == nil)

        store.applyCardCollections(cardID: cardID, folderServerIDs: ["8", "7"])

        #expect(card(store, cardID).collectionID == gifts)
        #expect(card(store, cardID).folderServerIDs == ["8", "7"])
        #expect(card(store, cardID).isIn(collectionID: recipes, serverID: "7"))
    }

    @Test func addToCollectionsSkipsFoldersNotKnownLocally() {
        let store = makeStore()
        let cardID = addCard(store)
        let recipes = addSyncedCollection(store, name: "Recipes", serverID: "7")

        store.applyCardCollections(cardID: cardID, folderServerIDs: ["99", "7"])

        #expect(card(store, cardID).collectionID == recipes)

        store.applyCardCollections(cardID: cardID, folderServerIDs: ["99"])

        #expect(card(store, cardID).collectionID == nil)
    }

    // MARK: - Delete collection

    @Test func deletingPrimaryCollectionFallsBackToNextMembership() {
        let store = makeStore()
        let recipes = addSyncedCollection(store, name: "Recipes", serverID: "7")
        let gifts = addSyncedCollection(store, name: "Gifts", serverID: "8")
        let cardID = addCard(store, collectionID: recipes)
        store.applyCardCollections(cardID: cardID, folderServerIDs: ["7", "8"])

        store.deleteCollection(id: recipes)

        #expect(card(store, cardID).collectionID == gifts)
        #expect(card(store, cardID).folderServerIDs == ["8"])
    }

    @Test func deletingOnlyCollectionLeavesCardUncategorized() {
        let store = makeStore()
        let recipes = addSyncedCollection(store, name: "Recipes", serverID: "7")
        let localOnly = store.addCollection(name: "Local", privacy: .private).id
        let synced = addCard(store, collectionID: recipes)
        store.applyCardCollections(cardID: synced, folderServerIDs: ["7"])
        let local = addCard(store, collectionID: localOnly)

        store.deleteCollection(id: recipes)
        store.deleteCollection(id: localOnly)

        #expect(card(store, synced).collectionID == nil)
        #expect(card(store, synced).folderServerIDs.isEmpty)
        #expect(card(store, local).collectionID == nil)
    }

    @Test func deletingAnotherCollectionKeepsCardsUntouched() {
        let store = makeStore()
        let recipes = addSyncedCollection(store, name: "Recipes", serverID: "7")
        let gifts = addSyncedCollection(store, name: "Gifts", serverID: "8")
        let cardID = addCard(store, collectionID: recipes)

        store.deleteCollection(id: gifts)

        #expect(card(store, cardID).collectionID == recipes)
    }
}
