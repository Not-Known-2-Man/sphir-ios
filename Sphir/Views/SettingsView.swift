//
//  SettingsView.swift
//  Sphir
//
//  Profile, sync status, about, and app version.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

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
    }

    // MARK: - Profile

    private var profileCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(SphirColor.lightTaupe)
                .frame(width: 56, height: 56)
                .overlay(
                    Text("A")
                        .font(SphirFont.heading(24, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Alex")
                    .font(SphirFont.body(17, weight: .bold))
                    .foregroundColor(SphirColor.textPrimary)
                Text("Personal workspace")
                    .font(SphirFont.body(13))
                    .foregroundColor(SphirColor.mutedText)
            }

            Spacer()
        }
        .padding(16)
        .background(card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alex, personal workspace")
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
}

#Preview {
    SettingsView()
}
