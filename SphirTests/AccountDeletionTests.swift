//
//  AccountDeletionTests.swift
//  SphirTests
//
//  Unit tests for account deletion (S5, S6, S7).
//

import Testing
import Foundation
import CoreData
@testable import Sphir

private final class SpyNotificationObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var observer: NSObjectProtocol?

    var wasPosted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return count > 0
    }

    init(name: Notification.Name) {
        observer = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            self.count += 1
            self.lock.unlock()
        }
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    deinit {
        stop()
    }
}

private final class Stub422Protocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://sphir-api.onrender.com")!,
            statusCode: 422,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let body = Data(#"{"error":"Incorrect password"}"#.utf8)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
@Suite(.serialized)
struct AccountDeletionTests {

    // MARK: - Case 1: Success
    // Request closure called once with exact password; wipe called once;
    // isLoggedIn becomes false; Keychain cleared.
    @Test func successfulDeletionClearsSessionAndWipesData() async {
        var requestedPasswords: [String] = []
        var wipeCallCount = 0
        var keychainClearCount = 0

        let session = AuthSession(
            isLoggedIn: true,
            userName: "Jane Doe",
            userEmail: "jane@example.com",
            isMock: false,
            deleteAccountRequest: { password in
                requestedPasswords.append(password)
            },
            wipeLocalData: {
                wipeCallCount += 1
            },
            clearKeychain: {
                keychainClearCount += 1
            }
        )

        let result = await session.deleteAccount(password: "SuperSecret123")

        #expect(result == .success)
        #expect(requestedPasswords == ["SuperSecret123"])
        #expect(wipeCallCount == 1)
        #expect(keychainClearCount == 1)
        #expect(session.isLoggedIn == false)
        #expect(session.userName == "")
        #expect(session.userEmail == "")
    }

    // MARK: - Case 2: 422 (Incorrect Password)
    // Result is incorrectPassword; wipe NOT called; isLoggedIn stays true; Keychain untouched.
    @Test func incorrectPasswordDoesNotWipeDataOrClearSession() async {
        var wipeCallCount = 0
        var keychainClearCount = 0

        let session = AuthSession(
            isLoggedIn: true,
            userName: "Jane Doe",
            userEmail: "jane@example.com",
            isMock: false,
            deleteAccountRequest: { _ in
                throw AuthAPIError.incorrectPassword
            },
            wipeLocalData: {
                wipeCallCount += 1
            },
            clearKeychain: {
                keychainClearCount += 1
            }
        )

        let result = await session.deleteAccount(password: "WrongPassword")

        #expect(result == .incorrectPassword)
        #expect(wipeCallCount == 0)
        #expect(keychainClearCount == 0)
        #expect(session.isLoggedIn == true)
        #expect(session.userName == "Jane Doe")
        #expect(session.userEmail == "jane@example.com")
    }

    // MARK: - Case 3: Other Error
    // Result is failed; wipe NOT called; isLoggedIn stays true; Keychain untouched.
    @Test func serverErrorDoesNotWipeDataOrClearSession() async {
        var wipeCallCount = 0
        var keychainClearCount = 0

        let session = AuthSession(
            isLoggedIn: true,
            userName: "Jane Doe",
            userEmail: "jane@example.com",
            isMock: false,
            deleteAccountRequest: { _ in
                throw NetworkError.server(status: 500, body: nil)
            },
            wipeLocalData: {
                wipeCallCount += 1
            },
            clearKeychain: {
                keychainClearCount += 1
            }
        )

        let result = await session.deleteAccount(password: "SomePassword")

        #expect(result == .failed)
        #expect(wipeCallCount == 0)
        #expect(keychainClearCount == 0)
        #expect(session.isLoggedIn == true)
        #expect(session.userName == "Jane Doe")
        #expect(session.userEmail == "jane@example.com")
    }

    // MARK: - Case 4: Real Local Wipe
    // Persistence layer function removes all collections and cards from an in-memory store.
    @Test func persistenceWipeAllDataRemovesCollectionsAndCards() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let collection = NSEntityDescription.insertNewObject(forEntityName: "CDCollection", into: context)
        collection.setValue(UUID(), forKey: "id")
        collection.setValue("Test Collection", forKey: "name")

        let card = NSEntityDescription.insertNewObject(forEntityName: "CDCard", into: context)
        card.setValue(UUID(), forKey: "id")
        card.setValue("Test Card", forKey: "title")

        try context.save()

        let fetchColBefore = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDCollection"))
        let fetchCardBefore = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDCard"))
        #expect(fetchColBefore.count == 1)
        #expect(fetchCardBefore.count == 1)

        controller.wipeAllData()

        let fetchColAfter = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDCollection"))
        let fetchCardAfter = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDCard"))
        #expect(fetchColAfter.isEmpty)
        #expect(fetchCardAfter.isEmpty)
    }

    // MARK: - Case 5: Sign-out Preserved
    // signOut() clears the session and does NOT call the delete request.
    @Test func signOutStillClearsSessionWithoutCallingDeleteAccount() async {
        var deleteRequestCallCount = 0
        var keychainClearCount = 0

        let session = AuthSession(
            isLoggedIn: true,
            userName: "Jane Doe",
            userEmail: "jane@example.com",
            isMock: true,
            deleteAccountRequest: { _ in
                deleteRequestCallCount += 1
            },
            clearKeychain: {
                keychainClearCount += 1
            }
        )

        await session.signOut()

        #expect(session.isLoggedIn == false)
        #expect(deleteRequestCallCount == 0)
        #expect(keychainClearCount == 1)
    }

    // MARK: - Case 6: 422 from NetworkService does NOT trigger 401 path
    @Test func networkService422DoesNotTrigger401SessionExpiration() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Stub422Protocol.self]
        let service = NetworkService(session: URLSession(configuration: config))

        let spy = SpyNotificationObserver(name: .sphirUnauthorized)
        defer { spy.stop() }

        do {
            let _: EmptyResponse = try await service.request(
                "/api/v1/auth",
                method: .delete,
                body: ["password": "wrong"],
                authorized: true
            )
            Issue.record("Expected 422 to throw")
        } catch let NetworkError.server(status, _) {
            #expect(status == 422)
        } catch {
            Issue.record("Expected NetworkError.server(status: 422), got \(error)")
        }

        #expect(!spy.wasPosted)
    }

    // MARK: - Case 7: Explicit Guest Detection
    // after continueAsGuest isGuest is true; a signed-in user named "Guest" or with an empty cached email is NOT a guest.
    @Test func continueAsGuestSetsIsGuestToTrue() async throws {
        let session = AuthSession(
            isLoggedIn: false,
            userName: "",
            userEmail: "",
            isMock: true
        )
        #expect(session.isGuest == false)

        try await session.continueAsGuest()
        #expect(session.isGuest == true)
        #expect(session.isLoggedIn == true)

        await session.signOut()
        #expect(session.isGuest == false)
    }

    @Test func signedInUserNamedGuestOrWithEmptyEmailIsNotGuest() {
        let session1 = AuthSession(
            isLoggedIn: true,
            userName: "Guest",
            userEmail: "",
            isMock: false
        )
        #expect(session1.isGuest == false)

        let session2 = AuthSession(
            isLoggedIn: true,
            userName: "Jane",
            userEmail: "",
            isMock: false
        )
        #expect(session2.isGuest == false)
    }

    // MARK: - Case 8: AppStore resetLocalData Wipes In-Memory State & Context
    @Test func appStoreResetLocalDataWipesContextAndPublishedProjections() throws {
        let controller = PersistenceController(inMemory: true)
        let store = AppStore(context: controller.container.viewContext, seedIfEmpty: false)

        let collection = store.addCollection(name: "Secret Collection", privacy: .private)
        store.addCard(
            title: "Secret Card",
            description: "",
            urlText: "https://secret.example",
            tagsText: "",
            type: .text,
            source: .url,
            collectionID: collection.id
        )

        #expect(!store.collections.isEmpty)
        #expect(!store.cards.isEmpty)

        store.resetLocalData()

        #expect(store.collections.isEmpty)
        #expect(store.cards.isEmpty)

        let fetchCol = try controller.container.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDCollection"))
        let fetchCards = try controller.container.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDCard"))
        #expect(fetchCol.isEmpty)
        #expect(fetchCards.isEmpty)
    }
}
