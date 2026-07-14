//
//  AuthView.swift
//  Sphir
//
//  Sign In / Sign Up screen. Mock authentication — records the user in the
//  session (UserDefaults); no real backend yet.
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

    private var isSignUp: Bool { mode == .signUp }

    private var canSubmit: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        let passwordOK = password.count >= 4
        let nameOK = !isSignUp || !name.trimmingCharacters(in: .whitespaces).isEmpty
        return emailOK && passwordOK && nameOK
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
    }

    // MARK: - Actions

    private func submit() {
        // Dismiss the keyboard first, then route once its input window has
        // torn down — otherwise the lingering window sits over the next
        // screen and swallows taps.
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            performAuth()
        }
    }

    private func performAuth() {
        switch mode {
        case .signIn:
            session.signIn(email: email.trimmingCharacters(in: .whitespaces))
        case .signUp:
            session.signUp(
                name: name,
                email: email.trimmingCharacters(in: .whitespaces)
            )
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(SphirColor.taupe)
                .frame(width: 72, height: 72)
                .overlay(
                    Text("S")
                        .font(SphirFont.heading(36, weight: .bold))
                        .foregroundColor(.white)
                )
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
        SecureField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(SphirFont.body(15))
            .foregroundColor(SphirColor.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(SphirColor.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
            .accessibilityIdentifier(id)
    }

    private var submitButton: some View {
        Button(action: submit) {
            Text(isSignUp ? "Create Account" : "Sign In")
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
