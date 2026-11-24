//
//  OfflineCardUploadTests.swift
//  SphirTests
//
//  A card left offline because its collection had no folder id yet is uploaded
//  by the next sync, after the collection got its id, carrying that folder id.
//  All network and Keychain access is replaced by injected fakes.
//

import Testing
import Foundation
import CoreData
@testable import Sphir

@MainActor
private final class FakeBackend {
    var online = false
    var calls: [String] = []

    func createFolder(name: String) async throws -> Collection {
        calls.append("folder")
        if !online { throw URLError(.notConnectedToInternet) }
        return Collection(name: name, cardCount: 0, serverID: "F1")
    }

    func createCard(_ card: Card, folder: String?) async throws -> Card {
        calls.append("card:\(folder ?? "nil")")
        if !online { throw URLError(.notConnectedToInternet) }
        var remote = card
        remote.serverID = "C1"
        return remote
    }
}

@MainActor
@Suite(.serialized)
struct OfflineCardUploadTests {
    private let backend = FakeBackend()
    private let store: AppStore

    init() {
        let backend = backend
        store = AppStore(
            context: PersistenceController(inMemory: true).container.viewContext,
            seedIfEmpty: false,
            createFolder: { name, _, _ in try await backend.createFolder(name: name) },
            createCard: { try await backend.createCard($0, folder: $1) },
            hasCredentials: { true },
            fetchFolders: { [Collection(name: "Trip", cardCount: 0, serverID: "F1")] },
            fetchCards: { throw URLError(.notConnectedToInternet) }   // keep the local cache
        )
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<300 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    @Test func offlineCardIsUploadedWithItsFolderOnceTheCollectionSyncs() async {
        let collection = store.addCollection(name: "Trip", privacy: .private)
        let card = store.addCard(title: "one", description: "", urlText: "https://a.test/one", tagsText: "",
                                 type: .text, source: .url, collectionID: collection.id)
        #expect(await waitUntil { store.cards.first { $0.id == card.id }?.syncStatus == .offline })
        #expect(store.collections.first { $0.id == collection.id }?.serverID == nil)
        #expect(backend.calls == ["folder"])         // card never POSTed without its folder

        backend.online = true
        backend.calls = []
        await store.syncCollections()
        await store.syncCards()

        #expect(backend.calls == ["folder", "card:F1"])   // folder first, then the card with its id
        let synced = store.cards.first { $0.id == card.id }
        #expect(synced?.syncStatus == .synced)
        #expect(synced?.serverID == "C1")
        #expect(synced?.collectionID == collection.id)
        #expect(store.collections.first { $0.id == collection.id }?.serverID == "F1")
    }
}
