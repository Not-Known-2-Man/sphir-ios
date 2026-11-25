//
//  SignOutWipeTests.swift
//  SphirTests
//
//  Sign out wipes local data; a 401 keeps it; a different account signing in
//  on the same device wipes the previous owner's data first.
//

import Testing
import Foundation
import CoreData
@testable import Sphir

@MainActor
@Suite(.serialized)
struct SignOutWipeTests {

    private let ownerKey = "auth.dataOwner"

    private final class Probe {
        var wipes = 0
        var loggedInAtWipe: [Bool] = []
        var ownerAtWipe: [String?] = []
        var signOutCalls = 0
        /// Ordered "wipe" / "save" events, to pin wipe-before-credentials.
        var events: [String] = []
        var unsynced = 0
        var ownerAtSave: [String?] = []
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let name = "SignOutWipeTests-\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    private func makeSession(
        defaults: UserDefaults,
        probe: Probe,
        loggedIn: Bool = false,
        email: String = "",
        signInFails: Bool = false
    ) -> AuthSession {
        var sessionRef: AuthSession?
        let session = AuthSession(
            isLoggedIn: loggedIn,
            userName: "",
            userEmail: email,
            isMock: false,
            deleteAccountRequest: { _ in },
            wipeLocalData: {
                probe.wipes += 1
                probe.loggedInAtWipe.append(sessionRef?.isLoggedIn ?? false)
                probe.ownerAtWipe.append(defaults.string(forKey: "auth.dataOwner"))
                probe.events.append("wipe")
            },
            clearKeychain: {},
            signInRequest: { email, _ in
                if signInFails { throw URLError(.notConnectedToInternet) }
                return SignInResponse(token: "t", uid: email, client: nil, firstName: nil, lastName: nil)
            },
            signOutRequest: { probe.signOutCalls += 1 },
            saveCredentials: { _ in
                probe.events.append("save")
                probe.ownerAtSave.append(defaults.string(forKey: "auth.dataOwner"))
            },
            unsyncedItemCount: { probe.unsynced },
            defaults: defaults
        )
        sessionRef = session
        return session
    }

    // R1
    @Test func signOutWipesLocalDataAndClearsOwner() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let probe = Probe()
        let session = makeSession(defaults: defaults, probe: probe)
        try await session.signIn(email: "a@x.com", password: "pw")
        #expect(defaults.string(forKey: ownerKey) == "a@x.com")

        await session.signOut()

        #expect(probe.signOutCalls == 1)
        #expect(probe.wipes == 1)
        #expect(session.isLoggedIn == false)
        #expect(defaults.string(forKey: ownerKey) == nil)
    }

    // R3
    @Test func unauthorizedKeepsLocalDataAndOwner() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let probe = Probe()
        let session = makeSession(defaults: defaults, probe: probe)
        try await session.signIn(email: "a@x.com", password: "pw")

        session.handleUnauthorized()

        #expect(session.isLoggedIn == false)
        #expect(probe.wipes == 0)
        #expect(defaults.string(forKey: ownerKey) == "a@x.com")
    }

    // R4: same owner
    @Test func sameOwnerSignInKeepsData() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("a@x.com", forKey: ownerKey)
        let probe = Probe()
        let session = makeSession(defaults: defaults, probe: probe)

        try await session.signIn(email: "a@x.com", password: "pw")

        #expect(probe.wipes == 0)
        #expect(session.isLoggedIn)
    }

    // R4: a failed sign-in never wipes or changes the owner
    @Test func failedSignInKeepsDataAndOwner() async {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("a@x.com", forKey: ownerKey)
        let probe = Probe()
        let session = makeSession(defaults: defaults, probe: probe, signInFails: true)

        await #expect(throws: (any Error).self) {
            try await session.signIn(email: "b@x.com", password: "pw")
        }

        #expect(probe.wipes == 0)
        #expect(session.isLoggedIn == false)
        #expect(defaults.string(forKey: ownerKey) == "a@x.com")
    }

    // R4: delete account wipes and clears the owner
    @Test func deleteAccountWipesAndClearsOwner() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let probe = Probe()
        let session = makeSession(defaults: defaults, probe: probe)
        try await session.signIn(email: "a@x.com", password: "pw")

        let result = await session.deleteAccount(password: "pw")

        #expect(result == .success)
        #expect(probe.wipes == 1)
        #expect(defaults.string(forKey: ownerKey) == nil)
    }

    // R4: different owner, wipe before isLoggedIn
    @Test func differentOwnerSignInWipesBeforeLoggingIn() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("a@x.com", forKey: ownerKey)
        let probe = Probe()
        let session = makeSession(defaults: defaults, probe: probe)

        try await session.signIn(email: "b@x.com", password: "pw")

        #expect(probe.wipes == 1)
        #expect(probe.loggedInAtWipe == [false])
        #expect(session.isLoggedIn)
        #expect(defaults.string(forKey: ownerKey) == "b@x.com")
    }

    // R4: no owner recorded
    @Test func noOwnerSignInKeepsDataAndRecordsOwner() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let probe = Probe()
        let session = makeSession(defaults: defaults, probe: probe)

        try await session.signIn(email: "a@x.com", password: "pw")

        #expect(probe.wipes == 0)
        #expect(defaults.string(forKey: ownerKey) == "a@x.com")
    }

    // R4: normalization
    @Test func ownerMatchIgnoresCaseAndWhitespace() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("a@x.com", forKey: ownerKey)
        let probe = Probe()
        let session = makeSession(defaults: defaults, probe: probe)

        try await session.signIn(email: "  A@X.com ", password: "pw")

        #expect(probe.wipes == 0)
        #expect(defaults.string(forKey: ownerKey) == "a@x.com")
    }

    // R4: launch migration
    @Test func launchRecordsCachedEmailAsOwnerWhenMissing() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        _ = makeSession(defaults: defaults, probe: Probe(), loggedIn: true, email: " Old@X.com ")
        #expect(defaults.string(forKey: ownerKey) == "old@x.com")
    }

    // Fix 1: the owner is forgotten only after the wipe, so a crash in between
    // still leaves the data tied to its owner.
    @Test func signOutWipesBeforeForgettingOwner() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let probe = Probe()
        let session = makeSession(defaults: defaults, probe: probe)
        try await session.signIn(email: "a@x.com", password: "pw")

        await session.signOut()

        #expect(probe.ownerAtWipe == ["a@x.com"])
        #expect(defaults.string(forKey: ownerKey) == nil)
    }

    @Test func deleteAccountWipesBeforeForgettingOwner() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let probe = Probe()
        let session = makeSession(defaults: defaults, probe: probe)
        try await session.signIn(email: "a@x.com", password: "pw")

        _ = await session.deleteAccount(password: "pw")

        #expect(probe.ownerAtWipe == ["a@x.com"])
        #expect(defaults.string(forKey: ownerKey) == nil)
    }

    // Fix 3: signing in as another account reports the unsynced items it would delete.
    @Test func unsyncedItemsLostOnlyWhenAnotherAccountSignsIn() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let probe = Probe()
        probe.unsynced = 3
        let session = makeSession(defaults: defaults, probe: probe)

        #expect(session.unsyncedItemsLost(signingInAs: "b@x.com") == 0) // no owner: nothing wiped
        defaults.set("a@x.com", forKey: ownerKey)
        #expect(session.unsyncedItemsLost(signingInAs: " A@X.com ") == 0)
        #expect(session.unsyncedItemsLost(signingInAs: "b@x.com") == 3)
        probe.unsynced = 0
        #expect(session.unsyncedItemsLost(signingInAs: "b@x.com") == 0)
    }

    // Fix 4: an old logged-in install without a cached email gets an unknown
    // owner, so whichever account signs in next starts clean.
    @Test func launchWithoutCachedEmailMarksOwnerUnknownAndNextSignInWipes() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let probe = Probe()
        probe.unsynced = 1
        let session = makeSession(defaults: defaults, probe: probe, loggedIn: true, email: "")
        #expect(defaults.string(forKey: ownerKey) != nil)
        #expect(session.unsyncedItemsLost(signingInAs: "a@x.com") == 1)

        session.handleUnauthorized()
        try await session.signIn(email: "a@x.com", password: "pw")

        #expect(probe.wipes == 1)
        #expect(defaults.string(forKey: ownerKey) == "a@x.com")
    }

    // Fix 5: the new account's token is stored only after the old data is gone,
    // so no sync can upload the previous account's cards with it.
    @Test func credentialsAreSavedOnlyAfterWipe() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("a@x.com", forKey: ownerKey)
        let probe = Probe()
        let session = makeSession(defaults: defaults, probe: probe)

        try await session.signIn(email: "b@x.com", password: "pw")

        #expect(probe.events == ["wipe", "save"])
    }

    // A crash after the token is stored must not leave the new account logged
    // in with the previous owner recorded (its next sign-in would wipe its own data).
    @Test func ownerIsRecordedBeforeCredentialsAreSaved() async throws {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("a@x.com", forKey: ownerKey)
        let probe = Probe()
        let session = makeSession(defaults: defaults, probe: probe)

        try await session.signIn(email: "b@x.com", password: "pw")

        #expect(probe.ownerAtSave == ["b@x.com"])
    }

    @Test func failedSignInSavesNoCredentials() async {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let probe = Probe()
        let session = makeSession(defaults: defaults, probe: probe, signInFails: true)

        await #expect(throws: (any Error).self) {
            try await session.signIn(email: "b@x.com", password: "pw")
        }

        #expect(probe.events.isEmpty)
    }

    // Fix 2: collections that were never uploaded count too.
    @Test func unsyncedItemCountIncludesUnuploadedCollections() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let store = AppStore(context: context, seedIfEmpty: false)
        _ = store.addCollection(name: "local", privacy: .private)
        _ = store.addCollection(name: "uploaded", privacy: .private)
        let folders = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDCollection"))
        for folder in folders where folder.value(forKey: "name") as? String == "uploaded" {
            folder.setValue("srv-f", forKey: "serverID")
        }
        try context.save()

        #expect(store.unsyncedItemCount == 1)
    }

    // R2 (data side)
    @Test func unsyncedCardCountCountsOfflineOrNoServerIDOnly() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let store = AppStore(context: context, seedIfEmpty: false)
        for title in ["local", "offline", "synced"] {
            store.addCard(title: title, description: "", urlText: "https://\(title).test",
                          tagsText: "", type: .text, source: .url)
        }
        let objects = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDCard"))
        for object in objects {
            switch object.value(forKey: "title") as? String {
            case "offline":
                object.setValue("srv-1", forKey: "serverID")
                object.setValue(SyncStatus.offline.rawValue, forKey: "syncStatus")
            case "synced":
                object.setValue("srv-2", forKey: "serverID")
                object.setValue(SyncStatus.synced.rawValue, forKey: "syncStatus")
            default: break // "local": no serverID
            }
        }
        try context.save()

        #expect(store.unsyncedItemCount == 2)
    }
}
