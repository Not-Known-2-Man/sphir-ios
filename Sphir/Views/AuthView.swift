//
//  AuthView.swift
//  Sphir
//
//  Sign In / Sign Up screen, backed by the real API (AuthSession →
//  AuthAPIService). Uses the mock path automatically under UITEST.
//

import SwiftUI
import UIKit

struct AuthView: View {
    @EnvironmentObject private var session: AuthSession

    private enum Mode { case signIn, signUp }

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var isGuestLoading = false
    @State private var authError: String?
    /// Unsynced items of another account that this sign-in would delete.
    @State private var itemsToLose = 0
    @State private var showingSwitchAccount = false

    private var isSignUp: Bool { mode == .signUp }

    private var canSubmit: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        let passwordOK = password.count >= 4
        let nameOK = !isSignUp || !name.trimmingCharacters(in: .whitespaces).isEmpty
        return emailOK && passwordOK && nameOK && !isSubmitting
    }

    var body: some View {
        ZStack {
            SphirColor.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header

                    VStack(spacing: 12) {
                        if isSignUp {
                            field("Name", text: $name, id: "authNameField")
                        }
                        field("Email", text: $email, id: "authEmailField", keyboard: .emailAddress)
                        secureField("Password", text: $password, id: "authPasswordField")
                    }

                    submitButton

                    if !isSignUp {
                        guestButton

                        Button("Forgot password?") { /* mock: no-op */ }
                            .font(SphirFont.body(13))
                            .foregroundColor(SphirColor.taupe)
                            .accessibilityIdentifier("forgotPasswordButton")
                    }

                    toggleRow
                }
                .padding(.horizontal, 28)
                .padding(.top, 64)
                .padding(.bottom, 32)
            }
        }
        .alert(
            "Sign-in failed",
            isPresented: Binding(get: { authError != nil }, set: { if !$0 { authError = nil } })
        ) {
            Button("OK", role: .cancel) { authError = nil }
        } message: {
            Text(authError ?? "")
        }
        .alert(
            "Sign in as a different account?",
            isPresented: $showingSwitchAccount
        ) {
            Button("Sign In", role: .destructive) {
                Task { await performAuth(confirmed: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let n = itemsToLose
            Text("This device has \(n == 1 ? "1 item" : "\(n) items") from another account that \(n == 1 ? "was" : "were") not uploaded. Signing in deletes \(n == 1 ? "it" : "them").")
        }
    }

    // MARK: - Actions

    private func submit() {
        // Dismiss the keyboard so its input window doesn't linger over the
        // next screen and swallow taps.
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
        Task { await performAuth() }
    }

    private func performGuestLogin() {
        Task {
            isGuestLoading = true
            defer { isGuestLoading = false }
            do {
                try await session.continueAsGuest()
            } catch {
                authError = (error as? LocalizedError)?.errorDescription
                    ?? "Couldn't connect. Check your connection and try again."
            }
        }
    }

    private func performAuth(confirmed: Bool = false) async {
        let cleanEmail = email.trimmingCharacters(in: .whitespaces)
        if !confirmed {
            let lost = session.unsyncedItemsLost(signingInAs: cleanEmail)
            if lost > 0 { itemsToLose = lost; showingSwitchAccount = true; return }
        }

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            switch mode {
            case .signIn:
                try await session.signIn(email: cleanEmail, password: password)
            case .signUp:
                try await session.signUp(name: name, email: cleanEmail, password: password)
            }
        } catch {
            authError = (error as? LocalizedError)?.errorDescription
                ?? "Something went wrong. Please try again."
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 12) {
            Image("SphirLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 200)
                .accessibilityHidden(true)

            Text(isSignUp ? "Create your account" : "Welcome back")
                .font(SphirFont.heading(24, weight: .bold))
                .foregroundColor(SphirColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func field(
        _ placeholder: String,
        text: Binding<String>,
        id: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(SphirFont.body(15))
            .foregroundColor(SphirColor.textPrimary)
            .keyboardType(keyboard)
            .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
            .autocorrectionDisabled(keyboard == .emailAddress)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(SphirColor.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
            .accessibilityIdentifier(id)
    }

    private func secureField(_ placeholder: String, text: Binding<String>, id: String) -> some View {
        PasswordField(placeholder: placeholder, text: text, id: id)
            .textFieldStyle(.plain)
            .font(SphirFont.body(15))
            .foregroundColor(SphirColor.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(SphirColor.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
    }

    private var submitButton: some View {
        Button(action: submit) {
            Group {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text(isSignUp ? "Create Account" : "Sign In")
                }
            }
            .font(SphirFont.body(16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 22).fill(SphirColor.taupe))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.5)
        .accessibilityIdentifier("authSubmitButton")
    }

    private var guestButton: some View {
        Button(action: performGuestLogin) {
            Group {
                if isGuestLoading {
                    ProgressView().tint(SphirColor.mutedText)
                } else {
                    Text("Continue as Guest")
                }
            }
            .font(SphirFont.body(14))
            .foregroundColor(SphirColor.mutedText)
        }
        .buttonStyle(.plain)
        .disabled(isGuestLoading || isSubmitting)
        .accessibilityIdentifier("continueAsGuestButton")
    }

    private var toggleRow: some View {
        HStack(spacing: 4) {
            Text(isSignUp ? "Already have an account?" : "New to Sphir?")
                .font(SphirFont.body(13))
                .foregroundColor(SphirColor.mutedText)
            Button(isSignUp ? "Sign In" : "Sign Up") {
                withAnimation { mode = isSignUp ? .signIn : .signUp }
            }
            .font(SphirFont.body(13, weight: .semibold))
            .foregroundColor(SphirColor.taupe)
            .accessibilityIdentifier("authToggleButton")
        }
    }
}

#Preview {
    AuthView().environmentObject(AuthSession())
}
