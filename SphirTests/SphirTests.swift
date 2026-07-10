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

    /// Metadata captured by the extension (title, description, thumbnail)
    /// survives the App Group round-trip onto the imported Card.
    @MainActor
    @Test func importedCardCarriesMetadata() async throws {
        SharedInbox.clearPendingCards()

        let store = AppStore()
        let first = try #require(store.collections.first)
        let thumbnail = Data([0x01, 0x02, 0x03, 0x04])

        SharedInbox.enqueueCard(
            SharedCardDTO(
                id: UUID(),
                title: "Apple",
                description: "Think different.",
                urlString: "https://apple.com",
                imageData: thumbnail,
                collectionID: first.id,
                createdAt: Date()
            )
        )
        store.importPendingSharedCards()

        let card = try #require(store.cards(in: first.id).first { $0.content == "https://apple.com" })
        #expect(card.title == "Apple")
        #expect(card.description == "Think different.")
        #expect(card.imageData == thumbnail)
    }

    /// A text share (Mail body / Messages text, no URL) imports as a text card
    /// with the body as its content and the correct source app.
    @MainActor
    @Test func importsTextShareAsBodyCard() async throws {
        SharedInbox.clearPendingCards()

        let store = AppStore()
        let first = try #require(store.collections.first)
        let body = "Lunch at noon? Here's the spot: https://maps.example.com/x"

        SharedInbox.enqueueCard(
            SharedCardDTO(
                id: UUID(),
                title: "Lunch at noon?",
                bodyText: body,
                sourceAppRaw: "messages",
                collectionID: first.id,
                createdAt: Date()
            )
        )
        store.importPendingSharedCards()

        let card = try #require(store.cards(in: first.id).first { $0.content == body })
        #expect(card.title == "Lunch at noon?")
        #expect(card.sourceApp == .messages)
        #expect(SharedInbox.loadPendingCards().isEmpty)
    }

}
