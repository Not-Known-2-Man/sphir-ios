//
//  CardCustomImageTests.swift
//  SphirTests
//
//  card-custom-image: upload endpoint, JPEG resize under the API limit,
//  og_image on update/removal, and AppStore persisting the changed image.
//  All network and Keychain access is replaced by stubs / injected fakes.
//

import Testing
import Foundation
import CoreData
import UIKit
@testable import Sphir

// MARK: - Stub URLSession

private final class ImageStubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 201
    nonisolated(unsafe) static var responseBody = #"{"id":"abc","url":"https://api.test/api/v1/images/abc"}"#
    nonisolated(unsafe) static var requests: [(method: String, path: String, body: Data?, contentType: String?)] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 65_536)
            while stream.hasBytesAvailable {
                let n = stream.read(&buffer, maxLength: buffer.count)
                if n <= 0 { break }
                data.append(buffer, count: n)
            }
            stream.close()
            body = data
        }
        Self.requests.append((request.httpMethod ?? "?", request.url?.path ?? "", body,
                              request.value(forHTTPHeaderField: "Content-Type")))
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.responseBody.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func stubService() -> NetworkService {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ImageStubProtocol.self]
    ImageStubProtocol.status = 201
    ImageStubProtocol.responseBody = #"{"id":"abc","url":"https://api.test/api/v1/images/abc"}"#
    ImageStubProtocol.requests = []
    return NetworkService(session: URLSession(configuration: config))
}

/// A noisy image so JPEG cannot compress it to almost nothing.
private func noisyImageData(side: Int) -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { ctx in
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<4000 {
            ctx.cgContext.setFillColor(UIColor(red: .random(in: 0...1, using: &rng), green: .random(in: 0...1, using: &rng),
                                               blue: .random(in: 0...1, using: &rng), alpha: 1).cgColor)
            let s = CGFloat.random(in: 2...40, using: &rng)
            ctx.cgContext.fill(CGRect(x: .random(in: 0...CGFloat(side), using: &rng),
                                      y: .random(in: 0...CGFloat(side), using: &rng), width: s, height: s))
        }
    }
    return image.pngData()!
}

private func requestObject(_ body: Data?) throws -> [String: Any] {
    let data = try #require(body)
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

@Suite(.serialized)
struct CardImageAPITests {
    // MARK: S2 / S5 upload

    @Test func uploadPostsTheJPEGAsADataURLAndReturnsTheURL() async throws {
        let service = stubService()
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3])

        let url = try await CardAPIService.uploadImage(jpeg, using: service)

        #expect(url == "https://api.test/api/v1/images/abc")
        let sent = try #require(ImageStubProtocol.requests.first)
        #expect(ImageStubProtocol.requests.count == 1)
        #expect(sent.method == "POST" && sent.path == "/api/v1/images")
        #expect(sent.contentType == "application/json")
        let json = try requestObject(sent.body)
        #expect(json.keys.sorted() == ["data"])
        #expect(json["data"] as? String == "data:image/jpeg;base64,\(jpeg.base64EncodedString())")
    }

    @Test func uploadFailureThrowsAndReturnsNoURL() async {
        let service = stubService()
        ImageStubProtocol.status = 422
        ImageStubProtocol.responseBody = #"{"error":"too large"}"#
        await #expect(throws: NetworkError.self) {
            _ = try await CardAPIService.uploadImage(Data([1, 2, 3]), using: service)
        }
    }

    @Test func uploadWithoutAURLInTheResponseThrows() async {
        let service = stubService()
        ImageStubProtocol.responseBody = #"{"id":"abc"}"#
        await #expect(throws: (any Error).self) {
            _ = try await CardAPIService.uploadImage(Data([1, 2, 3]), using: service)
        }
    }

    // MARK: S5 resize

    @Test func largeImageIsResizedToAJPEGUnderTheBudget() throws {
        let raw = noisyImageData(side: 3000)
        let jpeg = try #require(ImageCompression.jpegForUpload(raw))
        #expect(jpeg.count <= ImageCompression.maxBytes)
        #expect(ImageCompression.maxBytes <= 1_400_000)
        #expect(Array(jpeg.prefix(2)) == [0xFF, 0xD8])
        let decoded = try #require(UIImage(data: jpeg))
        #expect(max(decoded.size.width * decoded.scale, decoded.size.height * decoded.scale) <= ImageCompression.maxDimension)
    }

    @Test func smallImageKeepsItsSizeAndBecomesJPEG() throws {
        let jpeg = try #require(ImageCompression.jpegForUpload(noisyImageData(side: 300)))
        let decoded = try #require(UIImage(data: jpeg))
        #expect(Int(decoded.size.width * decoded.scale) == 300)
        #expect(Array(jpeg.prefix(2)) == [0xFF, 0xD8])
    }

    @Test func nonImageDataGivesNoJPEG() {
        #expect(ImageCompression.jpegForUpload(Data([1, 2, 3])) == nil)
    }

    // MARK: S3 og_image on update

    private func card(imageURL: String?) -> Card {
        Card(title: "T", description: "d", content: "c", cardType: .text, sourceApp: .safari,
             imageURL: imageURL, serverID: "9")
    }

    private func sentUpdate(_ card: Card, _ change: CardImageChange?) async throws -> [String: Any] {
        let service = stubService()
        ImageStubProtocol.responseBody = #"{"id":9,"title":"T"}"#
        ImageStubProtocol.status = 200
        if let change {
            try await CardAPIService.updateCard(serverID: "9", card: card, imageChange: change, using: service)
        } else {
            try await CardAPIService.updateCard(serverID: "9", card: card, using: service)
        }
        let sent = try #require(ImageStubProtocol.requests.first)
        #expect(sent.method == "PUT" && sent.path == "/api/v1/businesses/9")
        return try requestObject(sent.body)
    }

    @Test func titleOnlyUpdateStillOmitsOgImage() async throws {
        let withImage = try await sentUpdate(card(imageURL: "https://img.test/a.jpg"), nil)
        #expect(withImage["og_image"] == nil)
        let noImage = try await sentUpdate(card(imageURL: nil), .unchanged)
        #expect(noImage["og_image"] == nil)
        #expect(noImage["title"] as? String == "T")
    }

    @Test func replacedImageSendsTheNewURL() async throws {
        let json = try await sentUpdate(card(imageURL: "https://api.test/api/v1/images/new"), .replaced)
        #expect(json["og_image"] as? String == "https://api.test/api/v1/images/new")
    }

    @Test func explicitRemovalSendsAnEmptyOgImage() async throws {
        let json = try await sentUpdate(card(imageURL: nil), .removed)
        #expect(json["og_image"] as? String == "")
    }

    @Test func createRequestKeepsItsOgImageBehavior() throws {
        let withURL = BusinessRequest(card: card(imageURL: "https://img.test/a.jpg"))
        let without = BusinessRequest(card: card(imageURL: nil))
        let a = try requestObject(try JSONEncoder().encode(withURL))
        let b = try requestObject(try JSONEncoder().encode(without))
        #expect(a["og_image"] as? String == "https://img.test/a.jpg")
        #expect(b["og_image"] == nil)
    }
}

// MARK: - AppStore.updateCard

@MainActor
@Suite(.serialized)
struct CardImageStoreTests {
    private final class Spy {
        var plain: [String] = []
        var withImage: [(String, CardImageChange, String?)] = []
    }
    private let spy = Spy()
    private let store: AppStore

    init() {
        let spy = spy
        store = AppStore(
            context: PersistenceController(inMemory: true).container.viewContext,
            seedIfEmpty: false,
            hasCredentials: { true },
            fetchFolders: { throw URLError(.notConnectedToInternet) },
            fetchCards: { throw URLError(.notConnectedToInternet) },
            updateCardAPI: { id, card in spy.plain.append("\(id):\(card.title)") },
            updateCardImageAPI: { id, card, change in spy.withImage.append((id, change, card.imageURL)) }
        )
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<300 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func makeCard(imageURL: String? = nil, imageData: Data? = nil) -> Card {
        let id = store.addClipCard(SharePayload(collectionID: nil, title: "Old", description: "", urlString: "https://a.test",
                                                bodyText: nil, imageData: imageData, tags: [], imageURL: imageURL))
        return store.cards.first { $0.id == id }!
    }

    private func synced(_ card: Card) -> Card {
        var c = store.cards.first { $0.id == card.id }!
        c.serverID = "S1"
        return c
    }

    @Test func replacedImagePersistsTheURLAndClearsTheLocalData() async throws {
        let created = makeCard(imageURL: "https://old.test/a.jpg", imageData: Data([1, 2, 3]))
        var edited = synced(created)
        edited.imageURL = "https://api.test/api/v1/images/new"
        edited.imageData = nil

        store.updateCard(edited, imageChange: .replaced)

        let stored = try #require(store.cards.first { $0.id == created.id })
        #expect(stored.imageURL == "https://api.test/api/v1/images/new")
        #expect(stored.imageData == nil)
        #expect(await waitUntil { spy.withImage.count == 1 })
        #expect(spy.withImage.first?.1 == .replaced)
        #expect(spy.withImage.first?.2 == "https://api.test/api/v1/images/new")
        #expect(spy.plain.isEmpty)
    }

    @Test func removedImageClearsBothAndSendsRemoval() async throws {
        let created = makeCard(imageURL: "https://old.test/a.jpg", imageData: Data([1, 2, 3]))
        var edited = synced(created)
        edited.imageURL = nil
        edited.imageData = nil

        store.updateCard(edited, imageChange: .removed)

        let stored = try #require(store.cards.first { $0.id == created.id })
        #expect(stored.imageURL == nil && stored.imageData == nil)
        #expect(await waitUntil { spy.withImage.count == 1 })
        #expect(spy.withImage.first?.1 == .removed)
    }

    @Test func titleOnlyUpdateKeepsTheImageAndUsesTheOriginalUpdater() async throws {
        let created = makeCard(imageURL: "https://old.test/a.jpg", imageData: Data([1, 2, 3]))
        var edited = synced(created)
        edited.title = "New"
        edited.imageURL = nil      // ignored: the image did not change
        edited.imageData = nil

        store.updateCard(edited)

        let stored = try #require(store.cards.first { $0.id == created.id })
        #expect(stored.title == "New")
        #expect(stored.imageURL == "https://old.test/a.jpg")
        #expect(stored.imageData == Data([1, 2, 3]))
        #expect(await waitUntil { spy.plain.count == 1 })
        #expect(spy.plain == ["S1:New"])
        #expect(spy.withImage.isEmpty)
    }

    @Test func replacedImageSurvivesASyncThatReturnsTheNewURL() async throws {
        let created = makeCard(imageURL: "https://old.test/a.jpg", imageData: Data([1, 2, 3]))
        var edited = synced(created)
        edited.imageURL = "https://api.test/api/v1/images/new"
        edited.imageData = nil
        store.updateCard(edited, imageChange: .replaced)

        let dto = try JSONDecoder().decode(BusinessDTO.self, from: Data(
            #"{"id":"S1","title":"Old","og_image":"https://api.test/api/v1/images/new"}"#.utf8))
        store.reconcileCards([dto])

        let stored = try #require(store.cards.first { $0.id == created.id })
        #expect(stored.imageURL == "https://api.test/api/v1/images/new")
        #expect(stored.imageData == nil)
    }
}

// MARK: - Clip screen (ClipFlowModel)

@MainActor
@Suite(.serialized)
struct ClipCustomImageTests {
    private struct Boom: Error {}

    private func makeModel(
        signedIn: Bool = true,
        upload: @escaping @MainActor (Data) async throws -> String,
        create: @escaping @MainActor (BusinessRequest) async throws -> BusinessDTO = { _ in
            try JSONDecoder().decode(BusinessDTO.self, from: Data(#"{"id":"77","title":"T"}"#.utf8))
        },
        queue: @escaping @MainActor (SharePayload) -> UUID = { _ in UUID() }
    ) -> ClipFlowModel {
        let model = ClipFlowModel(
            content: SharedContent(urlString: "https://example.com/x"),
            sharedCollections: [], inApp: true, signedIn: signedIn,
            queue: queue, uploadImage: upload, createCardRequest: create)
        model.phase = .preview
        model.collections = [ClipCollection(name: "Reading", serverID: "1", localID: nil)]
        model.selectedIDs = ["1"]
        return model
    }

    private func jpegSample() -> Data { ImageCompression.jpegForUpload(noisyImageData(side: 200))! }

    @Test func pickedImageShowsAtOnceAsAJPEGCover() throws {
        let model = makeModel(upload: { _ in "unused" })
        model.draft.imageURL = "https://og.test/old.jpg"

        model.pickImage(noisyImageData(side: 3000))   // PNG in, JPEG out

        let cover = try #require(model.coverData)
        #expect(Array(cover.prefix(2)) == [0xFF, 0xD8])
        #expect(cover.count <= ImageCompression.maxBytes)
        #expect(model.hasPickedImage)
    }

    @Test func nonImageDataLeavesTheCoverUntouched() {
        let model = makeModel(upload: { _ in "unused" })
        model.coverData = Data([9])
        model.pickImage(Data([1, 2, 3]))
        #expect(model.coverData == Data([9]))
        #expect(!model.hasPickedImage)
    }

    @Test func saveUploadsThePickedImageAndSendsItsURLAsOgImage() async throws {
        var uploaded: [Data] = []
        var requests: [BusinessRequest] = []
        var queued = 0
        let model = makeModel(
            upload: { uploaded.append($0); return "https://api.test/api/v1/images/new" },
            create: { requests.append($0); return try JSONDecoder().decode(BusinessDTO.self, from: Data(#"{"id":"77"}"#.utf8)) },
            queue: { _ in queued += 1; return UUID() })
        model.draft.imageURL = "https://og.test/old.jpg"
        model.pickImage(noisyImageData(side: 400))
        let picked = try #require(model.coverData)

        await model.save()

        #expect(uploaded == [picked])
        let request = try #require(requests.first)
        #expect(requests.count == 1)
        let json = try requestObject(try JSONEncoder().encode(request))
        #expect(json["og_image"] as? String == "https://api.test/api/v1/images/new")
        #expect(model.phase == .saved && model.savedServerID == "77")
        #expect(queued == 0)
    }

    @Test func saveWithoutAPickedImageDoesNotUpload() async {
        var uploads = 0
        let model = makeModel(upload: { _ in uploads += 1; return "x" })
        model.coverData = Data([1, 2, 3])      // the page's own image, not a picked one
        await model.save()
        #expect(uploads == 0)
        #expect(model.savedServerID == "77")
    }

    @Test func uploadFailureQueuesTheCardWithThePickedImage() async throws {
        var payloads: [SharePayload] = []
        var created = 0
        let model = makeModel(
            upload: { _ in throw Boom() },
            create: { _ in created += 1; throw Boom() },
            queue: { payloads.append($0); return UUID() })
        model.pickImage(noisyImageData(side: 400))
        let picked = try #require(model.coverData)

        await model.save()

        #expect(created == 0)
        let payload = try #require(payloads.first)
        #expect(payloads.count == 1)
        #expect(payload.imageData == picked)
        #expect(model.phase == .saved && model.savedServerID == nil && model.queuedMessage != nil)
    }

    @Test func createFailureAfterAnUploadStillQueuesThePickedImage() async throws {
        var payloads: [SharePayload] = []
        let model = makeModel(
            upload: { _ in "https://api.test/api/v1/images/new" },
            create: { _ in throw Boom() },
            queue: { payloads.append($0); return UUID() })
        model.pickImage(noisyImageData(side: 400))
        let picked = try #require(model.coverData)

        await model.save()

        #expect(payloads.first?.imageData == picked)
        #expect(model.savedServerID == nil && model.phase == .saved)
    }

    @Test func signedOutSaveQueuesWithoutUploading() async throws {
        var uploads = 0
        var payloads: [SharePayload] = []
        let model = makeModel(signedIn: false, upload: { _ in uploads += 1; return "x" },
                              queue: { payloads.append($0); return UUID() })
        model.pickImage(noisyImageData(side: 400))
        let picked = try #require(model.coverData)

        await model.save()

        #expect(uploads == 0)
        #expect(payloads.first?.imageData == picked)
    }
}
