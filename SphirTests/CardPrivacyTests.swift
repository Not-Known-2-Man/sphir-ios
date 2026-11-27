//
//  CardPrivacyTests.swift
//  SphirTests
//
//  card-privacy T2 (S5): every card has a private lock (default on) that
//  flows from the API into Card, is stored locally and is sent on create and update.
//

import Testing
import Foundation
import CoreData
@testable import Sphir

struct CardPrivacyTests {

    private func dto(_ json: String) throws -> BusinessDTO {
        try JSONDecoder().decode(BusinessDTO.self, from: Data(json.utf8))
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Card

    @Test func newCardIsPrivateByDefault() {
        #expect(Card(title: "T").isPrivate == true)
    }

    // MARK: - BusinessDTO

    @Test func dtoDecodesIsPrivateTrueAndFalse() throws {
        #expect(try dto(#"{"id":1,"title":"T","is_private":true}"#).isPrivate == true)
        #expect(try dto(#"{"id":1,"title":"T","is_private":false}"#).isPrivate == false)
        #expect(try dto(#"{"id":1,"title":"T","is_private":false}"#).toCard().isPrivate == false)
    }

    @Test func dtoMissingOrWrongIsPrivateIsLocked() throws {
        #expect(try dto(#"{"id":1,"title":"T"}"#).isPrivate == true)
        #expect(try dto(#"{"id":1,"title":"T","is_private":null}"#).isPrivate == true)
        #expect(try dto(#"{"id":1,"title":"T"}"#).toCard().isPrivate == true)
    }

    @Test func dtoToleratesPreviewWithCountOnly() throws {
        // "already_on_sphir" may now carry only a count: strings default to "".
        let d = try dto(#"{"count":3}"#)
        #expect(d.title == "")
        #expect(d.price == "")
    }

    // MARK: - BusinessRequest

    @Test func requestEncodesIsPrivate() throws {
        let locked = try object(JSONEncoder().encode(BusinessRequest(card: Card(title: "T"))))
        #expect(locked["is_private"] as? Bool == true)
        let open = try object(JSONEncoder().encode(BusinessRequest(card: Card(title: "T", isPrivate: false))))
        #expect(open["is_private"] as? Bool == false)
    }

    // MARK: - Store

    @MainActor
    @Test func storedCardKeepsAndUpdatesTheLock() throws {
        let store = AppStore(context: PersistenceController(inMemory: true).container.viewContext, seedIfEmpty: false)
        let card = store.addOwnCard(title: "Mine", description: "", content: "x", tagsText: "")
        #expect(store.cards.first { $0.id == card.id }?.isPrivate == true)
        var edited = card
        edited.isPrivate = false
        store.updateCard(edited)
        #expect(store.cards.first { $0.id == card.id }?.isPrivate == false)
    }

    @MainActor
    @Test func reconcileTakesTheLockFromTheServer() throws {
        let store = AppStore(context: PersistenceController(inMemory: true).container.viewContext, seedIfEmpty: false)
        store.reconcileCards([try dto(#"{"id":7,"title":"A","is_private":false}"#),
                              try dto(#"{"id":8,"title":"B"}"#)])
        let byServer = Dictionary(uniqueKeysWithValues: store.cards.compactMap { c in c.serverID.map { ($0, c) } })
        #expect(byServer["7"]?.isPrivate == false)
        #expect(byServer["8"]?.isPrivate == true)
        store.reconcileCards([try dto(#"{"id":7,"title":"A","is_private":true}"#)])
        #expect(store.cards.first { $0.serverID == "7" }?.isPrivate == true)
    }
}
