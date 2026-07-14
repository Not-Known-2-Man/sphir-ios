//
//  AuthSession.swift
//  Sphir
//
//  Mock authentication state, persisted in UserDefaults. No real backend yet —
//  signing in/up simply records the user locally and marks them logged in.
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

    private let loggedInKey = "auth.isLoggedIn"
    private let nameKey = "auth.userName"
    private let emailKey = "auth.userEmail"
    private let onboardingKey = "onboarding.hasSeen"

    init() {
        let args = ProcessInfo.processInfo.arguments
        // "SHOW_ONBOARDING" forces the onboarding step on for UI tests.
        let forceOnboarding = args.contains("SHOW_ONBOARDING")

        if args.contains("LOGGED_OUT") {
            // Force the auth screen for UI tests.
            isLoggedIn = false
            userName = ""
            userEmail = ""
            hasSeenOnboarding = !forceOnboarding
            return
        }
        if args.contains("UITEST") {
            // Deterministic logged-in user for the rest of the UI tests.
            isLoggedIn = true
            userName = "Alex"
            userEmail = "alex@sphir.app"
            hasSeenOnboarding = !forceOnboarding
            return
        }
        let defaults = UserDefaults.standard
        isLoggedIn = defaults.bool(forKey: loggedInKey)
        userName = defaults.string(forKey: nameKey) ?? ""
        userEmail = defaults.string(forKey: emailKey) ?? ""
        hasSeenOnboarding = defaults.bool(forKey: onboardingKey)
    }

    // MARK: - Derived

    var displayName: String { userName.isEmpty ? "there" : userName }
    var initial: String { String(displayName.first ?? "S").uppercased() }

    // MARK: - Actions (mock)

    func signIn(email: String) {
        let stored = UserDefaults.standard.string(forKey: nameKey)
        userEmail = email
        userName = (stored?.isEmpty == false) ? stored! : Self.name(fromEmail: email)
        isLoggedIn = true
        persist()
    }

    func signUp(name: String, email: String) {
        userName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        userEmail = email
        isLoggedIn = true
        persist()
    }

    func signOut() {
        // Clears the session only. Onboarding stays "seen" so returning users
        // who sign in again go straight to the dashboard.
        isLoggedIn = false
        userName = ""
        userEmail = ""
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: loggedInKey)
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: emailKey)
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

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: loggedInKey)
        defaults.set(userName, forKey: nameKey)
        defaults.set(userEmail, forKey: emailKey)
    }

    private static func name(fromEmail email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? "there"
        return local.isEmpty ? "there" : local.capitalized
    }
}
