//
//  CardDetailCoverTests.swift
//  SphirTests
//
//  Tests for card cover source selection, link card badges, Buy Now eligibility,
//  and footer row text formatting.
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

    @Test func coverSourcePrioritizesLocalImageData() {
        let dummyData = Data([0x89, 0x50, 0x4E, 0x47])
        let card = Card(
            title: "Local Image",
            imageURL: "https://example.com/cover.png",
            imageData: dummyData
        )
        #expect(CardDetailView.coverSource(for: card) == .localData(dummyData))
    }

    @Test func coverSourceFallsBackToRemoteURL() {
        let card = Card(
            title: "Remote Cover",
            imageURL: "https://example.com/cover.png",
            imageData: nil
        )
        #expect(CardDetailView.coverSource(for: card) == .remoteURL(URL(string: "https://example.com/cover.png")!))
    }

    @Test func coverSourceUsesPlaceholderWhenNoImagesExist() {
        let card = Card(title: "Text Only", imageURL: nil, imageData: nil)
        #expect(CardDetailView.coverSource(for: card) == .placeholder)
    }

    @Test func isLinkCardIdentifiesLinksFromSafariOrURLContent() {
        let safariCard = Card(title: "Safari Card", sourceApp: .safari)
        #expect(CardDetailView.isLinkCard(safariCard) == true)

        let linkContentCard = Card(
            title: "Linked Card",
            content: "https://apple.com/iphone",
            sourceApp: .photos
        )
        #expect(CardDetailView.isLinkCard(linkContentCard) == true)

        let plainNoteCard = Card(
            title: "Plain Note",
            content: "Just some notes without URLs",
            sourceApp: .own
        )
        #expect(CardDetailView.isLinkCard(plainNoteCard) == false)
    }

    @Test func canBuyNowRequiresProductWithPriceAndURL() {
        let validProduct = Card(
            title: "The Sprouter",
            content: "https://thesproutingcompany.com",
            cardType: .product,
            price: "$99.99"
        )
        let canBuyValid = CardDetailView.canBuyNow(validProduct)
        #expect(canBuyValid)

        let productNoPrice = Card(
            title: "The Sprouter",
            content: "https://thesproutingcompany.com",
            cardType: .product,
            price: ""
        )
        let canBuyNoPrice = CardDetailView.canBuyNow(productNoPrice)
        #expect(!canBuyNoPrice)

        let productNoURL = Card(
            title: "The Sprouter",
            content: "Just a description",
            cardType: .product,
            price: "$99.99"
        )
        let canBuyNoURL = CardDetailView.canBuyNow(productNoURL)
        #expect(!canBuyNoURL)

        let articleWithPrice = Card(
            title: "Magazine Issue",
            content: "https://magazine.com",
            cardType: .article,
            price: "$10.00"
        )
        let canBuyArticle = CardDetailView.canBuyNow(articleWithPrice)
        #expect(!canBuyArticle)
    }

    @Test func footerTextFormatsSafariAndOtherSources() {
        let safariCard = Card(
            title: "Web Link",
            sourceApp: .safari,
            createdAt: Date(timeIntervalSince1970: 1_710_000_000)
        )
        let safariFooter = CardDetailView.footerText(for: safariCard)
        #expect(safariFooter.starts(with: "Saved from Safari · "))

        let photosCard = Card(
            title: "Photo",
            sourceApp: .photos,
            createdAt: Date(timeIntervalSince1970: 1_710_000_000)
        )
        let photosFooter = CardDetailView.footerText(for: photosCard)
        #expect(photosFooter.starts(with: "Saved from Photos · "))
    }

    // MARK: card-detail-info (S5-S7)

    @Test func sourceRowShowsSiteAndDomain() {
        let card = Card(title: "t", content: "https://www.theverge.com/a", site: "The Verge")
        #expect(CardDetailView.sourceRowText(for: card) == "The Verge · theverge.com")
    }

    @Test func sourceRowFallsBackToDomainWhenSiteMissingOrEqual() {
        let none = Card(title: "t", content: "https://www.theverge.com/a")
        #expect(CardDetailView.sourceRowText(for: none) == "theverge.com")
        let same = Card(title: "t", content: "https://theverge.com/a", site: "WWW.TheVerge.com")
        #expect(CardDetailView.sourceRowText(for: same) == "theverge.com")
    }

    @Test func sourceRowIsNilWithoutLink() {
        #expect(CardDetailView.sourceRowText(for: Card(title: "t", content: "just a note", site: "X")) == nil)
    }

    @Test func publishedTextFormatsValidDatesOnly() {
        #expect(CardDetailView.publishedText("2024-03-05") == "Published Mar 5, 2024")
        #expect(CardDetailView.publishedText("") == nil)
        #expect(CardDetailView.publishedText("2024-13-45") == nil)
        #expect(CardDetailView.publishedText("garbage") == nil)
    }

    @Test func collectionsForCardIncludesPrimaryAndFolders() {
        let a = Collection(name: "A", cardCount: 0, serverID: "fa")
        let b = Collection(name: "B", cardCount: 0, serverID: "fb")
        let c = Collection(name: "C", cardCount: 0, serverID: "fc")
        let card = Card(title: "t", collectionID: a.id, folderServerIDs: ["fa", "fc"])
        #expect(CardDetailView.collections(for: card, in: [a, b, c]).map(\.name) == ["A", "C"])
        let loose = Card(title: "t")
        #expect(CardDetailView.collections(for: loose, in: [a, b, c]).isEmpty)
    }
}
