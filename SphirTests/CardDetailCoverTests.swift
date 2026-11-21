//
//  CardDetailCoverTests.swift
//  SphirTests
//
//  Card detail shows the remote cover (og_image) when the card has no local image data.
//

import Testing
import Foundation
@testable import Sphir

struct CardDetailCoverTests {

    @Test func remoteCoverUsesTheCardImageURL() {
        let card = Card(title: "Shoe", imageURL: "https://cdn.shop.com/shoe.png")
        #expect(CardDetailView.remoteCoverURL(for: card) == URL(string: "https://cdn.shop.com/shoe.png"))
    }

    @Test func remoteCoverUpgradesHttpToHttps() {
        let card = Card(title: "Shoe", imageURL: "http://cdn.shop.com/shoe.png")
        #expect(CardDetailView.remoteCoverURL(for: card) == URL(string: "https://cdn.shop.com/shoe.png"))
    }

    @Test func noRemoteCoverWithoutAnHttpImageURL() {
        #expect(CardDetailView.remoteCoverURL(for: Card(title: "Note")) == nil)
        #expect(CardDetailView.remoteCoverURL(for: Card(title: "Note", imageURL: "")) == nil)
        #expect(CardDetailView.remoteCoverURL(for: Card(title: "Note", imageURL: "data:image/png;base64,AAA")) == nil)
    }
}
