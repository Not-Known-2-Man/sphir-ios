//
//  AccountDeletionRaceTests.swift
//  SphirTests
//
//  A sync already waiting on the API when the account is deleted must not
//  re-create the wiped collections or cards once its response arrives.
//

import Testing
import Foundation
import CoreData
@testable import Sphir

@MainActor @Suite(.serialized)
struct AccountDeletionRaceTests {

    private func waitFor(_ ready: () -> Bool) async {
        for _ in 0..<200 where !ready() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    @Test func inFlightCardSyncCannotRecreateCardsAfterReset() async throws {
        var gate: CheckedContinuation<Void, Never>?
        let dto = try JSONDecoder().decode(BusinessDTO.self, from: Data(#"{"id":99,"title":"Ghost","description":"","website":"https://g.test","email":"","tags":[]}"#.utf8))
        let store = AppStore(
            context: PersistenceController(inMemory: true).container.viewContext,
            seedIfEmpty: false, hasCredentials: { true }, fetchFolders: { [] },
            fetchCards: { await withCheckedContinuation { gate = $0 }; return [dto] })
        let sync = Task { await store.syncCards() }
        await waitFor { gate != nil }
        store.resetLocalData()
        gate?.resume()
        await sync.value
        #expect(store.cards.isEmpty)
    }

    @Test func inFlightCollectionSyncCannotRecreateCollectionsAfterReset() async throws {
        var gate: CheckedContinuation<Void, Never>?
        let store = AppStore(
            context: PersistenceController(inMemory: true).container.viewContext,
            seedIfEmpty: false, hasCredentials: { true },
            fetchFolders: {
                await withCheckedContinuation { gate = $0 }
                return [Collection(name: "Ghost", cardCount: 0, serverID: "F9")]
            },
            fetchCards: { [] })
        let sync = Task { await store.syncCollections() }
        await waitFor { gate != nil }
        store.resetLocalData()
        gate?.resume()
        await sync.value
        #expect(store.collections.isEmpty)
    }
}
