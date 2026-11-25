//
//  UnfiledCollectionTests.swift
//  SphirTests
//
//  demo-feedback-1125 (iOS): the default "Unfiled Cards" collection
//  (`is_default`), cards without a collection landing in it, no delete/rename
//  of it, and "New collection" from the create-card screens.
//

import Testing
import Foundation
import CoreData
@testable import Sphir

@MainActor
struct UnfiledCollectionTests {

    private let context = PersistenceController(inMemory: true).container.viewContext

    private func folders(_ json: String) throws -> [FolderDTO] {
        try JSONDecoder().decode([FolderDTO].self, from: Data(json.utf8))
    }

    private func makeStore(folders: [Collection] = [], deleteFolder: @escaping AppStore.RemoteDeleter = { _ in }) -> AppStore {
        AppStore(context: context, seedIfEmpty: false,
                 hasCredentials: { true },
                 fetchFolders: { folders },
                 deleteFolderAPI: deleteFolder)
    }

    private let reading = Collection(name: "Reading", cardCount: 0, serverID: "1")
    private let unfiled = Collection(name: "Unfiled Cards", cardCount: 0, serverID: "2", isDefault: true)

    // MARK: - Decoding

    @Test func decodesIsDefault() throws {
        let list = try folders(#"[{"id":1,"name":"Reading"},{"id":"2","name":"Unfiled Cards","is_default":true},{"id":3,"name":"X","is_default":false}]"#)
        #expect(list.map { $0.toCollection().isDefault } == [false, true, false])
        #expect(list[1].toCollection().serverID == "2")
    }

    // MARK: - Persistence of the flag

    @Test func syncKeepsTheDefaultFlagAndUpdatesIt() async {
        let store = makeStore(folders: [reading, unfiled])
        await store.syncCollections()
        // Both rows can share createdAt, so their order is not stable: check by name.
        let flags = Dictionary(uniqueKeysWithValues: store.collections.map { ($0.name, $0.isDefault) })
        #expect(flags == ["Reading": false, "Unfiled Cards": true])
        #expect(store.defaultCollection?.name == "Unfiled Cards")

        // A second sync (existing local rows) keeps the flag.
        await store.syncCollections()
        #expect(store.collections.filter(\.isDefault).count == 1)
    }

    // MARK: - Cards without a collection (S4)

    @Test func cardWithoutCollectionGoesToTheDefault() async {
        let store = makeStore(folders: [reading, unfiled])
        await store.syncCollections()
        let card = store.addCard(title: "A", description: "", urlText: "", tagsText: "",
                                 type: .text, source: .url)
        #expect(card.collectionID == store.defaultCollection?.id)
        #expect(store.cards.first { $0.id == card.id }?.collectionID == store.defaultCollection?.id)
    }

    @Test func unknownCollectionAlsoFallsBackToTheDefault() async {
        let store = makeStore(folders: [reading, unfiled])
        await store.syncCollections()
        let card = store.addCard(title: "A", description: "", urlText: "", tagsText: "",
                                 type: .text, source: .url, collectionID: UUID())
        #expect(card.collectionID == store.defaultCollection?.id)
    }

    @Test func deletingACollectionMovesItsCardsToTheDefault() async {
        let store = makeStore(folders: [reading, unfiled])
        await store.syncCollections()
        let readingID = store.collections.first { $0.name == "Reading" }!.id
        let card = store.addCard(title: "A", description: "", urlText: "", tagsText: "",
                                 type: .text, source: .url, collectionID: readingID)
        #expect(card.collectionID == readingID)

        store.deleteCollection(id: readingID)

        #expect(store.cards.first { $0.id == card.id }?.collectionID == store.defaultCollection?.id)
        #expect(store.collections.map(\.name) == ["Unfiled Cards"])
    }

    // MARK: - Protected default (S5)

    @Test func defaultCollectionCannotBeDeleted() async {
        var deleted: [String] = []
        let store = makeStore(folders: [reading, unfiled], deleteFolder: { deleted.append($0) })
        await store.syncCollections()
        let id = store.defaultCollection!.id

        store.deleteCollection(id: id)
        await Task.yield()

        #expect(store.collections.contains { $0.id == id })
        #expect(deleted.isEmpty)
        #expect(!Collection(name: "x", cardCount: 0, isDefault: true).canModify)
        #expect(Collection(name: "x", cardCount: 0).canModify)
    }

    @Test func conflictOnDeleteResyncsInsteadOfLosingTheCollection() async {
        // The server still says 409 for a collection the app did not know was the default.
        let conflict = NetworkError.server(status: 409, body: #"{"error":"Unfiled Cards can't be deleted or renamed"}"#)
        #expect(AppStore.isDefaultCollectionConflict(conflict))
        #expect(!AppStore.isDefaultCollectionConflict(NetworkError.server(status: 500, body: nil)))
        #expect(!AppStore.isDefaultCollectionConflict(NetworkError.unauthorized))

        let store = makeStore(folders: [reading, unfiled], deleteFolder: { _ in throw conflict })
        await store.syncCollections()
        let id = store.collections.first { $0.name == "Reading" }!.id
        store.deleteCollection(id: id)
        for _ in 0..<20 { await Task.yield() }
        // Reading was never really deleted on the server: the resync brings it back.
        #expect(store.collections.contains { $0.serverID == "1" })
    }

    // MARK: - New collection (S6)

    @Test func newCollectionNameIsTrimmedAndRequired() {
        #expect(NewCollectionName.resolve("  Gifts  ", existing: ["Reading"]) == .create("Gifts"))
        #expect(NewCollectionName.resolve("   ", existing: []) == .invalid)
        #expect(NewCollectionName.resolve("", existing: []) == .invalid)
    }

    @Test func newCollectionWithAnExistingNameSelectsTheExistingOne() {
        #expect(NewCollectionName.resolve("reading", existing: ["Gifts", "Reading"]) == .existing(1))
    }

    @Test func selectionAfterCreateIsTheNewCollection() {
        #expect(CollectionSelection.afterCreate(id: "9") == ["9"])
        #expect(CollectionSelection.primary(of: CollectionSelection.afterCreate(id: "9")) == "9")
    }

    @Test func clipModelCreatesAndSelectsKeepingTheDraft() async {
        let model = ClipFlowModel(
            content: SharedContent(urlString: "https://example.com/x"),
            sharedCollections: [], inApp: true,
            queue: { _ in UUID() },
            createCollection: { name in ClipCollection(name: name, serverID: "77", localID: UUID()) })
        model.draft.title = "Typed title"
        model.collections = [ClipCollection(name: "Reading", serverID: "1", localID: nil)]
        model.selectedIDs = ["1"]

        await model.createCollection(named: "  Gifts ")

        #expect(model.collections.map(\.name) == ["Reading", "Gifts"])
        #expect(model.selected?.name == "Gifts")
        #expect(model.selectedIDs == ["77"])
        #expect(model.draft.title == "Typed title")
        #expect(model.collectionError == nil)
    }

    @Test func clipModelReusesAnExistingCollectionWithTheSameName() async {
        var calls = 0
        let model = ClipFlowModel(
            content: SharedContent(urlString: "https://example.com/x"),
            sharedCollections: [], inApp: true,
            queue: { _ in UUID() },
            createCollection: { name in calls += 1; return ClipCollection(name: name, serverID: "77", localID: nil) })
        model.collections = [ClipCollection(name: "Reading", serverID: "1", localID: nil)]
        model.selectedIDs = []

        await model.createCollection(named: "reading")

        #expect(calls == 0)
        #expect(model.collections.count == 1)
        #expect(model.selectedIDs == ["1"])
    }

    @Test func clipModelReportsAFailedCreateAndChangesNothing() async {
        let model = ClipFlowModel(
            content: SharedContent(urlString: "https://example.com/x"),
            sharedCollections: [], inApp: true,
            queue: { _ in UUID() },
            createCollection: { _ in nil })
        model.collections = [ClipCollection(name: "Reading", serverID: "1", localID: nil)]
        model.selectedIDs = ["1"]

        await model.createCollection(named: "Gifts")

        #expect(model.collections.count == 1)
        #expect(model.selectedIDs == ["1"])
        #expect(model.collectionError == "Couldn't create the collection. Try again.")
    }

    @Test func appCreateWaitsForTheServerIDAndSelectsIt() async {
        let store = AppStore(context: context, seedIfEmpty: false,
                             createFolder: { name, _, _ in Collection(name: name, cardCount: 0, serverID: "55") },
                             hasCredentials: { true })
        let created = await store.addCollectionAwaitingServer(name: "Gifts")
        #expect(created.serverID == "55")
        #expect(store.collections.contains { $0.id == created.id })
    }
}
