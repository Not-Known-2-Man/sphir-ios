//
//  RootView.swift
//  Sphir
//
//  Top-level routing: splash → auth → onboarding → dashboard.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: AuthSession

    // Skip the splash delay under UI tests for determinism.
    @State private var showSplash = !ProcessInfo.processInfo.arguments.contains("UITEST")

    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else if !session.isLoggedIn {
                AuthView()
            } else {
                // Dashboard presents onboarding itself (as a cover) on first
                // launch, so it stays rendered underneath.
                DashboardView()
            }
        }
        .task {
            guard showSplash else { return }
            try? await Task.sleep(nanoseconds: 600_000_000)
            showSplash = false
        }
    }
}
