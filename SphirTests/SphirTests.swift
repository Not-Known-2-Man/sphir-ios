//
//  SphirTests.swift
//  SphirTests
//
//  Created by Saul Alejandro on 09/07/26.
//

import Testing
import Foundation
@testable import Sphir

struct SphirTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

    /// A card enqueued to the App Group (as a share extension would do) is
    /// imported into a collection the next time the app store is created.
    @MainActor
    @Test func importsPendingSharedCard() async throws {
        SharedInbox.clearPendingCards()
        SharedInbox.enqueueCard(
            SharedCardDTO(
                id: UUID(),
                title: "example.com",
                urlString: "https://example.com/article",
                collectionID: nil, // no destination → first collection
                createdAt: Date()
            )
        )

        let store = AppStore()
        let first = try #require(store.collections.first)

        #expect(store.cards(in: first.id).contains { $0.content == "https://example.com/article" })
        #expect(SharedInbox.loadPendingCards().isEmpty)
    }

    /// Simulates the real bug path: the app is already running, the extension
    /// writes a card, and the app imports it on foreground resume — the count
    /// must increase and the card must land in the chosen collection.
    @MainActor
    @Test func importsSharedCardOnForegroundResume() async throws {
        SharedInbox.clearPendingCards()

        let store = AppStore()
        let first = try #require(store.collections.first)
        let countBefore = store.cards(in: first.id).count
        let cardCountBefore = first.cardCount

        // Extension writes a card targeting the (already published) collection.
        SharedInbox.enqueueCard(
            SharedCardDTO(
                id: UUID(),
                title: "example.com",
                urlString: "https://example.com/foreground",
                collectionID: first.id,
                createdAt: Date()
            )
        )

        // App returns to foreground.
        store.importPendingSharedCards()

        let updatedFirst = try #require(store.collections.first { $0.id == first.id })
        #expect(store.cards(in: first.id).count == countBefore + 1)
        #expect(updatedFirst.cardCount == cardCountBefore + 1)
        #expect(store.cards(in: first.id).contains { $0.content == "https://example.com/foreground" })
        #expect(SharedInbox.loadPendingCards().isEmpty)
    }

}
