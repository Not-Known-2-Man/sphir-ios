//
//  AiCardsTests.swift
//  SphirTests
//
//  ai-cards T5 (S4, S6): the preview's already_on_sphir notice, the AI-filled
//  card and the suggested collection. Pure logic only; nothing reaches the API.
//

import Testing
import Foundation
@testable import Sphir

struct AiCardsTests {

    private func decode(_ s: String) throws -> LinkPreview {
        try JSONDecoder().decode(LinkPreview.self, from: Data(s.utf8))
    }

    @Test func decodesAlreadyOnSphirAiAndSuggestedCollection() throws {
        let p = try decode("""
        {"url":"https://a.test","title":"T","ai":true,"suggested_collection_id":42,
         "already_on_sphir":{"count":3,"title":"Stored","image":"https://x.test/i.jpg","price":"$9"}}
        """)
        #expect(p.ai == true)
        #expect(p.suggestedCollectionID == "42")
        #expect(p.alreadyOnSphir == AlreadyOnSphir(count: 3, title: "Stored", image: "https://x.test/i.jpg", price: "$9"))
    }

    @Test func decodesNullsAndOldResponsesWithoutTheNewFields() throws {
        let nulls = try decode(#"{"url":"https://a.test","already_on_sphir":null,"ai":false,"suggested_collection_id":null}"#)
        #expect(nulls.alreadyOnSphir == nil && nulls.ai == false && nulls.suggestedCollectionID == nil)
        let old = try decode(#"{"url":"https://a.test","title":"T"}"#)
        #expect(old.alreadyOnSphir == nil && old.ai == false && old.suggestedCollectionID == nil)
        let zero = try decode(#"{"url":"https://a.test","already_on_sphir":{"count":0,"title":"x"}}"#)
        #expect(zero.alreadyOnSphir == nil)
    }

    @Test func noticeCountsPeopleWithoutNames() {
        #expect(AlreadyOnSphir(count: 1, title: "", image: "", price: "").notice == "Already on Sphir · 1 person saved it")
        #expect(AlreadyOnSphir(count: 3, title: "", image: "", price: "").notice == "Already on Sphir · 3 people saved it")
    }

    @Test func storedCardFillsWhatThePageLacks() {
        var p = LinkPreview(url: "https://a.test/x", title: "", image: "", price: "")
        p.alreadyOnSphir = AlreadyOnSphir(count: 2, title: "Stored title", image: "https://x.test/i.jpg", price: "$9")
        let d = ClipDraft(preview: p, fallbackURL: "https://a.test/x")
        #expect(d.title == "Stored title")
        #expect(d.imageURL == "https://x.test/i.jpg")
        #expect(d.price == "$9")
    }

    @Test func pageValuesWinOverTheStoredCard() {
        var p = LinkPreview(url: "https://a.test/x", title: "Live", image: "https://x.test/live.jpg", price: "$5")
        p.alreadyOnSphir = AlreadyOnSphir(count: 2, title: "Stored", image: "https://x.test/i.jpg", price: "$9")
        let d = ClipDraft(preview: p, fallbackURL: "https://a.test/x")
        #expect(d.title == "Live" && d.imageURL == "https://x.test/live.jpg" && d.price == "$5")
    }

    @Test func suggestedCollectionWinsWhenAvailable() {
        #expect(FolderSelection.preselect(suggested: "7", lastUsed: "3", available: ["3", "7"]) == "7")
        #expect(FolderSelection.preselect(suggested: "99", lastUsed: "3", available: ["3", "7"]) == "3")
        #expect(FolderSelection.preselect(suggested: nil, lastUsed: "3", available: ["3", "7"]) == "3")
        #expect(FolderSelection.preselect(suggested: nil, lastUsed: nil, available: ["3", "7"]) == "3")
        #expect(FolderSelection.preselect(suggested: nil, lastUsed: nil, available: []) == nil)
    }
}
