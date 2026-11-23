//
//  CardCollectionRaceTests.swift
//  SphirTests
//
//  A card added to a collection whose create request is still in flight must
//  wait for it and be created with the new folder id; with no folder id at all
//  it must stay offline (syncCards uploads it later, with the folder). The
//  network is replaced by suspendable fakes injected into AppStore.
//

import Testing
import Foundation
import CoreData
@testable import Sphir

@MainActor
private final class FakeAPI {
    var folderCalls = 0
    var cardCalls: [(title: String, folder: String?)] = []
    var holdFolder = false
    var failFolder = false
    private var gate: CheckedContinuation<Void, Never>?

    var folderIsHeld: Bool { gate != nil }

    func createFolder(name: String, description: String, privacy: String) async throws -> Collection {
        folderCalls += 1
        if holdFolder {
            await withCheckedContinuation { gate = $0 }
            gate = nil
        }
        if failFolder { throw URLError(.notConnectedToInternet) }
        return Collection(name: name, cardCount: 0, serverID: "F1")
    }

    func createCard(_ card: Card, folder: String?) async throws -> Card {
        cardCalls.append((card.title, folder))
        var remote = card
        remote.serverID = "C\(cardCalls.count)"
        return remote
    }

    func releaseFolder() { gate?.resume() }
}

@MainActor
@Suite(.serialized)
struct CardCollectionRaceTests {
    private let api = FakeAPI()
    private let store: AppStore

    init() {
        let api = api
        store = AppStore(
            context: PersistenceController(inMemory: true).container.viewContext,
            seedIfEmpty: false,
            createFolder: { try await api.createFolder(name: $0, description: $1, privacy: $2) },
            createCard: { try await api.createCard($0, folder: $1) },
            hasCredentials: { true }          // never touches the Keychain
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

    // MARK: - Tests

    @Test func cardWaitsForInFlightFolderAndGetsItsID() async {
        api.holdFolder = true
        let collection = store.addCollection(name: "Trip", privacy: .private)
        #expect(await waitUntil { api.folderIsHeld })

        let card = addCard("one", to: collection.id)
        await settle()
        #expect(api.cardCalls.isEmpty)               // still waiting for the folder

        api.releaseFolder()
        #expect(await waitUntil { api.cardCalls.count == 1 })
        #expect(api.cardCalls.first?.folder == "F1")
        #expect(await waitUntil { status(card) == .synced })
        #expect(api.folderCalls == 1)
        #expect(store.collections.first { $0.id == collection.id }?.serverID == "F1")
    }

    @Test func twoCardsDuringTheSameCreateBothGetTheFolderID() async {
        api.holdFolder = true
        let collection = store.addCollection(name: "Trip", privacy: .private)
        #expect(await waitUntil { api.folderIsHeld })

        _ = addCard("one", to: collection.id)
        _ = addCard("two", to: collection.id)
        await settle()
        #expect(api.cardCalls.isEmpty)

        api.releaseFolder()
        #expect(await waitUntil { api.cardCalls.count == 2 })
        #expect(api.cardCalls.map(\.folder) == ["F1", "F1"])
        #expect(api.folderCalls == 1)
    }

    @Test func failedFolderKeepsTheCardOfflineAndUnsent() async {
        api.holdFolder = true
        api.failFolder = true
        let collection = store.addCollection(name: "Trip", privacy: .private)
        #expect(await waitUntil { api.folderIsHeld })

        let card = addCard("one", to: collection.id)
        api.releaseFolder()                          // create fails
        #expect(await waitUntil { status(card) == .offline })
        await settle()
        #expect(api.cardCalls.isEmpty)               // never POSTed without its folder
        #expect(status(card) == .offline)
        #expect(store.collections.first { $0.id == collection.id }?.serverID == nil)

        // A card added after the failure (no create in flight) is held back too.
        let later = addCard("two", to: collection.id)
        #expect(await waitUntil { status(later) == .offline })
        await settle()
        #expect(api.cardCalls.isEmpty)
    }

    // MARK: - Preserved behavior

    @Test func cardIntoSyncedCollectionIsPostedImmediatelyWithItsFolder() async {
        let collection = store.addCollection(name: "Trip", privacy: .private)
        #expect(await waitUntil { store.collections.first { $0.id == collection.id }?.serverID == "F1" })

        let card = addCard("one", to: collection.id)
        #expect(await waitUntil { api.cardCalls.count == 1 })
        #expect(api.cardCalls.first?.folder == "F1")
        #expect(await waitUntil { status(card) == .synced })
        #expect(api.folderCalls == 1)
    }

    @Test func cardWithoutCollectionIsPostedWithNoFolder() async {
        let card = addCard("one", to: nil)
        #expect(await waitUntil { api.cardCalls.count == 1 })
        #expect(api.cardCalls.first?.folder == nil)
        #expect(await waitUntil { status(card) == .synced })
    }
}
