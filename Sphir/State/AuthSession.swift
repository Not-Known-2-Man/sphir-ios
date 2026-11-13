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

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var isLoggedIn: Bool
    @Published private(set) var userName: String
    @Published private(set) var userEmail: String
    /// Whether the user has completed onboarding (persists across sign-out).
    @Published private(set) var hasSeenOnboarding: Bool

    private let isMock: Bool
    private let nameKey = "auth.userName"
    private let emailKey = "auth.userEmail"
    private let onboardingKey = "onboarding.hasSeen"

    init() {
        let args = ProcessInfo.processInfo.arguments
        let forceOnboarding = args.contains("SHOW_ONBOARDING")
        let defaults = UserDefaults.standard

        if args.contains("LOGGED_OUT") {
            isMock = true
            isLoggedIn = false
            userName = ""
            userEmail = ""
            hasSeenOnboarding = !forceOnboarding
            return
        }
        if args.contains("UITEST") {
            isMock = true
            isLoggedIn = true
            userName = "Alex"
            userEmail = "alex@sphir.app"
            hasSeenOnboarding = !forceOnboarding
            return
        }

        isMock = false
        isLoggedIn = KeychainService.hasCredentials
        userName = defaults.string(forKey: nameKey) ?? ""
        userEmail = defaults.string(forKey: emailKey) ?? ""
        hasSeenOnboarding = defaults.bool(forKey: onboardingKey)

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
            return
        }
        try await AuthAPIService.continueAsGuest()
        userName = "Guest"
        userEmail = ""
        isLoggedIn = true
        // Guest session is not persisted to Keychain — next launch shows AuthView again.
    }

    func signOut() async {
        if !isMock {
            await AuthAPIService.signOut()
        }
        clearSession()
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
        userName = ""
        userEmail = ""
        KeychainService.clear()
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
    }

    private func mockSignUp(name: String, email: String) {
        userName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        userEmail = email
        isLoggedIn = true
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
