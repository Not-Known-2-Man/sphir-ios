//
//  SettingsView.swift
//  Sphir
//
//  Profile, sync status, about, and app version.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: AuthSession
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAccountSheet = false
    @State private var showingSignOutConfirmation = false

    private var unsyncedCount: Int { session.isMockSession ? 0 : store.unsyncedCardCount }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            FlowModalHeader(title: "Settings") { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileCard
                    syncStatusCard
                    aboutSection

                    #if DEBUG
                    resetOnboardingButton
                    #endif

                    signOutButton

                    if !session.isGuest {
                        deleteAccountButton
                    }

                    Text(appVersion)
                        .font(SphirFont.body(12))
                        .foregroundColor(SphirColor.mutedText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .background(SphirColor.background.ignoresSafeArea())
        .sheet(isPresented: $showingDeleteAccountSheet) {
            DeleteAccountSheet {
                dismiss()
            }
            .environmentObject(session)
        }
    }

    // MARK: - Profile

    private var profileCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(SphirColor.lightTaupe)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(session.initial)
                        .font(SphirFont.heading(24, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(session.displayName)
                    .font(SphirFont.body(17, weight: .bold))
                    .foregroundColor(SphirColor.textPrimary)
                Text(session.userEmail.isEmpty ? "Personal workspace" : session.userEmail)
                    .font(SphirFont.body(13))
                    .foregroundColor(SphirColor.mutedText)
            }

            Spacer()
        }
        .padding(16)
        .background(card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(session.displayName), \(session.userEmail.isEmpty ? "personal workspace" : session.userEmail)")
    }

    // MARK: - Sync status

    private var syncStatusCard: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(SphirColor.success)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text("Synced")
                    .font(SphirFont.body(15, weight: .semibold))
                    .foregroundColor(SphirColor.textPrimary)
                Text("All changes saved locally")
                    .font(SphirFont.body(12))
                    .foregroundColor(SphirColor.mutedText)
            }

            Spacer()

            Image(systemName: "checkmark.icloud")
                .font(.system(size: 18))
                .foregroundColor(SphirColor.success)
                .accessibilityHidden(true)
        }
        .padding(16)
        .background(card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sync status: Synced. All changes saved locally.")
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About Sphir")
                .font(SphirFont.heading(18, weight: .bold))
                .foregroundColor(SphirColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("Sphir is your calm space to capture and collect what matters — articles, media, links, photos, and screenshots — organized into private collections and shared groups.")
                .font(SphirFont.body(14))
                .foregroundColor(SphirColor.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(card)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(SphirColor.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
    }

    // MARK: - Actions

    private var signOutButton: some View {
        Button {
            if unsyncedCount > 0 {
                showingSignOutConfirmation = true
            } else {
                performSignOut()
            }
        } label: {
            Text("Sign Out")
                .font(SphirFont.body(16, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(SphirColor.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("signOutButton")
        .alert("Sign out?", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive) { performSignOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            let n = unsyncedCount
            Text("You have \(n == 1 ? "1 card" : "\(n) cards") that \(n == 1 ? "is" : "are") not uploaded yet. Signing out deletes \(n == 1 ? "it" : "them") from this device.")
        }
    }

    private func performSignOut() {
        Task { await session.signOut() }
        dismiss()
    }

    private var deleteAccountButton: some View {
        Button {
            showingDeleteAccountSheet = true
        } label: {
            Text("Delete Account")
                .font(SphirFont.body(16, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(SphirColor.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("deleteAccountButton")
    }

    #if DEBUG
    private var resetOnboardingButton: some View {
        Button {
            session.resetOnboarding()
            dismiss()
        } label: {
            Text("Reset Onboarding (debug)")
                .font(SphirFont.body(13))
                .foregroundColor(SphirColor.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("resetOnboardingButton")
    }

    #endif
}

struct DeleteAccountSheet: View {
    @EnvironmentObject private var session: AuthSession
    @Environment(\.dismiss) private var dismiss
    let onAccountDeleted: () -> Void

    @State private var password = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("This permanently deletes your account, collections and cards. This cannot be undone.")
                    .font(SphirFont.body(14))
                    .foregroundColor(SphirColor.mutedText)
                    .fixedSize(horizontal: false, vertical: true)

                PasswordField(placeholder: "Current password", text: $password, id: "deleteAccountPasswordField")
                    .textFieldStyle(.roundedBorder)

                if let errorMessage {
                    Text(errorMessage)
                        .font(SphirFont.body(13))
                        .foregroundColor(.red)
                        .accessibilityIdentifier("deleteAccountErrorMessage")
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(role: .destructive) {
                        performDelete()
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text("Delete Account")
                                .font(SphirFont.body(16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(password.isEmpty || isDeleting ? Color.red.opacity(0.4) : Color.red)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(password.isEmpty || isDeleting)
                    .accessibilityIdentifier("confirmDeleteAccountButton")

                    Button("Cancel") {
                        dismiss()
                    }
                    .font(SphirFont.body(16, weight: .regular))
                    .foregroundColor(SphirColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .disabled(isDeleting)
                    .accessibilityIdentifier("cancelDeleteAccountButton")
                }
            }
            .padding(20)
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isDeleting)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func performDelete() {
        guard !password.isEmpty, !isDeleting else { return }
        isDeleting = true
        errorMessage = nil

        Task {
            let result = await session.deleteAccount(password: password)
            isDeleting = false
            switch result {
            case .success:
                dismiss()
                onAccountDeleted()
            case .incorrectPassword:
                errorMessage = "Incorrect password"
            case .failed:
                errorMessage = "Could not delete your account. Please try again."
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthSession())
        .environmentObject(AppStore())
}
