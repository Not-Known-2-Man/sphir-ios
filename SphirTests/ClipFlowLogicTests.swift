//
//  ClipFlowLogicTests.swift
//  SphirTests
//
//  T4 pure logic for the three-tap share flow: Safari preprocessing result
//  parsing, preview -> card payload, save path choice, folder_ids composition,
//  and the POST /preview -> GET /preview fallback.
//

import Testing
import Foundation
@testable import Sphir

struct ClipFlowLogicTests {

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Preprocessing result

    private let safariResult: [String: Any] = [
        "url": "https://shop.example.com/p/1",
        "head": #"<head><meta property="og:title" content="Lamp"></head>"#,
        "jsonld": [#"{"@type":"Product","name":"Lamp"}"#]
    ]

    @Test func snapshotParsesWrappedSafariResult() throws {
        let raw: [String: Any] = ["NSExtensionJavaScriptPreprocessingResultsKey": safariResult]
        let snap = try #require(PageSnapshot.parse(raw))
        #expect(snap.url == "https://shop.example.com/p/1")
        #expect(snap.html.contains(#"<meta property="og:title" content="Lamp">"#))
        #expect(snap.html.contains(#"<script type="application/ld+json">{"@type":"Product","name":"Lamp"}</script>"#))
    }

    @Test func snapshotParsesUnwrappedResult() throws {
        let snap = try #require(PageSnapshot.parse(safariResult))
        #expect(snap.url == "https://shop.example.com/p/1")
        #expect(snap.html.contains("application/ld+json"))
    }

    @Test func snapshotRejectsMissingOrNonWebURL() {
        #expect(PageSnapshot.parse(nil) == nil)
        #expect(PageSnapshot.parse("nope") == nil)
        #expect(PageSnapshot.parse(["head": "<head></head>"]) == nil)
        #expect(PageSnapshot.parse(["url": "", "head": "<head></head>"]) == nil)
        #expect(PageSnapshot.parse(["url": "javascript:alert(1)", "head": "x"]) == nil)
        #expect(PageSnapshot.parse(["url": "file:///etc/hosts", "head": "x"]) == nil)
    }

    @Test func snapshotWithoutHeadOrJSONLDHasNoHTML() throws {
        let snap = try #require(PageSnapshot.parse(["url": "https://a.test/x"]))
        #expect(snap.url == "https://a.test/x")
        #expect(snap.html.isEmpty)
    }

    @Test func snapshotHTMLStaysUnderTheBodyLimit() throws {
        let huge = String(repeating: "a", count: 3_000_000)
        let snap = try #require(PageSnapshot.parse([
            "url": "https://a.test/x",
            "head": "<head>\(huge)</head>",
            "jsonld": [#"{"@type":"Recipe"}"#, huge]
        ]))
        #expect(snap.html.utf8.count <= PageSnapshot.maxHTMLBytes)
        // A small JSON-LD block survives a huge head; the oversized one is dropped.
        #expect(snap.html.contains(#"{"@type":"Recipe"}"#))
    }

    // MARK: - Preview -> card payload

    private let product = LinkPreview(
        url: "https://www.shop.example.com/p/1", title: "Lamp", description: "Nice lamp",
        image: "https://x.test/a.jpg", type: "product", tags: ["home", "_product", " light "],
        price: "$29.99", site: "shop.example.com", published: "2026-05-01")

    @Test func draftFromPreviewFillsTheCard() {
        let d = ClipDraft(preview: product, fallbackURL: "https://ignored.test")
        #expect(d.type == .product)
        #expect(d.typeLabel == "PRODUCT")
        #expect(d.title == "Lamp" && d.description == "Nice lamp")
        #expect(d.imageURL == "https://x.test/a.jpg")
        #expect(d.tags == ["home", "light"])
        #expect(d.price == "$29.99")
        #expect(d.url == "https://www.shop.example.com/p/1")
        #expect(d.sourceLine == "shop.example.com · May 1, 2026")
    }

    @Test func draftUsesFallbackURLAndHostWhenPreviewIsSparse() {
        let d = ClipDraft(preview: LinkPreview(title: "T"), fallbackURL: "https://www.example.com/a")
        #expect(d.url == "https://www.example.com/a")
        #expect(d.type == .text && d.typeLabel == "LINK")
        #expect(d.imageURL == nil && d.price == "")
        #expect(d.sourceLine == "example.com")
    }

    @Test func requestCarriesTypeTagPriceImageAndFolder() throws {
        let d = ClipDraft(preview: product, fallbackURL: "")
        let obj = try object(JSONEncoder().encode(d.request(folderServerID: "12")))
        #expect(obj["title"] as? String == "Lamp")
        #expect(obj["description"] as? String == "Nice lamp")
        #expect(obj["website"] as? String == "https://www.shop.example.com/p/1")
        #expect(obj["tags"] as? [String] == ["home", "light", "_product"])
        #expect(obj["price"] as? String == "$29.99")
        #expect(obj["og_image"] as? String == "https://x.test/a.jpg")
        #expect(obj["folder_id"] as? String == "12")
    }

    @Test func requestOmitsEmptyPriceAndImage() throws {
        let d = ClipDraft(preview: LinkPreview(url: "https://a.test", title: "T", type: "article"), fallbackURL: "")
        let obj = try object(JSONEncoder().encode(d.request(folderServerID: nil)))
        #expect(obj["price"] == nil)
        #expect(obj["og_image"] == nil)
        #expect(obj["tags"] as? [String] == ["_article"])
    }

    @Test func editedTitleAndDescriptionReachTheRequest() throws {
        var d = ClipDraft(preview: product, fallbackURL: "")
        d.title = "My lamp"; d.description = "Mine"
        let obj = try object(JSONEncoder().encode(d.request(folderServerID: "1")))
        #expect(obj["title"] as? String == "My lamp" && obj["description"] as? String == "Mine")
    }

    @Test func onDeviceFallbackTypeUsesDomainRulesOnly() {
        func type(_ url: String) -> CardType { ClipDraft(fallbackURL: url).type }
        #expect(type("https://www.youtube.com/watch?v=1") == .video)
        #expect(type("https://youtu.be/abc") == .video)
        #expect(type("https://vimeo.com/1") == .video)
        #expect(type("https://www.tiktok.com/@a/video/1") == .video)
        #expect(type("https://www.instagram.com/reel/Cx/") == .social)
        #expect(type("https://instagram.com/p/Cx/") == .social)
        #expect(type("https://www.instagram.com/someone/") == .text)
        #expect(type("https://x.com/a/status/1") == .social)
        #expect(type("https://twitter.com/a/status/1") == .social)
        #expect(type("https://www.facebook.com/a") == .social)
        #expect(type("https://www.threads.net/@a") == .social)
        #expect(type("https://example.com/amazing") == .text)
        #expect(ClipDraft(fallbackURL: "https://example.com").typeLabel == "LINK")
    }

    @Test func draftBuildsALocalCardWithoutTheTypeTag() {
        let d = ClipDraft(preview: product, fallbackURL: "")
        let id = UUID()
        let card = d.card(collectionID: id)
        #expect(card.cardType == .product && card.tags == ["home", "light"])
        #expect(card.content == "https://www.shop.example.com/p/1" && card.collectionID == id)
        #expect(card.imageURL == "https://x.test/a.jpg")
    }

    // MARK: - Save path

    @Test func savePathChoice() {
        #expect(ClipSavePath.choose(signedIn: true, folderServerID: "5") == .online(folderServerID: "5"))
        #expect(ClipSavePath.choose(signedIn: true, folderServerID: nil) == .queue(.noCollection))
        #expect(ClipSavePath.choose(signedIn: true, folderServerID: "") == .queue(.noCollection))
        #expect(ClipSavePath.choose(signedIn: false, folderServerID: "5") == .queue(.signedOut))
    }

    @Test func failuresFallBackToTheQueue() {
        #expect(ClipSavePath.queueReason(after: NetworkError.unauthorized) == .signedOut)
        #expect(ClipSavePath.queueReason(after: NetworkError.transport(URLError(.notConnectedToInternet))) == .failed)
        #expect(ClipSavePath.queueReason(after: NetworkError.server(status: 500, body: nil)) == .failed)
        #expect(ClipSavePath.queueReason(after: NetworkError.invalidURL) == .failed)
    }

    @Test func queueMessages() {
        #expect(ClipSavePath.QueueReason.failed.message == "Saved — it will sync when you open Sphir")
        #expect(ClipSavePath.QueueReason.noCollection.message == "Saved — it will sync when you open Sphir")
        #expect(ClipSavePath.QueueReason.signedOut.message == "Sign in to Sphir to clip")
        #expect(ClipSavePath.signInMessage == "Sign in to Sphir to clip")
        #expect(ClipSavePath.queuedMessage == "Saved — it will sync when you open Sphir")
    }

    // MARK: - Folder composition

    @Test func folderIDsPutThePrimaryFirstThenCollectionOrder() {
        let order = ["1", "2", "3", "4"]
        #expect(FolderSelection.compose(primary: "3", extras: ["1", "4"], order: order) == ["3", "1", "4"])
        #expect(FolderSelection.compose(primary: "2", extras: [], order: order) == ["2"])
    }

    @Test func folderIDsDropDuplicatesEmptiesAndUnknownOrder() {
        let order = ["1", "2"]
        #expect(FolderSelection.compose(primary: "1", extras: ["1", "2", ""], order: order) == ["1", "2"])
        // An extra missing from the collection list is kept (never silently lost), after the ordered ones.
        #expect(FolderSelection.compose(primary: "1", extras: ["9", "2"], order: order) == ["1", "2", "9"])
    }

    @Test func togglingNeverRemovesThePrimary() {
        #expect(FolderSelection.toggle("2", primary: "1", extras: []) == ["2"])
        #expect(FolderSelection.toggle("2", primary: "1", extras: ["2"]) == [])
        #expect(FolderSelection.toggle("1", primary: "1", extras: ["2"]) == ["2"])
    }

    @Test func chipTogglingAddsInOrderAndRemoves() {
        #expect(CollectionSelection.toggle("2", in: ["1"]) == ["1", "2"])
        #expect(CollectionSelection.toggle("3", in: ["1", "2"]) == ["1", "2", "3"])
        #expect(CollectionSelection.toggle("1", in: ["1", "2"]) == ["2"])
        #expect(CollectionSelection.toggle("2", in: ["1", "2", "3"]) == ["1", "3"])
    }

    @Test func chipTogglingKeepsTheLastSelectedOne() {
        #expect(CollectionSelection.toggle("1", in: ["1"]) == ["1"])
        #expect(CollectionSelection.toggle("1", in: []) == ["1"])
    }

    @Test func primaryChipIsTheFirstSelected() {
        #expect(CollectionSelection.primary(of: ["3", "1"]) == "3")
        #expect(CollectionSelection.primary(of: CollectionSelection.toggle("3", in: ["3", "1"])) == "1")
        #expect(CollectionSelection.primary(of: []) == nil)
    }

    @Test func preselectsLastUsedCollectionElseFirst() {
        #expect(FolderSelection.preselect(lastUsed: "3", available: ["1", "2", "3"]) == "3")
        #expect(FolderSelection.preselect(lastUsed: "9", available: ["1", "2"]) == "1")
        #expect(FolderSelection.preselect(lastUsed: nil, available: ["1", "2"]) == "1")
        #expect(FolderSelection.preselect(lastUsed: "1", available: []) == nil)
    }

    @Test func foldersRequestEncodesNumericIDs() throws {
        let obj = try object(JSONEncoder().encode(BusinessFoldersRequest(folderIDs: ["12", "3"])))
        #expect(obj["folder_ids"] as? [Int] == [12, 3])
    }

    @Test func dtoDecodesPriceAndFolderIDs() throws {
        let dto = try JSONDecoder().decode(BusinessDTO.self, from: Data(
            #"{"id":7,"title":"T","price":"$5","folder_id":2,"folder_ids":[2,"3"]}"#.utf8))
        #expect(dto.price == "$5")
        #expect(dto.folderServerIDs == ["2", "3"])
        let old = try JSONDecoder().decode(BusinessDTO.self, from: Data(#"{"id":1,"title":"T","folder_id":4}"#.utf8))
        #expect(old.price == "" && old.folderServerIDs == ["4"])
    }

    @Test func pickerListMatchesServerFoldersToLocalCollections() {
        let local = UUID()
        let folders = [Collection(name: "Recipes", cardCount: 0, serverID: "10"),
                       Collection(name: "Travel", cardCount: 0, serverID: "11"),
                       Collection(name: "NoID", cardCount: 0)]
        let shared = [SharedCollectionDTO(id: local, name: "recipes")]
        let list = ClipCollection.pickerList(folders: folders, shared: shared)
        #expect(list.map(\.name) == ["Recipes", "Travel"])
        #expect(list.map(\.serverID) == ["10", "11"])
        #expect(list[0].localID == local && list[1].localID == nil)
    }
}

// MARK: - POST /preview -> GET /preview

private final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, String))?
    nonisolated(unsafe) static var seen: [String] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, body) = StubProtocol.handler?(request) ?? (500, "")
        StubProtocol.seen.append("\(request.httpMethod ?? "?") \(request.url?.path ?? "")")
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized)
struct PreviewFallbackTests {
    private func service() -> NetworkService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        StubProtocol.seen = []
        return NetworkService(session: URLSession(configuration: config))
    }
    private let ok = #"{"url":"https://a.test","title":"T","type":"recipe","tags":["x"]}"#

    @Test func postsTheHTMLWhenAvailable() async throws {
        StubProtocol.handler = { _ in (200, ok) }
        let p = try await service().preview(url: "https://a.test", html: "<head></head>")
        #expect(p.type == "recipe" && p.title == "T")
        #expect(StubProtocol.seen == ["POST /api/v1/preview"])
    }

    @Test func fallsBackToGETWhenPOSTIsMissing() async throws {
        StubProtocol.handler = { $0.httpMethod == "POST" ? (404, #"{"error":"Not found"}"#) : (200, ok) }
        let p = try await service().preview(url: "https://a.test", html: "<head></head>")
        #expect(p.title == "T")
        #expect(StubProtocol.seen == ["POST /api/v1/preview", "GET /api/v1/preview"])
    }

    @Test func usesGETWithoutHTML() async throws {
        StubProtocol.handler = { _ in (200, ok) }
        _ = try await service().preview(url: "https://a.test", html: nil)
        _ = try await service().preview(url: "https://a.test", html: "")
        #expect(StubProtocol.seen == ["GET /api/v1/preview"])
    }

    @Test func surfacesTheErrorWhenGETFailsToo() async {
        StubProtocol.handler = { _ in (422, #"{"error":"Could not fetch metadata"}"#) }
        await #expect(throws: NetworkError.self) {
            _ = try await service().preview(url: "https://a.test", html: "<head></head>")
        }
    }
}
