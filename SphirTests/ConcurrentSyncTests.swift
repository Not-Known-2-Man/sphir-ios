//
//  ConcurrentSyncTests.swift
//  SphirTests
//
//  syncCollections / syncCards running while a push is in flight must not
//  create the same folder or POST the same card twice, and must not touch
//  objects deleted while a request was awaited. All network and Keychain
//  access is replaced by injected fakes.
//

import Testing
import Foundation
import CoreData
@testable import Sphir

@MainActor
private final class FakeAPI {
    var credentials = true
    var folderCalls = 0
    var cardCalls: [String] = []
    var cardFolders: [String?] = []
    var holdNextFolder = false
    var holdNextCard = false
    var failFolder = false
    private var folderGate: CheckedContinuation<Void, Never>?
    private var cardGate: CheckedContinuation<Void, Never>?

    var folderIsHeld: Bool { folderGate != nil }
    var cardIsHeld: Bool { cardGate != nil }

    func createFolder(name: String) async throws -> Collection {
        folderCalls += 1
        if holdNextFolder {
            holdNextFolder = false
            await withCheckedContinuation { folderGate = $0 }
            folderGate = nil
        }
        if failFolder { throw URLError(.notConnectedToInternet) }
        return Collection(name: name, cardCount: 0, serverID: "F\(folderCalls)")
    }

    func createCard(_ card: Card, folder: String?) async throws -> Card {
        cardCalls.append(card.title)
        cardFolders.append(folder)
        let n = cardCalls.count
        if holdNextCard {
            holdNextCard = false
            await withCheckedContinuation { cardGate = $0 }
            cardGate = nil
        }
        var remote = card
        remote.serverID = "C\(n)"
        return remote
    }

    var updatedCards: [String] = []      // "serverID:title"
    var deletedCards: [String] = []
    var deletedFolders: [String] = []

    func releaseFolder() { folderGate?.resume() }
    func releaseCard() { cardGate?.resume() }
}

@MainActor
@Suite(.serialized)
struct ConcurrentSyncTests {
    private let api = FakeAPI()
    private let store: AppStore

    init() {
        let api = api
        store = AppStore(
            context: PersistenceController(inMemory: true).container.viewContext,
            seedIfEmpty: false,
            createFolder: { name, _, _ in try await api.createFolder(name: name) },
            createCard: { card, folder in try await api.createCard(card, folder: folder) },
            hasCredentials: { api.credentials },
            fetchFolders: { throw URLError(.notConnectedToInternet) },
            fetchCards: { throw URLError(.notConnectedToInternet) },
            updateCardAPI: { id, card in api.updatedCards.append("\(id):\(card.title)") },
            deleteCardAPI: { api.deletedCards.append($0) },
            deleteFolderAPI: { api.deletedFolders.append($0) }
        )
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<300 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func settle() async { try? await Task.sleep(for: .milliseconds(150)) }

    private func addCard(_ title: String, to collection: UUID?) -> Card {
        store.addCard(title: title, description: "", urlText: "https://a.test/\(title)", tagsText: "",
                      type: .text, source: .url, collectionID: collection)
    }

    private func status(_ card: Card) -> SyncStatus? { store.cards.first { $0.id == card.id }?.syncStatus }

    // MARK: - F1: one POST per card

    @Test func syncCardsSkipsACardWaitingForItsFolder() async {
        api.holdNextFolder = true
        let collection = store.addCollection(name: "Trip", privacy: .private)
        #expect(await waitUntil { api.folderIsHeld })
        let card = addCard("one", to: collection.id)
        await settle()

        await store.syncCards()                      // the card is mid-push: not its turn
        #expect(api.cardCalls.isEmpty)

        api.releaseFolder()
        #expect(await waitUntil { status(card) == .synced })
        #expect(api.cardCalls == ["one"])
    }

    @Test func syncCardsSkipsACardWhoseCreateIsInFlight() async {
        api.holdNextCard = true
        let card = addCard("one", to: nil)
        #expect(await waitUntil { api.cardIsHeld })

        await store.syncCards()                      // must not POST it a second time
        #expect(api.cardCalls == ["one"])

        api.releaseCard()
        #expect(await waitUntil { status(card) == .synced })
        #expect(api.cardCalls == ["one"])
    }

    @Test func twoOverlappingSyncCardsPostTheCardOnce() async {
        api.credentials = false                      // added offline: no push
        let card = addCard("one", to: nil)
        api.credentials = true
        api.holdNextCard = true
        let first = Task { await store.syncCards() }
        #expect(await waitUntil { api.cardIsHeld })

        await store.syncCards()                      // second sync while the first uploads
        #expect(api.cardCalls == ["one"])

        api.releaseCard()
        await first.value
        #expect(api.cardCalls == ["one"])
        #expect(status(card) == .synced)
    }

    // MARK: - F2: one create per collection

    @Test func syncCollectionsWaitsForAnInFlightFolderCreate() async {
        api.holdNextFolder = true
        let collection = store.addCollection(name: "Trip", privacy: .private)
        #expect(await waitUntil { api.folderIsHeld })

        let sync = Task { await store.syncCollections() }
        await settle()
        #expect(api.folderCalls == 1)                // no second create for the same collection

        api.releaseFolder()
        await sync.value
        #expect(api.folderCalls == 1)
        #expect(store.collections.filter { $0.id == collection.id }.count == 1)
        #expect(store.collections.first { $0.id == collection.id }?.serverID == "F1")
    }

    @Test func twoOverlappingSyncCollectionsCreateTheFolderOnce() async {
        api.credentials = false                      // added offline: no push
        let collection = store.addCollection(name: "Trip", privacy: .private)
        api.credentials = true
        api.holdNextFolder = true
        let first = Task { await store.syncCollections() }
        #expect(await waitUntil { api.folderIsHeld })

        let second = Task { await store.syncCollections() }
        await settle()
        #expect(api.folderCalls == 1)                // second sync waits, never re-creates

        api.releaseFolder()
        await first.value
        await second.value
        #expect(api.folderCalls == 1)
        #expect(store.collections.filter { $0.id == collection.id }.count == 1)
        #expect(store.collections.first { $0.id == collection.id }?.serverID == "F1")
    }

    @Test func cardPushedDuringSyncCreateWaitsAndGetsTheFolderID() async {
        api.credentials = false
        let collection = store.addCollection(name: "Trip", privacy: .private)
        api.credentials = true
        api.holdNextFolder = true
        let sync = Task { await store.syncCollections() }
        #expect(await waitUntil { api.folderIsHeld })

        let card = addCard("one", to: collection.id)
        await settle()
        #expect(api.cardCalls.isEmpty)               // waiting for the sync's create

        api.releaseFolder()
        await sync.value
        #expect(await waitUntil { status(card) == .synced })
        #expect(api.cardCalls == ["one"])
        #expect(api.cardFolders == ["F1"])
    }

    // MARK: - F3: objects deleted while a request is awaited

    @Test func collectionDeletedDuringSyncIsNotTouchedAndStaysGone() async {
        api.credentials = false
        let collection = store.addCollection(name: "Trip", privacy: .private)
        api.credentials = true
        api.holdNextFolder = true
        let sync = Task { await store.syncCollections() }
        #expect(await waitUntil { api.folderIsHeld })

        store.deleteCollection(id: collection.id)
        api.releaseFolder()
        await sync.value
        #expect(store.collections.isEmpty)
    }

    @Test func cardDeletedDuringSyncIsNotTouchedAndStaysGone() async {
        api.credentials = false
        let card = addCard("one", to: nil)
        api.credentials = true
        api.holdNextCard = true
        let sync = Task { await store.syncCards() }
        #expect(await waitUntil { api.cardIsHeld })

        store.deleteCard(id: card.id)
        api.releaseCard()
        await sync.value
        #expect(store.cards.isEmpty)
    }

    // MARK: - F5: failed folder create while a card waits

    @Test func failedFolderEndsTheWaitAndLeavesTheCardOffline() async {
        api.holdNextFolder = true
        api.failFolder = true
        let collection = store.addCollection(name: "Trip", privacy: .private)
        #expect(await waitUntil { api.folderIsHeld })
        let card = addCard("one", to: collection.id)
        await settle()

        api.releaseFolder()                          // the create fails
        #expect(await waitUntil { status(card) == .offline })   // bounded: wait loop ended
        await settle()
        #expect(api.cardCalls.isEmpty)
        #expect(status(card) == .offline)
    }

    // MARK: - F4: update/delete go through the injected seams

    @Test func updateAndDeleteUseTheInjectedAPIs() async {
        let collection = store.addCollection(name: "Trip", privacy: .private)
        #expect(await waitUntil { store.collections.first { $0.id == collection.id }?.serverID == "F1" })
        var card = addCard("one", to: nil)
        #expect(await waitUntil { status(card) == .synced })
        card.serverID = "C1"
        card.title = "edited"

        store.updateCard(card)
        #expect(await waitUntil { api.updatedCards == ["C1:edited"] })

        store.deleteCard(id: card.id)
        #expect(await waitUntil { api.deletedCards == ["C1"] })

        store.deleteCollection(id: collection.id)
        #expect(await waitUntil { api.deletedFolders == ["F1"] })

        api.credentials = false                      // without credentials nothing is sent
        let other = addCard("two", to: nil)
        store.deleteCard(id: other.id)
        await settle()
        #expect(api.deletedCards == ["C1"])
    }

    // MARK: - Orphan folder: collection deleted while its create was in flight

    @Test func folderCreatedForADeletedCollectionIsDeletedOnTheServer() async {
        api.holdNextFolder = true
        let collection = store.addCollection(name: "Trip", privacy: .private)
        #expect(await waitUntil { api.folderIsHeld })

        store.deleteCollection(id: collection.id)    // no serverID yet: nothing to delete remotely
        #expect(api.deletedFolders.isEmpty)
        api.releaseFolder()

        #expect(await waitUntil { api.deletedFolders == ["F1"] })
        await settle()
        #expect(api.deletedFolders == ["F1"])        // exactly once
    }

    @Test func folderOfAKeptCollectionIsNotDeleted() async {
        api.holdNextFolder = true
        let collection = store.addCollection(name: "Trip", privacy: .private)
        #expect(await waitUntil { api.folderIsHeld })
        api.releaseFolder()

        #expect(await waitUntil { store.collections.first { $0.id == collection.id }?.serverID == "F1" })
        await settle()
        #expect(api.deletedFolders.isEmpty)
    }
}
