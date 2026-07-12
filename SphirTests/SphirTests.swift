//
//  SphirTests.swift
//  SphirTests
//
//  Created by Saul Alejandro on 09/07/26.
//

import Testing
import Foundation
import CoreData
import SwiftUI
import UIKit
@testable import Sphir

struct SphirTests {

    /// An isolated, in-memory store so tests don't touch (or persist into)
    /// the shared App Group CoreData store.
    @MainActor
    private func makeStore() -> AppStore {
        AppStore(context: PersistenceController(inMemory: true).container.viewContext)
    }

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

        let store = makeStore()
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

        let store = makeStore()
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

        let store = makeStore()
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

        let store = makeStore()
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

    /// A screenshot card stores the image + extracted text and bumps the count.
    @MainActor
    @Test func addsScreenshotCardWithImageAndText() async throws {
        let store = makeStore()
        let first = try #require(store.collections.first)
        let countBefore = store.cards(in: first.id).count
        let cardCountBefore = first.cardCount
        let png = Data([0xFF, 0xD8, 0xFF, 0xE0])

        store.addScreenshotCard(
            title: "Receipt total",
            content: "Receipt total\n$42.00\nThank you",
            imageData: png,
            collectionID: first.id
        )

        let updatedFirst = try #require(store.collections.first { $0.id == first.id })
        let card = try #require(store.cards(in: first.id).first { $0.title == "Receipt total" })
        #expect(card.content == "Receipt total\n$42.00\nThank you")
        #expect(card.imageData == png)
        #expect(card.sourceApp == .screenshot)
        #expect(store.cards(in: first.id).count == countBefore + 1)
        #expect(updatedFirst.cardCount == cardCountBefore + 1)
    }

    /// A photo card stores the image + metadata details with the photos source.
    @MainActor
    @Test func addsPhotoCardWithImageAndMetadata() async throws {
        let store = makeStore()
        let first = try #require(store.collections.first)
        let cardCountBefore = first.cardCount
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xDB])

        store.addPhotoCard(
            title: "Photo — Jul 10, 2026",
            content: "Taken: Jul 10, 2026 at 9:41 AM\nCamera: Apple iPhone",
            imageData: jpeg,
            collectionID: first.id
        )

        let updatedFirst = try #require(store.collections.first { $0.id == first.id })
        let card = try #require(store.cards(in: first.id).first { $0.title == "Photo — Jul 10, 2026" })
        #expect(card.imageData == jpeg)
        #expect(card.sourceApp == .photos)
        #expect(card.content.contains("Camera: Apple iPhone"))
        #expect(updatedFirst.cardCount == cardCountBefore + 1)
    }

    /// Collections and cards written to a store survive being reopened from
    /// the same on-disk CoreData store (simulates an app relaunch).
    @MainActor
    @Test func cardsAndCollectionsPersistAcrossReloads() async throws {
        SharedInbox.clearPendingCards()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SphirTest-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let controllerA = PersistenceController(storeURL: url)
        let storeA = AppStore(context: controllerA.container.viewContext, seedIfEmpty: false)
        let collection = storeA.addCollection(name: "Persisted Collection", privacy: .private)
        storeA.addCard(
            title: "Persisted Card",
            description: "",
            urlText: "https://persist.example",
            tagsText: "keep",
            type: .text,
            source: .url,
            collectionID: collection.id
        )

        // Reopen the same store with a fresh controller/context.
        let controllerB = PersistenceController(storeURL: url)
        let storeB = AppStore(context: controllerB.container.viewContext, seedIfEmpty: false)

        #expect(storeB.collections.contains { $0.name == "Persisted Collection" })
        #expect(storeB.cards.contains { $0.title == "Persisted Card" })
    }

    /// Editing a card updates its fields.
    @MainActor
    @Test func editingCardUpdatesFields() async throws {
        let store = makeStore()
        let first = try #require(store.collections.first)
        let created = store.addCard(
            title: "Old", description: "", urlText: "", tagsText: "",
            type: .text, source: .url, collectionID: first.id
        )

        var edited = created
        edited.title = "New Title"
        edited.content = "New content"
        edited.tags = ["a", "b"]
        store.updateCard(edited)

        let reloaded = try #require(store.cards.first { $0.id == created.id })
        #expect(reloaded.title == "New Title")
        #expect(reloaded.content == "New content")
        #expect(reloaded.tags == ["a", "b"])
    }

    /// OCR extracts text from an image (works on the Simulator, so the
    /// screenshot flow is testable without a camera or real screenshots).
    @MainActor
    @Test func ocrExtractsTextFromImage() async throws {
        let image = Self.renderTextImage("HELLO SPHIR")
        let text = await OCRService.recognizeText(in: image)
        let upper = text.uppercased()
        #expect(upper.contains("HELLO") || upper.contains("SPHIR"))
    }

    /// Render a plain image containing the given text for OCR testing.
    private static func renderTextImage(_ string: String) -> UIImage {
        let size = CGSize(width: 600, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 64),
                .foregroundColor: UIColor.black
            ]
            (string as NSString).draw(at: CGPoint(x: 40, y: 60), withAttributes: attributes)
        }
    }

    /// The deep-link parser handles custom-scheme and universal-link forms.
    @Test func parsesDeepLinks() async throws {
        let cardID = UUID()
        let collectionID = UUID()

        #expect(DeepLink(url: URL(string: "sphir://card/\(cardID.uuidString)")!) == .card(cardID))
        #expect(DeepLink(url: URL(string: "sphir://collection/\(collectionID.uuidString)")!) == .collection(collectionID))
        #expect(DeepLink(url: URL(string: "https://sphir.io/card/\(cardID.uuidString)")!) == .card(cardID))
        #expect(DeepLink(url: URL(string: "https://sphir.io/collection/\(collectionID.uuidString)")!) == .collection(collectionID))

        // Rejected forms.
        #expect(DeepLink(url: URL(string: "sphir://card/not-a-uuid")!) == nil)
        #expect(DeepLink(url: URL(string: "https://example.com/card/\(cardID.uuidString)")!) == nil)
        #expect(DeepLink(url: URL(string: "sphir://unknown/\(cardID.uuidString)")!) == nil)
    }

    /// The router resolves a card deep link into a collection + card path.
    @MainActor
    @Test func routerRoutesCardDeepLink() async throws {
        let store = makeStore()
        let card = try #require(store.cards.first)
        let router = NavigationRouter()

        router.handle(URL(string: "sphir://card/\(card.id.uuidString)")!, store: store)

        // collection (owning) + card
        #expect(router.path.count == 2)
    }

    /// The router resolves a collection deep link into a single-item path.
    @MainActor
    @Test func routerRoutesCollectionDeepLink() async throws {
        let store = makeStore()
        let collection = try #require(store.collections.first)
        let router = NavigationRouter()

        router.handle(URL(string: "sphir://collection/\(collection.id.uuidString)")!, store: store)

        #expect(router.path.count == 1)
    }

    /// Deleting a card removes it and decrements the collection count.
    @MainActor
    @Test func deletingCardRemovesItAndUpdatesCount() async throws {
        let store = makeStore()
        let first = try #require(store.collections.first)
        let created = store.addCard(
            title: "Doomed", description: "", urlText: "", tagsText: "",
            type: .text, source: .url, collectionID: first.id
        )
        let countAfterAdd = store.cards(in: first.id).count

        store.deleteCard(id: created.id)

        #expect(!store.cards.contains { $0.id == created.id })
        #expect(store.cards(in: first.id).count == countAfterAdd - 1)
    }

}
