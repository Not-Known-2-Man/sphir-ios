//
//  ThumbnailActionsTests.swift
//  SphirTests
//
//  What the share action on a card or collection thumbnail sends outside Sphir.
//

import Testing
import Foundation
@testable import Sphir

struct ThumbnailActionsTests {

    // MARK: - Card

    @Test func cardWithLinkSharesTheLink() {
        let card = Card(title: "Lamp", content: "https://shop.example.com/p/1")
        #expect(ShareContent.item(for: card) == .url(URL(string: "https://shop.example.com/p/1")!))
    }

    @Test func cardWithBareDomainSharesItAsHTTPS() {
        let card = Card(title: "Apple", content: "apple.com")
        #expect(ShareContent.item(for: card) == .url(URL(string: "https://apple.com")!))
    }

    @Test func cardWithoutLinkSharesTitleAndDescription() {
        let card = Card(title: "My idea", description: "Notes about it", content: "just text")
        #expect(ShareContent.item(for: card) == .text("My idea\n\nNotes about it"))
    }

    @Test func cardWithoutLinkOrDescriptionSharesTheTitle() {
        let card = Card(title: "My idea")
        #expect(ShareContent.item(for: card) == .text("My idea"))
    }

    // MARK: - Collection

    @Test func collectionSharesNameDescriptionAndEveryCard() {
        let collection = Collection(name: "Reading", description: "Books to read", cardCount: 2)
        let cards = [
            Card(title: "Dune", content: "https://books.example.com/dune"),
            Card(title: "My notes")
        ]
        #expect(ShareContent.text(for: collection, cards: cards) ==
            "Reading\nBooks to read\n\n• Dune: https://books.example.com/dune\n• My notes")
    }

    @Test func emptyCollectionWithoutDescriptionSharesItsName() {
        let collection = Collection(name: "Empty", cardCount: 0)
        #expect(ShareContent.text(for: collection, cards: []) == "Empty")
    }
}
