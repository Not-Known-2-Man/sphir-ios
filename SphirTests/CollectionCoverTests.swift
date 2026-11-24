//
//  CollectionCoverTests.swift
//  SphirTests
//
//  Unit tests for CollectionCover helper.
//

import Testing
import Foundation
@testable import Sphir

struct CollectionCoverTests {

    @Test func noCardsReturnsEmpty() {
        let cards: [Card] = []
        let sources = CollectionCover.sources(for: cards)
        #expect(sources.isEmpty)
    }

    @Test func cardsWithoutAnyImageReturnsEmpty() {
        let cards = [
            Card(title: "1", imageURL: nil, imageData: nil),
            Card(title: "2", imageURL: nil, imageData: nil)
        ]
        let sources = CollectionCover.sources(for: cards)
        #expect(sources.isEmpty)
    }

    @Test func fiveCardsWithImagesReturnsFirstThreeInOrder() {
        let cards = (1...5).map { index in
            Card(title: "Card \(index)", imageData: Data([UInt8(index)]))
        }
        let sources = CollectionCover.sources(for: cards)
        #expect(sources == [
            .localData(Data([1])),
            .localData(Data([2])),
            .localData(Data([3]))
        ])
    }

    @Test func mixedCardsDropsCardsWithoutImages() {
        let cardNoImage1 = Card(title: "No Image 1")
        let cardA = Card(title: "Card A", imageURL: "https://example.com/a.jpg")
        let cardNoImage2 = Card(title: "No Image 2")
        let cardB = Card(title: "Card B", imageData: Data([0xAA, 0xBB]))

        let sources = CollectionCover.sources(for: [cardNoImage1, cardA, cardNoImage2, cardB])
        #expect(sources == [
            .remoteURL(URL(string: "https://example.com/a.jpg")!),
            .localData(Data([0xAA, 0xBB]))
        ])
    }

    @Test func localDataAndRemoteURLYieldExpectedSources() {
        let localData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let localCard = Card(title: "Local", imageData: localData)
        let remoteCard = Card(title: "Remote", imageURL: "https://example.com/cover.png")

        let sources = CollectionCover.sources(for: [localCard, remoteCard])
        #expect(sources == [
            .localData(localData),
            .remoteURL(URL(string: "https://example.com/cover.png")!)
        ])
    }
}
