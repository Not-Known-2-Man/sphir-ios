//
//  CardDetailInfoTests.swift
//  SphirTests
//
//  card-detail-info T2 (S4): `site` and `published` flow from the API and the
//  link preview into Card, the BusinessRequest, the clip draft and the offline
//  queue, and stay tolerant when a source does not have them.
//

import Testing
import Foundation
@testable import Sphir

struct CardDetailInfoTests {

    private func dto(_ json: String) throws -> BusinessDTO {
        try JSONDecoder().decode(BusinessDTO.self, from: Data(json.utf8))
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func preview() -> LinkPreview {
        LinkPreview(url: "https://shop.example.com/p/1", title: "Lamp",
                    site: "Example Shop", published: "2026-02-11")
    }

    // MARK: - Card

    @Test func cardDefaultsToEmptySiteAndPublished() {
        let card = Card(title: "T")
        #expect(card.site == "")
        #expect(card.published == "")
    }

    // MARK: - BusinessDTO

    @Test func dtoDecodesSiteAndPublished() throws {
        let d = try dto(#"{"id":1,"title":"T","site":"Example Shop","published":"2026-02-11"}"#)
        #expect(d.site == "Example Shop")
        #expect(d.published == "2026-02-11")
    }

    @Test func dtoMissingKeysGiveEmptyStrings() throws {
        let d = try dto(#"{"id":1,"title":"T"}"#)
        #expect(d.site == "")
        #expect(d.published == "")
        let wrong = try dto(#"{"id":1,"title":"T","site":5,"published":null}"#)
        #expect(wrong.site == "")
        #expect(wrong.published == "")
    }

    @Test func toCardCarriesSiteAndPublished() throws {
        let card = try dto(#"{"id":1,"title":"T","site":"Example Shop","published":"2026-02-11"}"#).toCard()
        #expect(card.site == "Example Shop")
        #expect(card.published == "2026-02-11")
    }

    // MARK: - BusinessRequest

    @Test func requestEncodesSiteAndPublishedWhenSet() throws {
        let card = Card(title: "T", site: "Example Shop", published: "2026-02-11")
        let obj = try object(JSONEncoder().encode(BusinessRequest(card: card)))
        #expect(obj["site"] as? String == "Example Shop")
        #expect(obj["published"] as? String == "2026-02-11")
    }

    @Test func requestOmitsSiteAndPublishedWhenEmpty() throws {
        let obj = try object(JSONEncoder().encode(BusinessRequest(card: Card(title: "T"))))
        #expect(obj["site"] == nil)
        #expect(obj["published"] == nil)
    }

    // MARK: - Clip flow

    @Test func draftCardAndRequestCarrySiteAndPublished() throws {
        let draft = ClipDraft(preview: preview(), fallbackURL: "https://x.test")
        let card = draft.card()
        #expect(card.site == "Example Shop")
        #expect(card.published == "2026-02-11")
        let obj = try object(JSONEncoder().encode(draft.request(folderServerID: nil)))
        #expect(obj["site"] as? String == "Example Shop")
        #expect(obj["published"] as? String == "2026-02-11")
    }

    @Test func draftPayloadCarriesSiteAndPublished() {
        let payload = ClipDraft(preview: preview(), fallbackURL: "https://x.test")
            .payload(collectionID: nil, imageData: nil)
        #expect(payload.site == "Example Shop")
        #expect(payload.published == "2026-02-11")
        let bare = ClipDraft(preview: LinkPreview(url: "https://x.test/a", title: "A"), fallbackURL: "")
            .payload(collectionID: nil, imageData: nil)
        #expect(bare.published == nil)
    }

    // MARK: - Offline queue

    @Test func sharedCardWithoutKeysStillDecodes() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"Old","description":"","urlString":"https://a.test","bodyText":"","sourceAppRaw":"safari","createdAt":0}"#
        let dto = try JSONDecoder().decode(SharedCardDTO.self, from: Data(json.utf8))
        #expect(dto.site == nil)
        #expect(dto.published == nil)
        let card = AppStore.card(fromShared: dto, collectionID: nil)
        #expect(card.site == "")
        #expect(card.published == "")
    }

    @Test func cardFromSharedCarriesSiteAndPublished() {
        let dto = SharedCardDTO(id: UUID(), title: "T", urlString: "https://a.test", collectionID: nil,
                                createdAt: Date(), site: "Example Shop", published: "2026-02-11")
        let card = AppStore.card(fromShared: dto, collectionID: nil)
        #expect(card.site == "Example Shop")
        #expect(card.published == "2026-02-11")
        let round = try? JSONDecoder().decode(SharedCardDTO.self, from: JSONEncoder().encode(dto))
        #expect(round?.site == "Example Shop")
        #expect(round?.published == "2026-02-11")
    }
}
