//
//  ClipAppFlowTests.swift
//  SphirTests
//
//  T5: the main-app side of the three-tap clip: +Card routing, link input
//  normalization, deep links by server id, queued clips keeping type/price/
//  image, collections published with their server id, multi-collection
//  membership.
//

import Testing
import Foundation
import CoreData
@testable import Sphir

struct ClipAppFlowTests {

    @MainActor
    private func makeStore() -> AppStore {
        AppStore(context: PersistenceController(inMemory: true).container.viewContext, seedIfEmpty: false)
    }

    // MARK: - Deep links (S4: "View card" after an online save)

    @Test func deepLinkParsesServerIDs() {
        #expect(DeepLink(url: URL(string: "sphir://card/123")!) == .cardServerID("123"))
        #expect(DeepLink(url: URL(string: "sphir://card/9007")!) == .cardServerID("9007"))
        #expect(DeepLink(url: URL(string: "https://sphir.io/card/55")!) == .cardServerID("55"))
    }

    @Test func deepLinkKeepsUUIDsAndRejectsJunk() {
        let id = UUID()
        #expect(DeepLink(url: URL(string: "sphir://card/\(id.uuidString)")!) == .card(id))
        #expect(DeepLink(url: URL(string: "sphir://collection/\(id.uuidString)")!) == .collection(id))
        #expect(DeepLink(url: URL(string: "sphir://card/")!) == nil)
        #expect(DeepLink(url: URL(string: "sphir://card/a%20b")!) == nil)
        #expect(DeepLink(url: URL(string: "sphir://card/not-a-uuid")!) == nil)
        #expect(DeepLink(url: URL(string: "sphir://card/12abc")!) == nil)
        #expect(DeepLink(url: URL(string: "sphir://home")!) == nil)
    }

    @Test func deepLinkParsesCollectionServerIDs() {
        #expect(DeepLink(url: URL(string: "sphir://collection/12")!) == .collectionServerID("12"))
        #expect(DeepLink(url: URL(string: "https://sphir.io/collection/705")!) == .collectionServerID("705"))
        #expect(DeepLink(url: URL(string: "sphir://collection/12abc")!) == nil)
        #expect(DeepLink(url: URL(string: "sphir://collection/")!) == nil)
        #expect(DeepLink(url: URL(string: "sphir://home/12")!) == nil)
    }

    @Test func deepLinkKeepsExistingFormsWhenCollectionServerIDsExist() {
        let id = UUID()
        #expect(DeepLink(url: URL(string: "sphir://collection/\(id.uuidString)")!) == .collection(id))
        #expect(DeepLink(url: URL(string: "sphir://card/123")!) == .cardServerID("123"))
        #expect(DeepLink(url: URL(string: "sphir://collection/not-a-uuid")!) == nil)
    }

    @Test func routerResolvesCollectionByServerIDAndByUUID() {
        let a = Collection(name: "A", cardCount: 0, serverID: "12")
        let b = Collection(name: "B", cardCount: 0)
        let all = [a, b]
        #expect(NavigationRouter.collection(for: .collectionServerID("12"), in: all)?.id == a.id)
        #expect(NavigationRouter.collection(for: .collection(b.id), in: all)?.id == b.id)
        #expect(NavigationRouter.collection(for: .collectionServerID("99"), in: all) == nil)
        #expect(NavigationRouter.collection(for: .cardServerID("12"), in: all) == nil)
    }

    @Test func deepLinkCollectionURLByServerID() {
        #expect(Collection.deepLinkURL(serverID: "12")?.absoluteString == "sphir://collection/12")
    }

    @Test func routerResolvesCardByServerIDAndByUUID() {
        let a = Card(title: "A", serverID: "41")
        let b = Card(title: "B", serverID: nil)
        let cards = [a, b]
        #expect(NavigationRouter.card(for: .cardServerID("41"), in: cards)?.id == a.id)
        #expect(NavigationRouter.card(for: .card(b.id), in: cards)?.id == b.id)
        #expect(NavigationRouter.card(for: .cardServerID("99"), in: cards) == nil)
        #expect(NavigationRouter.card(for: .collection(UUID()), in: cards) == nil)
    }

    @Test func deepLinkCardURLUsesLocalID() {
        let card = Card(title: "A", serverID: "41")
        #expect(card.deepLinkURL?.absoluteString == "sphir://card/\(card.id.uuidString)")
        #expect(Card.deepLinkURL(serverID: "41")?.absoluteString == "sphir://card/41")
    }

    // MARK: - Queued clips keep type / price / image

    @MainActor
    @Test func importKeepsTypePriceAndImage() {
        SharedInbox.clearPendingCards()
        let store = makeStore()
        let collection = store.addCollection(name: "Shop", privacy: .private)
        SharedInbox.enqueueCard(SharedCardDTO(
            id: UUID(), title: "Lamp", description: "Nice", urlString: "https://shop.example.com/p/1",
            collectionID: collection.id, createdAt: Date(), tags: ["home"],
            cardTypeRaw: "product", price: "$29.99", imageURL: "https://x.test/a.jpg"))
        store.importPendingSharedCards()

        let card = try! #require(store.cards.first { $0.title == "Lamp" })
        #expect(card.cardType == .product)
        #expect(card.price == "$29.99")
        #expect(card.imageURL == "https://x.test/a.jpg")
        #expect(card.content == "https://shop.example.com/p/1")
        #expect(card.tags == ["home"])
        #expect(card.collectionID == collection.id)
        #expect(SharedInbox.loadPendingCards().isEmpty)
    }

    @MainActor
    @Test func importOfOldQueuedClipStaysPlainText() {
        SharedInbox.clearPendingCards()
        let store = makeStore()
        _ = store.addCollection(name: "Inbox", privacy: .private)
        SharedInbox.enqueueCard(SharedCardDTO(
            id: UUID(), title: "Old", urlString: "https://a.test", collectionID: nil, createdAt: Date()))
        store.importPendingSharedCards()
        let card = try! #require(store.cards.first { $0.title == "Old" })
        #expect(card.cardType == .text)
        #expect(card.price == "")
        #expect(card.imageURL == nil)
    }

    @Test func oldQueuedJSONStillDecodes() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","title":"T","description":"","urlString":"https://a.test","bodyText":"",
         "sourceAppRaw":"safari","createdAt":0}
        """
        let dto = try JSONDecoder().decode(SharedCardDTO.self, from: Data(json.utf8))
        #expect(dto.id == id)
        #expect(dto.cardTypeRaw == nil && dto.price == nil && dto.imageURL == nil)
    }

    @MainActor
    @Test func inAppClipQueueKeepsDraftDetails() {
        let store = makeStore()
        let collection = store.addCollection(name: "Recipes", privacy: .private)
        var draft = ClipDraft(fallbackURL: "https://www.youtube.com/watch?v=1", title: "Soup")
        draft.price = ""
        let payload = draft.payload(collectionID: collection.id, imageData: nil)
        #expect(payload.cardTypeRaw == "video")
        let id = store.addClipCard(payload)
        let card = try! #require(store.cards.first { $0.id == id })
        #expect(card.cardType == .video)
        #expect(card.title == "Soup")
        #expect(card.collectionID == collection.id)
    }

    @Test func draftPayloadCarriesTypePriceAndImage() {
        let preview = LinkPreview(url: "https://shop.example.com/p/1", title: "Lamp", description: "Nice",
                                  image: "https://x.test/a.jpg", type: "product", tags: ["home"],
                                  price: "$29.99", site: "shop.example.com", published: "")
        let draft = ClipDraft(preview: preview, fallbackURL: "https://shop.example.com/p/1")
        let local = UUID()
        let payload = draft.payload(collectionID: local, imageData: nil)
        #expect(payload.collectionID == local)
        #expect(payload.title == "Lamp")
        #expect(payload.urlString == "https://shop.example.com/p/1")
        #expect(payload.cardTypeRaw == "product")
        #expect(payload.price == "$29.99")
        #expect(payload.imageURL == "https://x.test/a.jpg")
        #expect(payload.tags == ["home"])
    }

    // MARK: - Collections published with the server id

    @Test func publishedCollectionsCarryServerID() {
        let a = Collection(name: "Recipes", cardCount: 0, serverID: "12")
        let b = Collection(name: "Local only", cardCount: 0)
        let shared = AppStore.sharedCollections(from: [a, b])
        #expect(shared == [SharedCollectionDTO(id: a.id, name: "Recipes", serverID: "12"),
                           SharedCollectionDTO(id: b.id, name: "Local only", serverID: nil)])
    }

    @Test func oldPublishedCollectionsStillDecode() throws {
        let id = UUID()
        let json = #"[{"id":"\#(id.uuidString)","name":"Old"}]"#
        let list = try JSONDecoder().decode([SharedCollectionDTO].self, from: Data(json.utf8))
        #expect(list == [SharedCollectionDTO(id: id, name: "Old")])
    }

    @Test func pickerMatchesByServerIDBeforeName() {
        let renamedLocal = UUID(), sameNameLocal = UUID()
        let folders = [Collection(name: "Server Name", cardCount: 0, serverID: "7")]
        let shared = [SharedCollectionDTO(id: sameNameLocal, name: "Server Name", serverID: "9"),
                      SharedCollectionDTO(id: renamedLocal, name: "Old Name", serverID: "7")]
        let list = ClipCollection.pickerList(folders: folders, shared: shared)
        #expect(list.map(\.localID) == [renamedLocal])
        #expect(list.map(\.serverID) == ["7"])
    }

    @Test func offlinePickerUsesPublishedServerIDs() {
        let id = UUID()
        let list = ClipCollection.fromShared([SharedCollectionDTO(id: id, name: "Recipes", serverID: "7")])
        #expect(list == [ClipCollection(name: "Recipes", serverID: "7", localID: id)])
    }

    // MARK: - Price and collections on cards

    @Test func requestSendsCardPriceAndTypeTag() throws {
        let card = Card(title: "Lamp", cardType: .product, price: "$29.99")
        let data = try JSONEncoder().encode(BusinessRequest(card: card))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["price"] as? String == "$29.99")
        #expect((json["tags"] as? [String])?.contains("_product") == true)
        let none = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(BusinessRequest(card: Card(title: "x")))) as? [String: Any]
        #expect(none?["price"] == nil)
    }

    @Test func dtoCarriesPriceAndFolderIDsToCard() throws {
        let dto = try JSONDecoder().decode(BusinessDTO.self, from: Data(
            #"{"id":5,"title":"Lamp","price":"$29.99","folder_id":3,"folder_ids":[3,8],"tags":["_product"]}"#.utf8))
        let card = dto.toCard()
        #expect(card.price == "$29.99")
        #expect(card.folderServerIDs == ["3", "8"])
    }

    @Test func cardBelongsToPrimaryAndExtraCollections() {
        let local = UUID()
        let card = Card(title: "A", collectionID: local, folderServerIDs: ["3", "8"])
        #expect(card.isIn(collectionID: local, serverID: nil))
        #expect(card.isIn(collectionID: UUID(), serverID: "8"))
        #expect(!card.isIn(collectionID: UUID(), serverID: "9"))
        #expect(!card.isIn(collectionID: UUID(), serverID: nil))
    }

    @MainActor
    @Test func priceSurvivesTheStore() {
        let store = makeStore()
        let collection = store.addCollection(name: "Shop", privacy: .private)
        SharedInbox.clearPendingCards()
        SharedInbox.enqueueCard(SharedCardDTO(
            id: UUID(), title: "Lamp", urlString: "https://a.test", collectionID: collection.id,
            createdAt: Date(), cardTypeRaw: "product", price: "$5"))
        store.importPendingSharedCards()
        #expect(store.cards.first { $0.title == "Lamp" }?.price == "$5")
    }

    @MainActor
    @Test func imageURLSurvivesTheStore() {
        let store = makeStore()
        let collection = store.addCollection(name: "Shop", privacy: .private)
        SharedInbox.clearPendingCards()
        SharedInbox.enqueueCard(SharedCardDTO(
            id: UUID(), title: "Lamp", urlString: "https://a.test", collectionID: collection.id,
            createdAt: Date(), cardTypeRaw: "product", imageURL: "https://x.test/lamp.jpg"))
        store.importPendingSharedCards()
        #expect(store.cards.first { $0.title == "Lamp" }?.imageURL == "https://x.test/lamp.jpg")
    }

    @MainActor
    @Test func syncUpdatesExistingCardImageURL() throws {
        let store = makeStore()
        let initialDTO = try JSONDecoder().decode(BusinessDTO.self, from: Data("""
        {"id":"srv-123","title":"Pasta","website":"https://a.test","og_image":""}
        """.utf8))
        store.reconcileCards([initialDTO])
        let initialCard = try #require(store.cards.first { $0.serverID == "srv-123" })
        #expect(initialCard.imageURL == nil)

        let updatedDTO = try JSONDecoder().decode(BusinessDTO.self, from: Data("""
        {"id":"srv-123","title":"Pasta","website":"https://a.test","og_image":"https://x.test/pasta.jpg"}
        """.utf8))
        store.reconcileCards([updatedDTO])

        let updatedCard = try #require(store.cards.first { $0.serverID == "srv-123" })
        #expect(updatedCard.imageURL == "https://x.test/pasta.jpg")
    }

    // MARK: - +Card input

    @Test func linkInputNormalization() {
        #expect(AddCardInput.link(from: "https://apple.com/mac") == "https://apple.com/mac")
        #expect(AddCardInput.link(from: "  http://a.test/x?y=1 \n") == "http://a.test/x?y=1")
        #expect(AddCardInput.link(from: "apple.com") == "https://apple.com")
        #expect(AddCardInput.link(from: "www.apple.com/mac") == "https://www.apple.com/mac")
        #expect(AddCardInput.link(from: "") == nil)
        #expect(AddCardInput.link(from: nil) == nil)
        #expect(AddCardInput.link(from: "hello") == nil)
        #expect(AddCardInput.link(from: "two words.com") == nil)
        #expect(AddCardInput.link(from: "ftp://a.test") == nil)
        #expect(AddCardInput.link(from: "https://") == nil)
        #expect(AddCardInput.link(from: "Buy milk. Then eggs") == nil)
    }

    // MARK: - +Card routing (S5)

    @MainActor
    @Test func addCardRouting() {
        let flow = CardFlowCoordinator()
        flow.start()
        #expect(flow.showAdd)
        #expect(flow.clipLink == nil && !flow.showForm && !flow.showScreenshotForm)

        flow.openLink("apple.com")
        #expect(flow.clipLink?.url == "https://apple.com")
        #expect(!flow.showForm && !flow.showScreenshotForm)

        flow.openLink("not a link")
        #expect(flow.clipLink?.url == "https://apple.com")   // rejected input changes nothing

        flow.clipLink = nil
        flow.openPhoto()
        #expect(flow.showScreenshotForm && flow.selectedSource == .screenshots)
        #expect(flow.clipLink == nil && !flow.showForm)

        flow.showScreenshotForm = false
        flow.openWrite()
        #expect(flow.showForm && flow.selectedType == .originalScribe)
        #expect(flow.clipLink == nil && !flow.showScreenshotForm)

        flow.dismissAll()
        #expect(!flow.showAdd)
    }

    @MainActor
    @Test func photoRowRoutesCameraAndLibrary() {
        let flow = CardFlowCoordinator()
        flow.start()

        flow.openCamera()
        #expect(flow.showPhotoForm && flow.selectedSource == .camera)
        #expect(flow.clipLink == nil && !flow.showForm && !flow.showScreenshotForm)

        flow.showPhotoForm = false
        flow.openPhoto()
        #expect(flow.showScreenshotForm && flow.selectedSource == .screenshots)
        #expect(!flow.showPhotoForm)

        #expect(CardFlowCoordinator.photoChoices(cameraAvailable: true) == [.library, .camera])
        #expect(CardFlowCoordinator.photoChoices(cameraAvailable: false) == [.library])
    }

    @MainActor
    @Test func viewCardFromTheClipClosesTheFlowAndRoutes() {
        let flow = CardFlowCoordinator()
        flow.start()
        flow.openLink("apple.com")
        flow.viewCard(id: "41")
        #expect(flow.pendingCardLink == "41")
        #expect(!flow.showAdd)
    }

    @MainActor
    @Test func ownCardIsSavedAsOriginalScribe() {
        let store = makeStore()
        let collection = store.addCollection(name: "Notes", privacy: .private)
        let card = store.addOwnCard(title: "Idea", description: "d", content: "Body text", tagsText: "a, b",
                                    collectionID: collection.id)
        #expect(card.cardType == .originalScribe)
        #expect(card.content == "Body text")
        #expect(card.tags == ["a", "b"])
        #expect(card.sourceApp == .own)
        #expect(store.cards.contains { $0.id == card.id })
    }
}
