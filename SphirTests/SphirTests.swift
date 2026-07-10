//
//  SphirTests.swift
//  SphirTests
//
//  Created by Saul Alejandro on 09/07/26.
//

import Testing
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

}
