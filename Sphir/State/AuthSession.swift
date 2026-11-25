//
//  AuthSession.swift
//  Sphir
//
//  Authentication state. Talks to the real API (AuthAPIService) with tokens
//  in the Keychain; falls back to a deterministic mock under UITEST so UI
//  tests don't hit the network. The cached display name/email live in
//  UserDefaults so a returning user is greeted before the first fetch.
//

import SwiftUI
import Combine

enum DeleteAccountResult: Equatable {
    case success
    case incorrectPassword
    case failed
}

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var isLoggedIn: Bool
    @Published private(set) var isGuest: Bool
    @Published private(set) var userName: String
    @Published private(set) var userEmail: String
    /// Whether the user has completed onboarding (persists across sign-out).
    @Published private(set) var hasSeenOnboarding: Bool

    typealias DeleteAccountRequest = (_ password: String) async throws -> Void
    typealias WipeLocalData = () -> Void
    typealias KeychainClearer = () -> Void
    typealias SignInRequest = (_ email: String, _ password: String) async throws -> SignInResponse
    typealias SignOutRequest = () async -> Void
    typealias CredentialSaver = (SignInResponse) -> Void

    private let isMock: Bool
    private let nameKey = "auth.userName"
    private let emailKey = "auth.userEmail"
    private let onboardingKey = "onboarding.hasSeen"
    private let ownerKey = "auth.dataOwner"
    /// Owner of data from an install that never cached its email: matches no
    /// account (it has no "@"), so the next sign-in starts clean.
    private static let unknownOwner = "unknown-owner"
    private let defaults: UserDefaults

    private let deleteAccountRequest: DeleteAccountRequest
    private let wipeLocalData: WipeLocalData
    private let clearKeychain: KeychainClearer
    private let signInRequest: SignInRequest
    private let signOutRequest: SignOutRequest
    private let saveCredentials: CredentialSaver
    private let unsyncedItemCount: () -> Int

    init(
        isLoggedIn: Bool? = nil,
        userName: String? = nil,
        userEmail: String? = nil,
        isMock: Bool? = nil,
        deleteAccountRequest: @escaping DeleteAccountRequest = { password in
            try await AuthAPIService.deleteAccount(password: password)
        },
        wipeLocalData: @escaping WipeLocalData = {
            PersistenceController.shared.wipeAllData()
            SharedInbox.clearPendingCards()
        },
        clearKeychain: @escaping KeychainClearer = {
            KeychainService.clear()
        },
        signInRequest: @escaping SignInRequest = { email, password in
            try await AuthAPIService.signIn(email: email, password: password)
        },
        signOutRequest: @escaping SignOutRequest = {
            await AuthAPIService.signOut()
        },
        saveCredentials: @escaping CredentialSaver = { response in
            KeychainService.saveCredentials(accessToken: response.token, uid: response.uid, client: response.client)
        },
        unsyncedItemCount: @escaping () -> Int = { 0 },
        defaults: UserDefaults = .standard
    ) {
        self.saveCredentials = saveCredentials
        self.unsyncedItemCount = unsyncedItemCount
        self.defaults = defaults
        self.signInRequest = signInRequest
        self.signOutRequest = signOutRequest
        self.deleteAccountRequest = deleteAccountRequest
        self.wipeLocalData = wipeLocalData
        self.clearKeychain = clearKeychain
        self.isGuest = false

        let args = ProcessInfo.processInfo.arguments
        let forceOnboarding = args.contains("SHOW_ONBOARDING")

        if let explicitMock = isMock {
            self.isMock = explicitMock
            self.isLoggedIn = isLoggedIn ?? false
            self.userName = userName ?? ""
            self.userEmail = userEmail ?? ""
            self.hasSeenOnboarding = !forceOnboarding
            if !explicitMock { recordOwnerIfMissing() }
            return
        }

        if args.contains("LOGGED_OUT") {
            self.isMock = true
            self.isLoggedIn = false
            self.userName = ""
            self.userEmail = ""
            self.hasSeenOnboarding = !forceOnboarding
            return
        }
        if args.contains("UITEST") {
            self.isMock = true
            self.isLoggedIn = true
            self.userName = "Alex"
            self.userEmail = "alex@sphir.app"
            self.hasSeenOnboarding = !forceOnboarding
            return
        }

        self.isMock = false
        self.isLoggedIn = isLoggedIn ?? KeychainService.hasCredentials
        self.userName = userName ?? (defaults.string(forKey: nameKey) ?? "")
        self.userEmail = userEmail ?? (defaults.string(forKey: emailKey) ?? "")
        self.hasSeenOnboarding = defaults.bool(forKey: onboardingKey)

        // Installs from before owner tracking: the cached account owns the data.
        recordOwnerIfMissing()

        // Sign out if the API rejects the token (401).
        NotificationCenter.default.addObserver(
            forName: .sphirUnauthorized, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleUnauthorized() }
        }
    }

    // MARK: - Derived

    var displayName: String { userName.isEmpty ? "there" : userName }
    /// Mock sessions (UI tests) keep their seeded data and skip the sign-out confirmation.
    var isMockSession: Bool { isMock }

    var initial: String { String(displayName.first ?? "S").uppercased() }

    // MARK: - Actions

    func signIn(email: String, password: String) async throws {
        guard !isMock else { mockSignIn(email: email); return }

        let response = try await signInRequest(email, password)
        let name = [response.firstName, response.lastName]
            .compactMap { $0 }.filter { !$0.isEmpty }
            .joined(separator: " ")
        userName = name.isEmpty ? Self.name(fromEmail: email) : name
        userEmail = email
        // Another account's data must be gone before the UI (and sync) can see
        // it, and before the new token is stored: sync runs only with a token.
        let owner = Self.normalized(email)
        if let recorded = defaults.string(forKey: ownerKey), recorded != owner {
            wipeLocalData()
        }
        saveCredentials(response)
        defaults.set(owner, forKey: ownerKey)
        isLoggedIn = true
        isGuest = false
        cacheProfile()
    }

    /// Items not uploaded yet that signing in as `email` would delete (another
    /// account's data). 0 when the same account signs in or no owner is known.
    func unsyncedItemsLost(signingInAs email: String) -> Int {
        guard !isMock,
              let recorded = defaults.string(forKey: ownerKey),
              recorded != Self.normalized(email) else { return 0 }
        return unsyncedItemCount()
    }

    func signUp(name: String, email: String, password: String) async throws {
        guard !isMock else { mockSignUp(name: name, email: email); return }

        try await AuthAPIService.signUp(name: name, email: email, password: password)
        // Account created → sign in automatically.
        try await signIn(email: email, password: password)
    }

    func continueAsGuest() async throws {
        guard !isMock else {
            userName = "Guest"
            isLoggedIn = true
            isGuest = true
            return
        }
        try await AuthAPIService.continueAsGuest()
        userName = "Guest"
        userEmail = ""
        isLoggedIn = true
        isGuest = true
        // Guest session is not persisted to Keychain — next launch shows AuthView again.
    }

    func signOut() async {
        if !isMock {
            await signOutRequest()
        }
        clearSession()
        // Wipe first: if the app dies in between, the data keeps its owner.
        if !isMock { wipeLocalData() }
        defaults.removeObject(forKey: ownerKey)
    }

    /// Delete account and all associated data permanently.
    func deleteAccount(password: String) async -> DeleteAccountResult {
        guard !isMock else {
            clearSession()
            wipeLocalData()
            defaults.removeObject(forKey: ownerKey)
            return .success
        }
        do {
            try await deleteAccountRequest(password)
            clearSession()
            wipeLocalData()
            defaults.removeObject(forKey: ownerKey)
            return .success
        } catch let error as AuthAPIError where error == .incorrectPassword {
            return .incorrectPassword
        } catch let NetworkError.server(status, _) where status == 422 {
            return .incorrectPassword
        } catch {
            return .failed
        }
    }

    /// Mark onboarding complete (after the user taps "Get Started").
    func completeOnboarding() {
        hasSeenOnboarding = true
        defaults.set(true, forKey: onboardingKey)
    }

    /// Debug helper to replay the onboarding flow without reinstalling.
    func resetOnboarding() {
        hasSeenOnboarding = false
        defaults.removeObject(forKey: onboardingKey)
    }

    // MARK: - Private

    private func recordOwnerIfMissing() {
        guard isLoggedIn, defaults.string(forKey: ownerKey) == nil else { return }
        let owner = Self.normalized(userEmail)
        defaults.set(owner.isEmpty ? Self.unknownOwner : owner, forKey: ownerKey)
    }

    /// Internal so tests can drive the 401 path without the global notification.
    func handleUnauthorized() {
        guard isLoggedIn else { return }
        clearSession()   // Keychain already cleared by NetworkService.
    }

    private func clearSession() {
        isLoggedIn = false
        isGuest = false
        userName = ""
        userEmail = ""
        clearKeychain()
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: emailKey)
    }

    private func cacheProfile() {
        defaults.set(userName, forKey: nameKey)
        defaults.set(userEmail, forKey: emailKey)
    }

    // MARK: - Mock (UITEST)

    private func mockSignIn(email: String) {
        let stored = defaults.string(forKey: nameKey)
        userEmail = email
        userName = (stored?.isEmpty == false) ? stored! : Self.name(fromEmail: email)
        isLoggedIn = true
        isGuest = false
    }

    private func mockSignUp(name: String, email: String) {
        userName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        userEmail = email
        isLoggedIn = true
        isGuest = false
    }

    // MARK: - Helpers

    private static func splitName(_ name: String) -> (first: String, last: String) {
        let parts = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1).map(String.init)
        return (parts.first ?? "", parts.count > 1 ? parts[1] : "")
    }

    private static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func name(fromEmail email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? "there"
        return local.isEmpty ? "there" : local.capitalized
    }
}
