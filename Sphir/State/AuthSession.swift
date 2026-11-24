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

    private let isMock: Bool
    private let nameKey = "auth.userName"
    private let emailKey = "auth.userEmail"
    private let onboardingKey = "onboarding.hasSeen"

    private let deleteAccountRequest: DeleteAccountRequest
    private let wipeLocalData: WipeLocalData
    private let clearKeychain: KeychainClearer

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
        }
    ) {
        self.deleteAccountRequest = deleteAccountRequest
        self.wipeLocalData = wipeLocalData
        self.clearKeychain = clearKeychain
        self.isGuest = false

        let args = ProcessInfo.processInfo.arguments
        let forceOnboarding = args.contains("SHOW_ONBOARDING")
        let defaults = UserDefaults.standard

        if let explicitMock = isMock {
            self.isMock = explicitMock
            self.isLoggedIn = isLoggedIn ?? false
            self.userName = userName ?? ""
            self.userEmail = userEmail ?? ""
            self.hasSeenOnboarding = !forceOnboarding
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

        // Sign out if the API rejects the token (401).
        NotificationCenter.default.addObserver(
            forName: .sphirUnauthorized, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleUnauthorized() }
        }
    }

    // MARK: - Derived

    var displayName: String { userName.isEmpty ? "there" : userName }
    var initial: String { String(displayName.first ?? "S").uppercased() }

    // MARK: - Actions

    func signIn(email: String, password: String) async throws {
        guard !isMock else { mockSignIn(email: email); return }

        let response = try await AuthAPIService.signIn(email: email, password: password)
        let name = [response.firstName, response.lastName]
            .compactMap { $0 }.filter { !$0.isEmpty }
            .joined(separator: " ")
        userName = name.isEmpty ? Self.name(fromEmail: email) : name
        userEmail = email
        isLoggedIn = true
        isGuest = false
        cacheProfile()
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
            await AuthAPIService.signOut()
        }
        clearSession()
    }

    /// Delete account and all associated data permanently.
    func deleteAccount(password: String) async -> DeleteAccountResult {
        guard !isMock else {
            clearSession()
            wipeLocalData()
            return .success
        }
        do {
            try await deleteAccountRequest(password)
            clearSession()
            wipeLocalData()
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
        UserDefaults.standard.set(true, forKey: onboardingKey)
    }

    /// Debug helper to replay the onboarding flow without reinstalling.
    func resetOnboarding() {
        hasSeenOnboarding = false
        UserDefaults.standard.removeObject(forKey: onboardingKey)
    }

    // MARK: - Private

    private func handleUnauthorized() {
        guard isLoggedIn else { return }
        clearSession()   // Keychain already cleared by NetworkService.
    }

    private func clearSession() {
        isLoggedIn = false
        isGuest = false
        userName = ""
        userEmail = ""
        clearKeychain()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: emailKey)
    }

    private func cacheProfile() {
        let defaults = UserDefaults.standard
        defaults.set(userName, forKey: nameKey)
        defaults.set(userEmail, forKey: emailKey)
    }

    // MARK: - Mock (UITEST)

    private func mockSignIn(email: String) {
        let stored = UserDefaults.standard.string(forKey: nameKey)
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

    private static func name(fromEmail email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? "there"
        return local.isEmpty ? "there" : local.capitalized
    }
}
