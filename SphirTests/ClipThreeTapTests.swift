//
//  ClipThreeTapTests.swift
//  SphirTests
//
//  S8 contract: LinkPreview decoding, type mapping, "_<type>" tag round trip,
//  og_image mapping, shared-keychain migration.
//

import Testing
import Foundation
import Security
@testable import Sphir

struct ClipThreeTapTests {

    private func json(_ s: String) -> Data { Data(s.utf8) }

    @Test func linkPreviewDecodesFullS8() throws {
        let p = try JSONDecoder().decode(LinkPreview.self, from: json("""
        {"url":"https://shop.example.com/p/1","title":"Lamp","description":"Nice","image":"https://x.test/a.jpg",
         "type":"product","tags":["home","light"],"price":"$29.99","site":"shop.example.com","published":"2026-05-01"}
        """))
        #expect(p == LinkPreview(url: "https://shop.example.com/p/1", title: "Lamp", description: "Nice",
                                 image: "https://x.test/a.jpg", type: "product", tags: ["home", "light"],
                                 price: "$29.99", site: "shop.example.com", published: "2026-05-01"))
    }

    @Test func linkPreviewDecodesOldFourFieldJSON() throws {
        let p = try JSONDecoder().decode(LinkPreview.self, from: json(
            #"{"title":"T","description":"D","image":"","url":"https://a.test"}"#))
        #expect(p.title == "T" && p.description == "D" && p.url == "https://a.test")
        #expect(p.image == "" && p.type == "link" && p.tags.isEmpty)
        #expect(p.price == "" && p.site == "" && p.published == "")
    }

    @Test func previewTypeMapsToCardType() {
        #expect(CardType(previewType: "article") == .article)
        #expect(CardType(previewType: "product") == .product)
        #expect(CardType(previewType: "video") == .video)
        #expect(CardType(previewType: "recipe") == .recipe)
        #expect(CardType(previewType: "social") == .social)
        #expect(CardType(previewType: "link") == .text)
        #expect(CardType(previewType: "weird") == .text)
    }

    @Test func existingCardTypeRawValuesUnchanged() {
        #expect(CardType(rawValue: "text") == .text)
        #expect(CardType(rawValue: "media") == .media)
        #expect(CardType(rawValue: "business") == .business)
        #expect(CardType(rawValue: "product") == .product)
        #expect(CardType(rawValue: "originalScribe") == .originalScribe)
    }

    @Test func dtoReadsTypeTagAndOgImage() throws {
        let dto = try JSONDecoder().decode(BusinessDTO.self, from: json(
            #"{"id":7,"title":"T","website":"https://a.test","tags":["_video","cats"],"og_image":"https://x.test/i.jpg"}"#))
        let card = dto.toCard()
        #expect(card.cardType == .video)
        #expect(card.tags == ["cats"])
        #expect(card.imageURL == "https://x.test/i.jpg")
    }

    @Test func dtoWithoutTypeTagStaysBusiness() throws {
        let card = try JSONDecoder().decode(BusinessDTO.self, from: json(
            #"{"id":1,"title":"T","tags":["a"]}"#)).toCard()
        #expect(card.cardType == .business)
        #expect(card.tags == ["a"])
        #expect(card.imageURL == nil)
    }

    @Test func requestAddsTypeTagAndOgImageRoundTrip() throws {
        let card = Card(title: "T", content: "https://a.test", cardType: .recipe,
                        imageURL: "https://x.test/i.jpg", tags: ["dinner"])
        let data = try JSONEncoder().encode(BusinessRequest(card: card))
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(obj["tags"] as? [String] == ["dinner", "_recipe"])
        #expect(obj["og_image"] as? String == "https://x.test/i.jpg")
        let back = try JSONDecoder().decode(BusinessDTO.self, from: data).toCard()
        #expect(back.cardType == .recipe && back.tags == ["dinner"] && back.imageURL == "https://x.test/i.jpg")
    }

    @Test func requestOmitsNonHTTPImage() throws {
        let card = Card(title: "T", cardType: .text, imageURL: "file:///tmp/a.jpg")
        let data = try JSONEncoder().encode(BusinessRequest(card: card))
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(obj["og_image"] == nil)
    }

    /// Legacy (default access group) credentials are returned, moved to the shared
    /// group when it is usable, and removed on clear(). Uses an isolated service name.
    @Test func keychainMigratesLegacyItemAndClears() {
        let saved = (KeychainService.service, KeychainService.sharedAccessGroup)
        defer { (KeychainService.service, KeychainService.sharedAccessGroup) = saved }
        KeychainService.service = "com.Sphir.auth.test.\(UUID().uuidString)"
        let group = "group.com.sphir.shared"
        func legacyQuery() -> [String: Any] {
            [kSecClass as String: kSecClassGenericPassword,
             kSecAttrService as String: KeychainService.service,
             kSecAttrAccount as String: "access_token"]
        }
        var add = legacyQuery(); add[kSecValueData as String] = Data("tok".utf8)
        #expect(SecItemAdd(add as CFDictionary, nil) == errSecSuccess)

        #expect(KeychainService.load(.accessToken) == "tok")
        // Second read still works (from shared, or legacy if the group is unusable here).
        #expect(KeychainService.load(.accessToken) == "tok")

        var shared = legacyQuery(); shared[kSecAttrService as String] = KeychainService.service + ".shared"; shared[kSecAttrAccessGroup as String] = group
        let sharedHit = SecItemCopyMatching(shared as CFDictionary, nil) == errSecSuccess
        let legacyHit = SecItemCopyMatching(legacyQuery() as CFDictionary, nil) == errSecSuccess
        print("[TEST] keychain shared group usable: \(sharedHit); legacy still present: \(legacyHit)")
        if sharedHit { #expect(!legacyHit) }

        KeychainService.delete(.accessToken)
        #expect(KeychainService.load(.accessToken) == nil)
    }
}
