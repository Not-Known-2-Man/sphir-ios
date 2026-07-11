//
//  OnboardingView.swift
//  Sphir
//
//  First-launch welcome screen.
//

import SwiftUI

/// Decides whether onboarding should be shown, and records completion.
enum OnboardingGate {
    static let key = "hasCompletedOnboarding"

    static func shouldShow() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("SHOW_ONBOARDING") { return true }   // force for tests
        if args.contains("UITEST") { return false }           // deterministic otherwise
        return !UserDefaults.standard.bool(forKey: key)
    }

    static func complete() {
        UserDefaults.standard.set(true, forKey: key)
    }
}

struct OnboardingView: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Circle()
                .fill(SphirColor.taupe)
                .frame(width: 96, height: 96)
                .overlay(
                    Text("S")
                        .font(SphirFont.heading(48, weight: .bold))
                        .foregroundColor(.white)
                )
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Welcome to Sphir")
                    .font(SphirFont.heading(28, weight: .bold))
                    .foregroundColor(SphirColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Your calm space to capture and collect what matters — articles, media, links, photos, and screenshots — organized into collections.")
                    .font(SphirFont.body(15))
                    .foregroundColor(SphirColor.mutedText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }

            Spacer()

            Button(action: onGetStarted) {
                Text("Get Started")
                    .font(SphirFont.body(17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 24).fill(SphirColor.taupe))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("getStartedButton")
            .accessibilityHint("Opens your dashboard")
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SphirColor.background.ignoresSafeArea())
    }
}

#Preview {
    OnboardingView(onGetStarted: {})
}
